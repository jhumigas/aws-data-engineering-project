resource "aws_security_group" "redshift" {
  name        = "${var.project_name}-${var.environment}-redshift-sg"
  description = "Security group for Redshift cluster"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5439
    to_port     = 5439
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr] # Allow access from VPC (Glue/Lambda/EC2)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-redshift-sg"
  }
}

resource "aws_redshift_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-redshift-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.project_name}-${var.environment}-redshift-subnet-group"
  }
}

# Role for Redshift to access S3 (Spectrum or Copy/Unload)
resource "aws_iam_role" "redshift_role" {
  name = "${var.project_name}-${var.environment}-redshift-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "redshift.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "redshift_s3_policy" {
  name = "${var.project_name}-${var.environment}-redshift-s3-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.bucket_arn,
          "${var.bucket_arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "redshift_s3_attach" {
  role       = aws_iam_role.redshift_role.name
  policy_arn = aws_iam_policy.redshift_s3_policy.arn
}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+"
}

resource "aws_redshift_cluster" "main" {
  cluster_identifier = "${var.project_name}-${var.environment}-redshift"
  database_name      = "dev" # Default DB name
  master_username    = "adminuser"
  master_password    = random_password.password.result
  node_type          = "ra3.large" # Changed for availability
  cluster_type       = "single-node"
  
  cluster_subnet_group_name = aws_redshift_subnet_group.main.name
  vpc_security_group_ids    = [aws_security_group.redshift.id]
  iam_roles                 = [aws_iam_role.redshift_role.arn]
  
  skip_final_snapshot = true
  publicly_accessible = false

  tags = {
    Name = "${var.project_name}-${var.environment}-redshift"
  }
}

# Secrets Manager for Redshift
resource "aws_secretsmanager_secret" "redshift_credentials" {
  name = "${var.project_name}/${var.environment}/redshift-credentials"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "redshift_credentials" {
  secret_id     = aws_secretsmanager_secret.redshift_credentials.id
  secret_string = jsonencode({
    username            = aws_redshift_cluster.main.master_username
    password            = aws_redshift_cluster.main.master_password
    engine              = "redshift"
    host                = aws_redshift_cluster.main.endpoint
    port                = 5439
    dbClusterIdentifier = aws_redshift_cluster.main.cluster_identifier
  })
}
