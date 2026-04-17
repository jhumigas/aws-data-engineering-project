module "vpc" {
  source = "./modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = "10.0.0.0/16"
  aws_region         = var.aws_region
  availability_zones = var.availability_zones
}

module "s3" {
  source = "./modules/s3"

  project_name = var.project_name
  environment  = var.environment
}

module "rds" {
  source = "./modules/rds"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.public_subnet_ids
  # allowed_security_group_ids passed if needed, or rely on internal rules
}

module "dms" {
  source = "./modules/dms"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.private_subnet_ids # DMS typically in private
  source_secret_arn     = module.rds.secret_arn
  rds_security_group_id = module.rds.security_group_id
  target_bucket_name    = module.s3.bucket_id
  aws_region            = var.aws_region
}

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

module "redshift" {
  source = "./modules/redshift"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnet_ids
  vpc_cidr     = module.vpc.vpc_cidr_block
  bucket_arn   = module.s3.bucket_arn
}

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

module "step_functions" {
  source = "./modules/step_functions"

  project_name   = var.project_name
  environment    = var.environment
  glue_job_names = module.glue.job_names
}

resource "null_resource" "db_migration" {
  depends_on = [module.rds]

  triggers = {
    migration_hash = sha1(join("", [for f in fileset("${path.module}/../db/migration", "*.sql") : filesha1("${path.module}/../db/migration/${f}")]))
  }

  provisioner "local-exec" {
    environment = {
      FLYWAY_PASSWORD = module.rds.db_instance_password
    }
    command = <<-EOT
      bash ${path.module}/../db/migrate.sh \
           ${replace(module.rds.db_instance_endpoint, ":3306", "")} \
           ${module.rds.db_instance_username}
    EOT
  }
}

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
