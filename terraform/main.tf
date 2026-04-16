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

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.public_subnet_ids
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
}

# Update: Need to better handle bucket name extraction or update S3 module.
# S3 module outputs bucket_id which IS the name.
# Re-checking S3 module output:
# output "bucket_id" { value = aws_s3_bucket.main.id } -> This is the name.
# output "bucket_arn" { value = aws_s3_bucket.main.arn }
# So I can just use module.s3.bucket_id

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
  triggers = {
    migration_sha1 = sha1(join("", [for f in fileset("${path.module}/../db/migration", "*.sql") : filesha1("${path.module}/../db/migration/${f}")]))
  }

  provisioner "local-exec" {
    command = <<-EOT
      flyway migrate \
        -url=jdbc:mysql://${module.rds.db_instance_endpoint}/dev \
        -user=${module.rds.db_instance_username} \
        -password='${module.rds.db_instance_password}' \
        -locations=filesystem:${path.module}/../db/migration
    EOT
  }

  depends_on = [module.rds]
}
