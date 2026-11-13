# Walkthrough 2: S3 Data Lake

Create a single S3 bucket to serve as the project's data lake.

- **Folders**: Create `bronze/` (for raw CSV) and `silver/` (for processed Parquet).
- **Policy**: Create a policy to allow Glue, DMS, and Redshift to access the bucket (see [Security Design](../SECURITY_DESIGN.md) for role-specific prefixes).

---

Next: [Walkthrough 3: DMS Replication (CDC)](./walkthrough-3-dms-replication.md)  
Back to [Walkthroughs](./README.md)
