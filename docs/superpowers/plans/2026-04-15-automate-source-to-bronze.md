# Automated Source to Bronze Deployment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automate schema creation, CDC activation, replication start, and initial data generation to land data in S3 Bronze zone with one command.

**Architecture:** Use local Flyway via Terraform `local-exec` to manage RDS schema, followed by AWS CLI calls to start DMS tasks and trigger the generator Lambda.

**Tech Stack:** Terraform, Flyway CLI, AWS CLI, MySQL.

---

### Task 1: Organize Migration Scripts

**Files:**
- Create: `db/migration/V1__Initial_Schema.sql`
- Create: `db/migration/V2__Configure_CDC.sql`
- Remove: `application_db_rds/mysql_source_ddl.sql`
- Remove: `application_db_rds/activate_cdc.sql`

- [ ] **Step 1: Move DDL script**
Copy content from `application_db_rds/mysql_source_ddl.sql` to `db/migration/V1__Initial_Schema.sql`.

- [ ] **Step 2: Move CDC script**
Copy content from `application_db_rds/activate_cdc.sql` to `db/migration/V2__Configure_CDC.sql`.

- [ ] **Step 3: Remove old files**
Run: `rm application_db_rds/mysql_source_ddl.sql application_db_rds/activate_cdc.sql`

- [ ] **Step 4: Commit**
```bash
git add db/migration/
git rm application_db_rds/mysql_source_ddl.sql application_db_rds/activate_cdc.sql
git commit -m "chore: setup flyway migration structure"
```

---

### Task 2: Update Terraform Outputs

**Files:**
- Modify: `terraform/modules/rds/outputs.tf`
- Modify: `terraform/modules/dms/outputs.tf`

- [ ] **Step 1: Add RDS outputs**
Ensure `terraform/modules/rds/outputs.tf` has the following:
```hcl
output "db_instance_endpoint" {
  value = aws_db_instance.main.endpoint
}
output "db_instance_username" {
  value = aws_db_instance.main.username
}
output "db_instance_password" {
  value     = aws_db_instance.main.password
  sensitive = true
}
```

- [ ] **Step 2: Add DMS outputs**
Ensure `terraform/modules/dms/outputs.tf` has:
```hcl
output "replication_task_arn" {
  value = aws_dms_replication_task.main.replication_task_arn
}
```

- [ ] **Step 3: Commit**
```bash
git add terraform/modules/rds/outputs.tf terraform/modules/dms/outputs.tf
git commit -m "feat: add rds and dms outputs for automation"
```

---

### Task 3: Implement Flyway Automation

**Files:**
- Modify: `terraform/main.tf`

- [ ] **Step 1: Add Flyway null_resource**
Add this to the end of `terraform/main.tf`:
```hcl
resource "null_resource" "db_migration" {
  depends_on = [module.rds]

  triggers = {
    migration_hash = sha1(join("", [for f in fileset("${path.module}/../db/migration", "*.sql") : filesha1("${path.module}/../db/migration/${f}")]))
  }

  provisioner "local-exec" {
    command = <<-EOT
      flyway -url="jdbc:mysql://${module.rds.db_instance_endpoint}/dev" \
             -user="${module.rds.db_instance_username}" \
             -password="${module.rds.db_instance_password}" \
             -locations="filesystem:${path.module}/../db/migration" \
             migrate
    EOT
  }
}
```

- [ ] **Step 2: Commit**
```bash
git add terraform/main.tf
git commit -m "feat: automate rds migrations with flyway"
```

---

### Task 4: Automate DMS Start and Data Generation

**Files:**
- Modify: `terraform/main.tf`

- [ ] **Step 1: Add DMS and Lambda triggers**
Add these to `terraform/main.tf`:
```hcl
resource "null_resource" "start_dms_task" {
  depends_on = [null_resource.db_migration, module.dms]

  provisioner "local-exec" {
    command = "aws dms start-replication-task --replication-task-arn ${module.dms.replication_task_arn} --start-replication-task-type start-replication --region ${var.aws_region}"
  }
}

resource "null_resource" "trigger_generator" {
  depends_on = [null_resource.start_dms_task, module.lambda]

  provisioner "local-exec" {
    command = "aws lambda invoke --function-name ${module.lambda.function_name} --region ${var.aws_region} /tmp/lambda_response.json"
  }
}
```

- [ ] **Step 2: Commit**
```bash
git add terraform/main.tf
git commit -m "feat: automate dms start and initial data generation"
```

---

### Task 5: Verification

- [ ] **Step 1: Run Targeted Terraform Apply**
Run: 
```bash
cd terraform && terraform apply \
  -target=module.vpc \
  -target=module.s3 \
  -target=module.rds \
  -target=module.dms \
  -target=module.lambda \
  -target=null_resource.db_migration \
  -target=null_resource.start_dms_task \
  -target=null_resource.trigger_generator \
  -auto-approve
```
Expected: Infrastructure created, Flyway migrations run, DMS task starts, and Lambda is invoked.

- [ ] **Step 2: Verify S3 Landing**
Wait 2-3 minutes for DMS to replicate.
Run: `aws s3 ls s3://$(terraform output -raw bucket_name)/bronze/dev/`
Expected: Folders for Customer, Product, etc. with .csv files.
