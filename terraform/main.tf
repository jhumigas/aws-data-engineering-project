# ===================================================================
# VPC Module - Network Foundation
# ===================================================================
# Provisions the VPC, subnets, and endpoints required for the project.
module "vpc" {
  source = "./modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = "10.0.0.0/16"
  aws_region         = var.aws_region
  availability_zones = var.availability_zones
}

# ===================================================================
# S3 Module - Data Lake Storage (Bronze/Silver/Gold)
# ===================================================================
# Provisions the S3 bucket and foundational folder structure.
module "s3" {
  source = "./modules/s3"

  project_name = var.project_name
  environment  = var.environment
}

# ===================================================================
# RDS Module - Source Transactional Database
# ===================================================================
# Provisions the MySQL database with CDC and backup retention enabled.
module "rds" {
  source = "./modules/rds"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.public_subnet_ids # RDS deployed in public for demo ease
  db_password  = var.db_password
}

# ===================================================================
# DMS Module - CDC Replication Engine
# ===================================================================
# Orchestrates data movement from RDS (MySQL) to S3 (Bronze).
module "dms" {
  source = "./modules/dms"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.private_subnet_ids # DMS workers in private subnets
  source_secret_arn     = module.rds.secret_arn
  rds_security_group_id = module.rds.security_group_id
  target_bucket_name    = module.s3.bucket_id
  aws_region            = var.aws_region
}

# ===================================================================
# Lambda Module - Data Generation Utility
# ===================================================================
# Packages and deploys the Python generator to simulate live traffic.
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

# ===================================================================
# Redshift Module - Data Warehouse
# ===================================================================
# Provisions the analytics cluster for final data modeling.
module "redshift" {
  source = "./modules/redshift"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnet_ids
  vpc_cidr     = module.vpc.vpc_cidr_block
  bucket_arn   = module.s3.bucket_arn
}

# ===================================================================
# Glue Module - Serverless ETL (Spark)
# ===================================================================
# Manages crawlers and jobs to transform data from Bronze to Silver.
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
  redshift_endpoint          = module.redshift.redshift_endpoint
}

# ===================================================================
# Step Functions Module - ETL Orchestrator
# ===================================================================
# Defines the state machine to run Glue jobs in sequence.
module "step_functions" {
  source = "./modules/step_functions"

  project_name                = var.project_name
  environment                 = var.environment
  glue_job_names              = module.glue.job_names_map
  glue_crawler_names          = module.glue.crawler_names
  redshift_cluster_identifier = module.redshift.cluster_identifier
  redshift_database           = module.redshift.database_name
}

# ===================================================================
# S3 Bucket Policy - Centralized Access Control
# ===================================================================
# Grants Glue, DMS, and Redshift permissions to interact with the Data Lake.
resource "aws_s3_bucket_policy" "bucket_access" {
  bucket = module.s3.bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = [
            module.dms.s3_role_arn,
            module.glue.role_arn,
            module.redshift.role_arn
          ]
        }
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:PutObjectTagging",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts"
        ]
        Resource = [
          module.s3.bucket_arn,
          "${module.s3.bucket_arn}/*"
        ]
      }
    ]
  })
}
