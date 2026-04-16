# Glue IAM Role
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


# Security Group for Glue
resource "aws_security_group" "glue" {
  name        = "${var.project_name}-${var.environment}-glue-sg"
  description = "Security group for Glue"
  vpc_id      = var.vpc_id

  # Allow self-reference
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
    security_group_id = var.redshift_security_group_id
}


resource "aws_glue_catalog_database" "main" {
  name = "${var.project_name}_${var.environment}_db"
}

# Upload scripts to S3
resource "aws_s3_object" "scripts" {
  for_each = fileset("${path.module}/../../../etl_glue_jobs", "*.py")
  
  bucket = var.bucket_name
  key    = "scripts/${each.value}"
  source = "${path.module}/../../../etl_glue_jobs/${each.value}"
  etag   = filemd5("${path.module}/../../../etl_glue_jobs/${each.value}")
}

# Glue Connection
resource "aws_glue_connection" "redshift" {
  name = "redshift-connection"
  
  connection_properties = {
    JDBC_CONNECTION_URL = "jdbc:redshift://..." # Ideally get from Redshift directly but we can't easily here without more inputs. 
                                                # Use Secrets Manager usually or construct if we have endpoint.
                                                # For now, skipping detailed connection string construction to avoid errors
                                                # or assumes the script picks it up from Secrets Manager.
                                                # But Glue Connection object represents network.
    SECRET_ID = var.redshift_secret_arn
  }

  physical_connection_requirements {
    availability_zone = var.availability_zone
    security_group_id_list = [aws_security_group.glue.id]
    subnet_id = var.subnet_ids[0]
  }
}

# Crawler
resource "aws_glue_crawler" "bronze" {
  database_name = aws_glue_catalog_database.main.name
  name          = "${var.project_name}-${var.environment}-bronze-crawler"
  role          = aws_iam_role.glue_role.arn

  s3_target {
    path = "s3://${var.bucket_name}/bronze/"
  }
  
  tags = {
    Name = "${var.project_name}-${var.environment}-bronze-crawler"
  }
}

# Jobs
resource "aws_glue_job" "job" {
  for_each = fileset("${path.module}/../../../etl_glue_jobs", "*.py")

  name     = "${var.project_name}-${var.environment}-${replace(each.value, ".py", "")}"
  role_arn = aws_iam_role.glue_role.arn
  glue_version = "4.0"

  command {
    script_location = "s3://${var.bucket_name}/scripts/${each.value}"
  }
  
  default_arguments = {
    "--job-language" = "python"
    "--TempDir"      = "s3://${var.bucket_name}/temporary/"
  }

  execution_property {
    max_concurrent_runs = 1
  }

  connections = [aws_glue_connection.redshift.name] # Attach connection to all jobs for simplicity, or select specific ones
}
