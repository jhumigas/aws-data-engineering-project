# Walkthrough 3: DMS Replication (CDC)

Set up continuous data capture from RDS to S3.

## Replication Instance
Use a small instance (e.g., `dms.t3.medium`).

## Endpoints
- **Source**: Connect to the RDS instance.
  Test the connection.
- **Target**: Connect to the S3 bucket.
  Ensure the service role has `s3:PutObject` permissions.
  Test the connection.

## Replication Task
- **Migration Type**: Full load + CDC.
- **Target Location**: `s3://<bucket>/bronze/`.
- **Settings**: Ensure `AddColumnName=true` and `IncludeOpForFullLoad=true` are set in the S3 target settings to provide headers and operation metadata to Spark.

---

Next: [Walkthrough 4: Data Generation (Lambda)](./walkthrough-4-lambda-data-generator.md)  
Back to [Walkthroughs](./README.md)
