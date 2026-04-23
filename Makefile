# Load Terraform outputs once into shell variables.
# We explicitly cd into terraform directory to fetch outputs.
TF_OUTPUTS := $(shell cd terraform && terraform output -json)
DB_ENDPOINT := $(shell echo '$(TF_OUTPUTS)' | jq -r '.rds_endpoint.value | split(":")[0]')
DB_PASSWORD := $(shell echo '$(TF_OUTPUTS)' | jq -r '.db_password.value')
DMS_ARN := $(shell echo '$(TF_OUTPUTS)' | jq -r '.dms_replication_task_arn.value')
LAMBDA_NAME := $(shell echo '$(TF_OUTPUTS)' | jq -r '.lambda_function_name.value')
SFN_ARN := $(shell echo '$(TF_OUTPUTS)' | jq -r '.state_machine_arn.value')
REDSHIFT_CLUSTER := $(shell echo '$(TF_OUTPUTS)' | jq -r '.redshift_cluster_identifier.value')

.PHONY: setup-rds setup-redshift trigger-dms trigger-lambda trigger-pipeline

setup-rds:
	@echo "Running Flyway migrations on RDS..."
	FLYWAY_PASSWORD=$(DB_PASSWORD) bash db/migrate.sh $(DB_ENDPOINT) admin
	@echo "Setting CDC binlog retention..."
	docker run --rm mysql:8.0 mysql -h $(DB_ENDPOINT) -u admin -p$(DB_PASSWORD) -e "CALL mysql.rds_set_configuration('binlog retention hours', 24);"

setup-redshift:
	@echo "Creating Redshift schema and objects..."
	aws redshift-data execute-statement --cluster-identifier $(REDSHIFT_CLUSTER) --database dev --db-user adminuser --sql "CREATE SCHEMA IF NOT EXISTS sales;" --region ca-central-1
	@echo "Applying DDLs..."
	for file in $$(ls data_warehouse_redshift/ddl/*.sql); do \
		aws redshift-data execute-statement --cluster-identifier $(REDSHIFT_CLUSTER) --database dev --db-user adminuser --sql "$$(cat $$file)" --region ca-central-1; \
	done
	@echo "Applying Stored Procedures..."
	for file in $$(ls data_warehouse_redshift/stored_procedures/*.sql); do \
		aws redshift-data execute-statement --cluster-identifier $(REDSHIFT_CLUSTER) --database dev --db-user adminuser --sql "$$(cat $$file)" --region ca-central-1; \
	done

trigger-dms:
	aws dms start-replication-task --replication-task-arn $(DMS_ARN) --start-replication-task-type reload-target --region ca-central-1

trigger-lambda:
	aws lambda invoke --function-name $(LAMBDA_NAME) --region ca-central-1 response.json

trigger-pipeline:
	aws stepfunctions start-execution --state-machine-arn $(SFN_ARN) --region ca-central-1
