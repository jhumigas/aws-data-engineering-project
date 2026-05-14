# AGENTS.md - AI Context & Guidelines

Technical context for AI assistants working on the AWS Data Engineering project.

## Project Overview
An enterprise-grade data pipeline moving data from an RDS MySQL source to a Redshift RA3 warehouse via DMS, S3, and Glue, orchestrated by Step Functions.

- **Primary Region:** `ca-central-1` (Canada Central)
- **Architecture:** Medallion (Bronze -> Silver -> Gold)
- **SCD Logic:** Type 2 (History preserving) in Redshift Dimensions.

## Core Workflows & Logic

### Orchestration Sequence
The Step Function orchestrator follows a strict sequential dependency:
1. **Parallel Dimensions:** `Customer` and `Product` are processed first.
2. **Parallel Facts:** `Orders` and `OrderDetails` are processed ONLY after dimensions succeed.

### SCD Type 2 Merge Pattern
Stored Procedures in Redshift follow this 4-step sequence:
1. **Stage:** Glue loads raw data into `stage_` table.
2. **Expire:** Deactivate existing records in the Gold table where `hash_value` changed.
3. **Insert:** Insert new active records.
4. **Clean:** Truncate the staging table.

## Tech Stack & Tooling
- **Languages:** Python (3.9+), SQL (Redshift/MySQL), PySpark (Spark 3.x)
- **Source DB:** AWS RDS MySQL 8.0 (with Binary Logging/CDC)
- **Ingestion:** AWS DMS (Database Migration Service)
- **Storage:** AWS S3 (Medallion Layers: Bronze, Silver, Scripts)
- **Processing:** AWS Glue (Spark ETL, Crawlers, Data Catalog)
- **Warehouse:** Amazon Redshift (RA3 Cluster)
- **Orchestration:** AWS Step Functions & AWS EventBridge (Scheduling)
- **Security:** AWS IAM, AWS Secrets Manager, AWS Lake Formation (PII/Governance)
- **Infrastructure:** Terraform (Modular, v1.0+)
- **Dependency Management:** `uv` (Lambda packaging), Flyway CLI (RDS Migrations)
- **BI/Analytics:** AWS QuickSight, Metabase (Local via Docker)
- **Control Plane:** `Makefile`

## Superpowers & Skills
For complex tasks, use the following specialized workflows:
- **`subagent-driven-development` / `executing-plans`**: Use these when implementing multi-step tasks defined in `docs/superpowers/plans/`.
- **`systematic-debugging`**: Use when troubleshooting pipeline failures (e.g., Glue job timeouts, Redshift merge conflicts).
- **`verification-before-completion`**: Always run verification steps (e.g., `make tf-outputs`, checking S3 files) before claiming a task is done.
- **`brainstorming`**: Use before starting any major architectural changes or new feature implementations.

## Critical Commands

### Development Entry Points
```bash
make build-lambda      # Package Lambda with uv (Linux target)
make setup-rds         # Flyway migrations + CDC config
make setup-redshift    # Warehouse DDL + Stored Procedures
make trigger-pipeline  # Trigger end-to-end Step Function
```

### Infrastructure Management
```bash
cd terraform && terraform plan
cd terraform && terraform apply
```

## Coding Standards

### Glue / PySpark
- Use `getResolvedOptions(sys.argv, [...])` for all script arguments.
- Always enable **Job Bookmarks** in Terraform config.
- Use `hash_value` (SHA256) for change detection.

### Redshift / SQL
- Schema: `sales`
- Target tables: `dim_customer`, `dim_product`, `fact_orders`, `fact_order_details`.
- Staging tables: `stage_` prefix.

### Terraform
- Follow the modular structure in `terraform/modules/`.
- Use **Regional Service Principals** (e.g., `dms.ca-central-1.amazonaws.com`) in IAM trust policies.
- **Validation Workflow:**
    1. `terraform fmt` - Ensure consistent styling.
    2. `terraform validate` - Check for internal consistency and syntax.
    3. `tflint` - (Recommended) Run linter for AWS-specific best practices.
    4. `terraform plan` - Always review the plan before applying to catch unintended deletions or destructive changes.

## Security & Secrets
- **Secrets Manager:** All DB credentials must be retrieved via Secrets Manager. No hardcoding.
- **Least Privilege:** Services are restricted by S3 prefix (e.g., Glue can only write to `silver/`).
- **Networking:** Most services run within private subnets using VPC Endpoints (S3, Secrets Manager, Redshift, STS).

## Troubleshooting (Quick Reference)
- **SFN Failures:** Check `Execution History` for Glue job ID.
- **Concurrency Errors:** `max_concurrent_runs` is capped at 5.
- **Schema Errors:** Re-run Glue Crawlers (`make trigger-crawlers`) if columns are missing.

## File Boundaries
- `terraform/`: Infrastructure as Code.
- `etl_glue_jobs/`: PySpark ETL logic.
- `data_warehouse_redshift/`: DDL, Stored Procedures, and validation SQL.
- `data_generator_lambda/`: Python source for traffic simulation.
