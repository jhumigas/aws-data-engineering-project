# AWS Glue ETL Jobs

PySpark scripts used by AWS Glue for data transformation and loading within the pipeline.

## Pre-requisites
- **S3 Bucket** created with `scripts/` and `temporary/` folders.
- **Glue IAM Role** with S3 and Redshift Data API permissions.

## Folder Structure
```text
.
├── load                          <-- Scripts loading Silver data to Redshift Staging
├── transform                     <-- Scripts cleaning Bronze CSV data to Silver Parquet
└── README.md
```

## Configuration
All jobs are fully parameterized via Terraform `default_arguments`. They utilize **Glue Job Bookmarks** to ensure incremental processing of only new files delivered by DMS.

### Manual Execution
To manually trigger a job without the Step Functions orchestrator, use the **AWS Glue CLI**:
```bash
aws glue start-job-run \
  --job-name <job-name> \
  --arguments '{
    "--SOURCE_BUCKET": "your-bucket-name",
    "--TARGET_PREFIX": "silver/dev",
    "--GLUE_DATABASE": "your-catalog-db"
  }' \
  --region ca-central-1
```
