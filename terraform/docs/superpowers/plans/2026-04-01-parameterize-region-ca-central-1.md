# Parameterize Region and AZs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move project deployment from `us-east-1` to `ca-central-1` and parameterize the region and availability zones throughout the Terraform modules.

**Architecture:** Update the root `variables.tf` and `main.tf` to define and pass `aws_region` and `availability_zones` to modules. Update `vpc` and `lambda` modules to accept and use these variables for resource configuration (VPC endpoints and Lambda environment variables).

**Tech Stack:** Terraform (AWS Provider)

---

### Task 1: Update Root Variables

**Files:**
- Modify: `variables.tf`

- [ ] **Step 1: Update root `variables.tf`**

Update `aws_region` default to `ca-central-1` and add `availability_zones` variable.

```hcl
variable "aws_region" {
  description = "AWS Region to deploy resources"
  type        = string
  default     = "ca-central-1"
}

variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
  default     = ["ca-central-1a", "ca-central-1b"]
}
```

- [ ] **Step 2: Commit**

```bash
git add variables.tf
git commit -m "feat: parameterize region and add availability_zones to root variables"
```

---

### Task 2: Update VPC Module Variables

**Files:**
- Modify: `modules/vpc/variables.tf`

- [ ] **Step 1: Add `aws_region` and update `availability_zones`**

```hcl
variable "aws_region" {
  type        = string
  description = "AWS Region to use for VPC endpoints"
}

variable "availability_zones" {
  type    = list(string)
  default = ["ca-central-1a", "ca-central-1b"]
}
```

- [ ] **Step 2: Commit**

```bash
git add modules/vpc/variables.tf
git commit -m "feat: add aws_region and update availability_zones in vpc module variables"
```

---

### Task 3: Update VPC Module Main

**Files:**
- Modify: `modules/vpc/main.tf`

- [ ] **Step 1: Parameterize VPC endpoint service names**

Replace hardcoded `us-east-1` with `${var.aws_region}` in VPC endpoint definitions.

```hcl
# VPC Endpoints (Gateway for S3)
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [aws_route_table.public.id] # Add private route tables if creating NAT Gateway
}

# ... (rest of security group vpce) ...

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type = "Interface"
  subnet_ids        = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.vpce.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "sts" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.sts"
  vpc_endpoint_type = "Interface"
  subnet_ids        = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.vpce.id]
  private_dns_enabled = true
}
```

- [ ] **Step 2: Commit**

```bash
git add modules/vpc/main.tf
git commit -m "feat: parameterize VPC endpoint service names with aws_region"
```

---

### Task 4: Update Lambda Module Variables

**Files:**
- Modify: `modules/lambda/variables.tf`

- [ ] **Step 1: Add `aws_region` variable**

```hcl
variable "aws_region" {
  type        = string
  description = "AWS Region to use for Lambda environment variables"
}
```

- [ ] **Step 2: Commit**

```bash
git add modules/lambda/variables.tf
git commit -m "feat: add aws_region variable to lambda module"
```

---

### Task 5: Update Lambda Module Main

**Files:**
- Modify: `modules/lambda/main.tf`

- [ ] **Step 1: Update `REGION_NAME` environment variable**

Update `aws_lambda_function.data_generator` environment variables.

```hcl
  environment {
    variables = {
      SECRET_NAME = var.rds_secret_arn # The code uses getenv("SECRET_NAME")
      REGION_NAME = var.aws_region
    }
  }
```

- [ ] **Step 2: Commit**

```bash
git add modules/lambda/main.tf
git commit -m "feat: parameterize REGION_NAME in lambda environment variables"
```

---

### Task 6: Update Root Main

**Files:**
- Modify: `main.tf`

- [ ] **Step 1: Pass new variables to modules**

Update `vpc`, `lambda`, and `glue` module calls.

```hcl
module "vpc" {
  source = "./modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = "10.0.0.0/16" 
  aws_region         = var.aws_region
  availability_zones = var.availability_zones
}

# ... (s3, rds, dms modules) ...

module "lambda" {
  source = "./modules/lambda"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.private_subnet_ids
  rds_secret_arn        = module.rds.secret_arn
  rds_security_group_id = module.rds.security_group_id
  aws_region            = var.aws_region
}

# ... (redshift module) ...

module "glue" {
  source = "./modules/glue"

  project_name               = var.project_name
  environment                = var.environment
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.private_subnet_ids
  availability_zone          = var.availability_zones[0]
  bucket_name                = module.s3.bucket_id
  redshift_secret_arn        = module.redshift.redshift_secret_arn
  redshift_security_group_id = module.redshift.redshift_security_group_id
}
```

- [ ] **Step 2: Commit**

```bash
git add main.tf
git commit -m "feat: pass aws_region and availability_zones to modules in root main.tf"
```

---

### Task 7: Verification

- [ ] **Step 1: Run `terraform validate`**

Run: `terraform validate`
Expected: SUCCESS

- [ ] **Step 2: Run `terraform plan`**

Run: `terraform plan`
Expected: Check plan output for region changes (`us-east-1` to `ca-central-1`) and AZ updates. Verify VPC endpoints and Lambda environment variables.

- [ ] **Step 3: Commit**

```bash
# No changes to commit, just record success.
```
