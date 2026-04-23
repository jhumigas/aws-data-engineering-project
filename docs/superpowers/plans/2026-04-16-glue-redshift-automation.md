# Glue and Redshift Data Pipeline Automation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automate the ETL pipeline from S3 Bronze to Redshift Gold, including schema discovery, transformation, and SCD Type 2 loading.

**Architecture:** Use table-specific Glue Crawlers for discovery, parameterized Glue Spark jobs for incremental transformation (Bronze -> Silver) and loading (Silver -> Redshift Staging), and sequential orchestration via Step Functions.

**Tech Stack:** Terraform, AWS Glue, Amazon Redshift, AWS Step Functions, PySpark.

---

### Task 1: Refactor Glue Transform Scripts

**Files:**
- Modify: `../etl_glue_jobs/transform/raw_customer_etl_job.py`
- Modify: `../etl_glue_jobs/transform/raw_orderdetails_etl_job.py`
- Modify: `../etl_glue_jobs/transform/raw_orders_etl_job.py`
- Modify: `../etl_glue_jobs/transform/raw_product_etl_job.py`

- [ ] **Step 1: Refactor Customer Transform Script to use dynamic arguments**

```python
# Modify ../etl_glue_jobs/transform/raw_customer_etl_job.py
import sys
from awsglue.utils import getResolvedOptions
from awsglue.job import Job
# ... existing imports ...

args = getResolvedOptions(sys.argv, ["JOB_NAME", "SOURCE_BUCKET", "GLUE_DATABASE", "TARGET_PREFIX"])
source_bucket = args['SOURCE_BUCKET']
glue_database = args['GLUE_DATABASE']
processed_folder_name = args['TARGET_PREFIX']
# ... update logic to use these variables ...
```

- [ ] **Step 2: Apply similar refactoring to Orders, Product, and OrderDetails transform scripts**
Ensure all scripts in `../etl_glue_jobs/transform/` use `getResolvedOptions`.

- [ ] **Step 3: Commit refactored scripts**

```bash
git add ../etl_glue_jobs/transform/
git commit -m "refactor: parameterize glue transform scripts"
```

---

### Task 2: Refactor Glue Load Scripts

**Files:**
- Modify: `../etl_glue_jobs/load/*.py`

- [ ] **Step 1: Parameterize Load scripts for Redshift connection**
Update scripts in `../etl_glue_jobs/load/` to accept `--REDSHIFT_CONNECTION` and `--STAGING_TABLE`.

- [ ] **Step 2: Commit load scripts**

```bash
git add ../etl_glue_jobs/load/
git commit -m "refactor: parameterize glue load scripts"
```

---

### Task 3: Update Glue Terraform Module

**Files:**
- Modify: `modules/glue/main.tf`
- Modify: `modules/glue/variables.tf`

- [ ] **Step 1: Add individual Crawlers for each Bronze folder**

```hcl
resource "aws_glue_crawler" "tables" {
  for_each = toset(["Customer", "Orders", "Product", "orderDetails"])
  database_name = aws_glue_catalog_database.main.name
  name          = "${var.project_name}-${var.environment}-crawler-${each.key}"
  role          = aws_iam_role.glue_role.arn
  s3_target {
    path = "s3://${var.bucket_name}/bronze/dev/${each.key}/"
  }
}
```

- [ ] **Step 2: Update Glue Job resource to pass dynamic arguments**

```hcl
resource "aws_glue_job" "job" {
  # ... existing config ...
  default_arguments = {
    "--SOURCE_BUCKET"       = var.bucket_name
    "--GLUE_DATABASE"       = aws_glue_catalog_database.main.name
    "--TARGET_PREFIX"       = "silver/dev"
    "--job-bookmark-option" = "job-bookmark-enable"
  }
}
```

- [ ] **Step 3: Commit Glue Module updates**

```bash
git add modules/glue/
git commit -m "feat: add crawlers and dynamic job args to glue module"
```

---

### Task 4: Finalize Step Functions Sequential Orchestration

**Files:**
- Modify: `modules/step_functions/main.tf`

- [ ] **Step 1: Construct sequential state machine definition**
Chain Crawlers -> Transform Jobs -> Load Jobs -> Redshift Procedures.

- [ ] **Step 2: Commit Step Functions updates**

```bash
git add modules/step_functions/
git commit -m "feat: sequential orchestration in step functions"
```

---

### Task 5: End-to-End Verification

- [ ] **Step 1: Run Terraform Apply**
Run: `terraform apply -auto-approve`

- [ ] **Step 2: Trigger and Verify**
Manually trigger Step Function and verify data in Redshift Gold tables.
