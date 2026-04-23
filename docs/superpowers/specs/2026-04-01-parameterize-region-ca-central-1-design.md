# Design Spec: Parameterize AWS Region and Availability Zones

Move the project deployment from `us-east-1` to `ca-central-1` (Canada Central) and parameterize the region and availability zones throughout the Terraform modules to improve portability and maintainability.

## User Requirements
- Deploy to `ca-central-1`.
- Use `ca-central-1a` as the primary availability zone.
- Parameterize the region and availability zones.

## Proposed Changes

### 1. Root Configuration (`/`)
- **`variables.tf`**:
    - Update `aws_region` default to `ca-central-1`.
    - Add `availability_zones` variable:
      ```hcl
      variable "availability_zones" {
        description = "List of availability zones to use"
        type        = list(string)
        default     = ["ca-central-1a", "ca-central-1b"]
      }
      ```
- **`main.tf`**:
    - Update `module "vpc"` to pass `aws_region = var.aws_region` and `availability_zones = var.availability_zones`.
    - Update `module "lambda"` to pass `aws_region = var.aws_region`.
    - Update `module "glue"` to use `availability_zone = var.availability_zones[0]`.

### 2. VPC Module (`modules/vpc/`)
- **`variables.tf`**: Add `aws_region` variable.
- **`main.tf`**:
    - Update `aws_vpc_endpoint.s3` service name to `com.amazonaws.${var.aws_region}.s3`.
    - Update `aws_vpc_endpoint.secretsmanager` service name to `com.amazonaws.${var.aws_region}.secretsmanager`.
    - Update `aws_vpc_endpoint.sts` service name to `com.amazonaws.${var.aws_region}.sts`.

### 3. Lambda Module (`modules/lambda/`)
- **`variables.tf`**: Add `aws_region` variable.
- **`main.tf`**: Update the `REGION_NAME` environment variable in the `aws_lambda_function.data_generator` resource to use `var.aws_region`.

## Verification Plan
1. Run `terraform validate` to check for syntax errors.
2. Run `terraform plan` to verify the intended changes (switching region and updating AZs).
3. Confirm that all VPC endpoint service names correctly reflect the new region.
4. Confirm that the Lambda environment variable `REGION_NAME` is updated.
