# ===================================================================
# Glue IAM Role - Service Permissions
# ===================================================================
# Allows Glue to access S3, Secrets Manager, and CloudWatch Logs.
resource "aws_iam_role" "glue_role" {
  name = "${var.project_name}-${var.environment}-glue-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
}

# Custom Policy for specific bucket and secret access
resource "aws_iam_policy" "glue_policy" {
  name = "${var.project_name}-${var.environment}-glue-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.bucket_name}",
          "arn:aws:s3:::${var.bucket_name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = [var.redshift_secret_arn]
      },
      {
        Effect = "Allow"
        Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "glue_service_role" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy_attachment" "glue_custom_policy" {
  role       = aws_iam_role.glue_role.name
  policy_arn = aws_iam_policy.glue_policy.arn
}

# ===================================================================
# Glue Networking - Security Group
# ===================================================================
# Enables Glue jobs to communicate with Redshift and S3 within the VPC.
resource "aws_security_group" "glue" {
  name        = "${var.project_name}-${var.environment}-glue-sg"
  description = "Security group for Glue"
  vpc_id      = var.vpc_id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-glue-sg"
  }
}

# Allow Redshift access from Glue
resource "aws_security_group_rule" "redshift_ingress_glue" {
    type = "ingress"
    from_port = 5439
    to_port = 5439
    protocol = "tcp"
    source_security_group_id = aws_security_group.glue.id
    security_group_id        = var.redshift_security_group_id
}

# ===================================================================
# Glue Data Catalog - Central Database
# ===================================================================
resource "aws_glue_catalog_database" "main" {
  name = "${var.project_name}_${var.environment}_db"
}

# ===================================================================
# ETL Script Deployment - S3 Upload
# ===================================================================
# Automatically uploads all Python scripts to the scripts/ folder.
resource "aws_s3_object" "scripts" {
  for_each = fileset("${path.module}/../../../etl_glue_jobs", "**/*.py")
  
  bucket = var.bucket_name
  key    = "scripts/${basename(each.value)}"
  source = "${path.module}/../../../etl_glue_jobs/${each.value}"
  etag   = filemd5("${path.module}/../../../etl_glue_jobs/${each.value}")
}

# ===================================================================
# Glue Connection - Redshift Connectivity
# ===================================================================
# Configures the JDBC connection for loading data into the warehouse.
resource "aws_glue_connection" "redshift" {
  name = "redshift-connection"
  
  connection_properties = {
    JDBC_CONNECTION_URL = "jdbc:redshift://${var.redshift_endpoint}/dev"
    SECRET_ID           = var.redshift_secret_arn
  }

  physical_connection_requirements {
    availability_zone      = var.availability_zone
    security_group_id_list = [aws_security_group.glue.id]
    subnet_id              = var.subnet_ids[0]
  }
}

# ===================================================================
# Glue Classifier - Schema Detection Tweaks
# ===================================================================
# Ensures CSV headers are used as column names.
resource "aws_glue_classifier" "csv_header" {
  name = "${var.project_name}-${var.environment}-csv-classifier"

  csv_classifier {
    allow_single_column    = false
    contains_header        = "PRESENT"
    delimiter              = ","
    disable_value_trimming = false
    quote_symbol           = "\""
  }
}

# ===================================================================
# Glue Crawlers - Bronze Layer Schema Discovery
# ===================================================================
# Individual crawlers for each table in the Bronze (Raw) folder.
resource "aws_glue_crawler" "tables" {
  for_each = toset(["Customer", "Orders", "Product", "orderDetails"])

  database_name = aws_glue_catalog_database.main.name
  name          = "${var.project_name}-${var.environment}-crawler-${each.key}"
  role          = aws_iam_role.glue_role.arn
  classifiers   = [aws_glue_classifier.csv_header.name]

  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Tables = { TableThreshold = 1 }
    }
  })

  s3_target {
    path = "s3://${var.bucket_name}/bronze/dev/${each.key}/"
  }
  
  tags = {
    Name = "${var.project_name}-${var.environment}-crawler-${each.key}"
  }
}

# ===================================================================
# Glue Spark Jobs - Dynamic ETL Execution
# ===================================================================
# provisions all transform and load jobs with parameterized arguments.
resource "aws_glue_job" "job" {
  for_each = fileset("${path.module}/../../../etl_glue_jobs", "**/*.py")

  name         = "${var.project_name}-${var.environment}-${replace(basename(each.value), ".py", "")}"
  role_arn     = aws_iam_role.glue_role.arn
  glue_version = "4.0"

  command {
    script_location = "s3://${var.bucket_name}/scripts/${basename(each.value)}"
  }
  
  # Dynamic Arguments passed to Python scripts
  default_arguments = {
    "--job-language"        = "python"
    "--TempDir"             = "s3://${var.bucket_name}/temporary/"
    "--SOURCE_BUCKET"       = var.bucket_name
    "--GLUE_DATABASE"       = aws_glue_catalog_database.main.name
    "--TARGET_PREFIX"       = "silver/dev"
    "--REDSHIFT_CONNECTION" = aws_glue_connection.redshift.name
    "--STAGING_TABLE"       = "sales.stage_dim_${replace(lower(basename(each.value)), "load_processed_", "")}" # Default naming pattern
    "--job-bookmark-option" = "job-bookmark-enable"
  }

  execution_property {
    max_concurrent_runs = 1
  }

  connections = [aws_glue_connection.redshift.name]
}
