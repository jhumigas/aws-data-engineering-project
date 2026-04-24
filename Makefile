# ===================================================================
# Project Control Plane
# ===================================================================

.DEFAULT_GOAL := help

.PHONY: help setup-rds setup-redshift trigger-dms trigger-lambda trigger-pipeline trigger-crawlers build-lambda clean-s3 tf-outputs run-metabase run-superset tf-init tf-plan tf-apply tf-destroy

## Show this help message
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

## Initialize Terraform
tf-init: ## Initialize Terraform
	@cd terraform && terraform init

## Plan Terraform changes
tf-plan: ## Plan Terraform changes
	@cd terraform && terraform plan

## Apply Terraform changes
tf-apply: ## Apply Terraform changes
	@cd terraform && terraform apply -auto-approve

## Destroy Terraform resources
tf-destroy: ## Destroy Terraform resources
	@cd terraform && terraform destroy -auto-approve

## Display all Terraform outputs
tf-outputs: ## Display all Terraform outputs
	@cd terraform && terraform output

## Build Lambda deployment package locally
build-lambda: ## Build Lambda deployment package using uv
	@echo "Building Lambda package..."
	cd data_generator_lambda && rm -rf build && mkdir -p build && \
	uv pip install --no-installer-metadata --no-compile-bytecode --python-platform x86_64-manylinux2014 --python 3.13 --target build/ -r pyproject.toml && \
	cp lambda_function.py build/ && \
	cd build && zip -r ../../terraform/modules/lambda/lambda_function.zip .

## Run Flyway migrations and enable CDC on RDS MySQL
setup-rds: ## Run RDS migrations and CDC setup
	$(eval DB_ENDPOINT := $(shell cd terraform && terraform output -raw rds_endpoint | cut -d: -f1))
	$(eval DB_PASSWORD := $(shell cd terraform && terraform output -raw db_password))
	@echo "Running Flyway migrations on RDS..."
	FLYWAY_PASSWORD=$(DB_PASSWORD) bash application_db_rds/migrate.sh $(DB_ENDPOINT) admin
	@echo "Setting CDC binlog retention..."
	docker run --rm mysql:8.0 mysql -h $(DB_ENDPOINT) -u admin -p$(DB_PASSWORD) -e "CALL mysql.rds_set_configuration('binlog retention hours', 24);"

## Initialize Redshift schema, tables, and stored procedures
setup-redshift: ## Initialize Redshift schema and objects
	$(eval REDSHIFT_CLUSTER := $(shell cd terraform && terraform output -raw redshift_cluster_identifier))
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

## Trigger all Glue crawlers for schema discovery
trigger-crawlers: ## Trigger all Glue crawlers
	@for crawler in aws-de-project-dev-crawler-Customer aws-de-project-dev-crawler-Orders aws-de-project-dev-crawler-Product aws-de-project-dev-crawler-orderDetails; do \
		echo "Starting crawler: $$crawler"; \
		aws glue start-crawler --name $$crawler --region ca-central-1; \
	done

## Start the DMS replication task (Full Load + CDC)
trigger-dms: ## Start DMS replication task
	$(eval DMS_ARN := $(shell cd terraform && terraform output -raw dms_replication_task_arn))
	aws dms start-replication-task --replication-task-arn $(DMS_ARN) --start-replication-task-type reload-target --region ca-central-1

## Invoke the Lambda generator to seed RDS with initial data
trigger-lambda: ## Seed RDS with Lambda data generator
	$(eval LAMBDA_NAME := $(shell cd terraform && terraform output -raw lambda_function_name))
	aws lambda invoke --function-name $(LAMBDA_NAME) --region ca-central-1 response.json

## Trigger the end-to-end Step Functions ETL pipeline
trigger-pipeline: ## Trigger Step Functions ETL pipeline
	$(eval SFN_ARN := $(shell cd terraform && terraform output -raw state_machine_arn))
	aws stepfunctions start-execution --state-machine-arn $(SFN_ARN) --region ca-central-1

## Purge all data from the S3 bronze and silver layers
clean-s3: ## Purge S3 bronze and silver data
	$(eval BUCKET := $(shell cd terraform && terraform output -raw bucket_name))
	aws s3 rm s3://$(BUCKET)/bronze/ --recursive
	aws s3 rm s3://$(BUCKET)/silver/ --recursive

## Spin up Metabase locally via Docker (Port 3000)
run-metabase: ## Run Metabase BI tool locally
	docker run -d -p 3000:3000 --name metabase metabase/metabase

## Spin up Apache Superset locally via Docker (Port 8088)
run-superset: ## Run Apache Superset BI tool locally
	docker run -d -p 8088:8088 --name superset apache/superset
