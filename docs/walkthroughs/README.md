# Walkthroughs

Start with the [Terraform walkthrough](./walkthrough_terraform.md) to deploy the whole stack and run the pipeline end to end.
The walkthroughs below provision the same infrastructure by hand, one component at a time, in the AWS Management Console and CLI.

## Phase 1: Foundation and Source Database

| Walkthrough | What it covers |
|---|---|
| [0. Prerequisites and Permissions](./walkthrough-0-prerequisites.md) | Tools, account access and the admin IAM identity |
| [1. RDS MySQL Setup](./walkthrough-1-rds-setup.md) | Source MySQL database, binlog parameters and CDC retention |

## Phase 2: Storage and Replication

| Walkthrough | What it covers |
|---|---|
| [2. S3 Data Lake](./walkthrough-2-s3-data-lake.md) | Bucket layout for the bronze and silver layers |
| [3. DMS Replication (CDC)](./walkthrough-3-dms-replication.md) | Full load and change data capture from RDS to bronze |

## Phase 3: Processing and Warehousing

| Walkthrough | What it covers |
|---|---|
| [4. Data Generation (Lambda)](./walkthrough-4-lambda-data-generator.md) | Synthetic sales traffic, packaging and credentials |
| [5. Redshift Data Warehouse](./walkthrough-5-redshift.md) | RA3 cluster, `sales` schema, DDL and stored procedures |
| [6. Glue ETL (Transformation)](./walkthrough-6-glue-etl.md) | Data Catalog, crawlers and bronze-to-silver Spark jobs |

## Phase 4: Integration and Orchestration

| Walkthrough | What it covers |
|---|---|
| [7. Redshift Loading and VPC Networking](./walkthrough-7-redshift-loading-and-vpc.md) | VPC endpoints, Glue connection and silver-to-staging loads |
| [8. Step Functions (Orchestration)](./walkthrough-8-step-functions.md) | Crawl, transform, load and awaited merges |

## Phase 5: Automation and Governance

| Walkthrough | What it covers |
|---|---|
| [9. Visualization (QuickSight / BI)](./walkthrough-9-visualization.md) | QuickSight dataset and sales dashboard |
| [10. Scheduling (EventBridge)](./walkthrough-10-scheduling.md) | EventBridge rules for the generator and the pipeline |
| [11. PII Management (Lake Formation)](./walkthrough-11-lake-formation.md) | LF-Tags and column-level access to PII |
| [12. Cleanup](./walkthrough-12-cleanup.md) | Tear everything down to stop costs |

## Conventions

- Region is `ca-central-1` unless stated otherwise.
- Paths such as `etl_glue_jobs/` are relative to the repository root.
