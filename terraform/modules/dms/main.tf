# ===================================================================
# DMS Security Group - Replication Network Access
# ===================================================================
# Defines firewall rules for the DMS Replication Instance.
# It must be able to reach the RDS source and be reached by admins (if needed).
resource "aws_security_group" "dms" {
  name        = "${var.project_name}-${var.environment}-dms-sg"
  description = "Security group for DMS replication instance"
  vpc_id      = var.vpc_id

  # Allow all internal traffic within the SG for management/coordination
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # Allow traffic from the entire VPC CIDR for connectivity to endpoints
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"] 
  }

  # Allow all outbound traffic to reach RDS and S3/Secrets Manager endpoints
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-dms-sg"
  }
}

# ===================================================================
# DMS Subnet Group - Multi-AZ Deployment
# ===================================================================
# Defines which subnets DMS can use. We use private subnets for security.
resource "aws_dms_replication_subnet_group" "main" {
  replication_subnet_group_id          = "${var.project_name}-${var.environment}-dms-subnet-group"
  replication_subnet_group_description = "DMS subnet group"
  subnet_ids                           = var.subnet_ids

  tags = {
    Name = "${var.project_name}-${var.environment}-dms-subnet-group"
  }
}

# ===================================================================
# DMS Replication Instance - The CDC Engine
# ===================================================================
# The compute resource that executes the migration task and captures changes.
resource "aws_dms_replication_instance" "main" {
  replication_instance_id    = "${var.project_name}-${var.environment}-dms-instance"
  replication_instance_class = "dms.t3.medium" # Minimum class for stable CDC
  allocated_storage          = 20 # Storage for logs and swap space
  
  replication_subnet_group_id = aws_dms_replication_subnet_group.main.id
  vpc_security_group_ids      = [aws_security_group.dms.id]

  tags = {
    Name = "${var.project_name}-${var.environment}-dms-instance"
  }
}

# ===================================================================
# DMS Source Endpoint - RDS MySQL
# ===================================================================
# Connects DMS to the source database. 
# Uses Secrets Manager for credential retrieval.
resource "aws_dms_endpoint" "source" {
  endpoint_id   = "${var.project_name}-${var.environment}-source-endpoint"
  endpoint_type = "source"
  engine_name   = "mysql"
  
  # Security/Auth: Fetch connection info directly from Secrets Manager
  secrets_manager_arn             = var.source_secret_arn
  secrets_manager_access_role_arn = aws_iam_role.dms_secrets_role.arn

  tags = {
    Name = "${var.project_name}-${var.environment}-source-endpoint"
  }
}

# ===================================================================
# IAM Role for DMS - Secrets Manager Access
# ===================================================================
# Allows DMS to assume a role to read the RDS credentials.
resource "aws_iam_role" "dms_secrets_role" {
  name = "${var.project_name}-${var.environment}-dms-secrets-role"

  # Trust Policy: Specifically includes regional principal for ca-central-1
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "dms.amazonaws.com",
            "dms.${var.aws_region}.amazonaws.com"
          ]
        }
      }
    ]
  })
}

# IAM Policy for Secrets Retrieval
resource "aws_iam_policy" "dms_secrets_policy" {
  name = "${var.project_name}-${var.environment}-dms-secrets-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = [var.source_secret_arn]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dms_secrets_attach" {
  role       = aws_iam_role.dms_secrets_role.name
  policy_arn = aws_iam_policy.dms_secrets_policy.arn
}

# ===================================================================
# DMS Target Endpoint - S3 (Bronze Layer)
# ===================================================================
# Connects DMS to the S3 bucket to land raw data as CSV.
resource "aws_dms_endpoint" "target" {
  endpoint_id   = "${var.project_name}-${var.environment}-target-endpoint"
  endpoint_type = "target"
  engine_name   = "s3"
  
  # Landing Zone Settings
  s3_settings {
    bucket_name             = var.target_bucket_name
    bucket_folder           = "bronze" # Raw data lands here
    service_access_role_arn = aws_iam_role.dms_s3_role.arn
    data_format             = "csv"
    timestamp_column_name   = "db_timestamp" # Metadata column for CDC tracking
    add_column_name         = true           # Ensure headers are included in CSVs
    include_op_for_full_load = true          # Include 'Op' column even in full load files
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-target-endpoint"
  }
}

# ===================================================================
# IAM Role for DMS - S3 Bucket Access
# ===================================================================
# Allows DMS to write files into the Data Lake.
resource "aws_iam_role" "dms_s3_role" {
  name = "${var.project_name}-${var.environment}-dms-s3-role"

  # Trust Policy: Includes regional principal to avoid assume-role errors
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "dms.amazonaws.com",
            "dms.${var.aws_region}.amazonaws.com"
          ]
        }
      }
    ]
  })
}

# IAM Policy for S3 Data Archival
resource "aws_iam_policy" "dms_s3_policy" {
  name = "${var.project_name}-${var.environment}-dms-s3-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.target_bucket_name}",
          "arn:aws:s3:::${var.target_bucket_name}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dms_s3_attach" {
  role       = aws_iam_role.dms_s3_role.name
  policy_arn = aws_iam_policy.dms_s3_policy.arn
}

# ===================================================================
# RDS Ingress Rule for DMS
# ===================================================================
# Explicitly allows the DMS Security Group to reach RDS on port 3306.
resource "aws_security_group_rule" "rds_ingress_dms" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.dms.id
  security_group_id        = var.rds_security_group_id
}

# ===================================================================
# DMS Replication Task - RDS to S3
# ===================================================================
# Replicates all tables from 'dev' schema using Full Load + CDC.
resource "aws_dms_replication_task" "main" {
  replication_task_id      = "${var.project_name}-${var.environment}-replication-task"
  migration_type           = "full-load-and-cdc" # Capture initial data and ongoing changes
  
  # Table Selection: Include everything from 'dev' schema
  table_mappings           = jsonencode({
    rules = [
      {
        "rule-type": "selection",
        "rule-id": "1",
        "rule-name": "1",
        "object-locator": {
          "schema-name": "dev",
          "table-name": "%"
        },
        "rule-action": "include"
      }
    ]
  })

  replication_instance_arn = aws_dms_replication_instance.main.replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.source.endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.target.endpoint_arn
  
  # Start manually after schema is ready (handled by null_resource in main.tf)
  start_replication_task = false 

  replication_task_settings = jsonencode({
    Logging = {
      EnableLogging = true # Essential for debugging CDC issues
    }
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-replication-task"
  }
}
