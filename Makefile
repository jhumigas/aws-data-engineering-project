.PHONY: setup-rds trigger-dms trigger-lambda trigger-pipeline

setup-rds:
	aws redshift-data execute-statement --cluster-identifier aws-de-project-dev-redshift --database dev --db-user adminuser --sql "CREATE SCHEMA IF NOT EXISTS sales;" --region ca-central-1

trigger-dms:
	aws dms start-replication-task --replication-task-arn $$(cd terraform && terraform output -raw dms_replication_task_arn) --start-replication-task-type reload-target --region ca-central-1

trigger-lambda:
	aws lambda invoke --function-name $$(cd terraform && terraform output -raw lambda_function_name) --region ca-central-1 response.json

trigger-pipeline:
	aws stepfunctions start-execution --state-machine-arn $$(cd terraform && terraform output -raw state_machine_arn) --region ca-central-1
