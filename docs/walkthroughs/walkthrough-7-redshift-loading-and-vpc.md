# Walkthrough 7: Redshift Loading and VPC Networking

Connect Glue to Redshift privately and load the silver layer into staging.

## VPC Endpoints
For private subnet communication, create endpoints for:
- **S3** (Gateway)
- **Secrets Manager** (Interface)
- **Redshift** (Interface)
- **STS** (Interface)

## Glue Connection
Create a "Redshift" connection type in Glue using the Redshift cluster's VPC, subnet, and security group.

## Loading Jobs
Deploy scripts from `etl_glue_jobs/load/` to move data from Silver S3 to Redshift staging.

---

Next: [Walkthrough 8: Step Functions (Orchestration)](./walkthrough-8-step-functions.md)  
Back to [Walkthroughs](./README.md)
