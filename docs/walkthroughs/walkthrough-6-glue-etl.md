# Walkthrough 6: Glue ETL (Transformation)

Process data from the Bronze layer to the Silver layer.

- **IAM Role**: Attach `AWSGlueServiceRole`, `AWSGlueNotebookRole`, and your custom S3 bucket policy.
- **Database**: Create a Glue Data Catalog database (e.g., `aws_de_project_db`).
- **Crawlers**: Create one crawler per Bronze folder to discover schema.
- **Spark Jobs**: Deploy the jobs from `etl_glue_jobs/transform/`.
- **Bookmarks**: **Enable job bookmarks** to avoid reprocessing old data.

---

Next: [Walkthrough 7: Redshift Loading and VPC Networking](./walkthrough-7-redshift-loading-and-vpc.md)  
Back to [Walkthroughs](./README.md)
