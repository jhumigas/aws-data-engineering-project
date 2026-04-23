# ===================================================================
# RDS DB Subnet Group - VPC Networking
# ===================================================================
# Defines the subnets across multiple availability zones for the DB.
# Ensures high availability and compliance with VPC isolation standards.
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.project_name}-${var.environment}-db-subnet-group"
  }
}

# ===================================================================
# RDS Security Group - Database Firewall
# ===================================================================
# Controls inbound and outbound traffic for the RDS instance.
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Security group for RDS instance"
  vpc_id      = var.vpc_id

  # Inbound Rule: Allow MySQL traffic from anywhere (Demo/Walkthrough purposes)
  # In production, this would be restricted to specific application security groups.
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  # Inbound Rule: Allow the SG to reach itself (for internal management)
  ingress {
    from_port = 3306
    to_port   = 3306
    protocol  = "tcp"
    self      = true
  }

  # Outbound Rule: Allow all traffic for updates and external integration
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-sg"
  }
}

# ===================================================================
# RDS Parameter Group - CDC Optimization
# ===================================================================
# Custom database parameters to enable Binary Logging (required for CDC).
# Ensures that DMS can capture changes from the MySQL binlogs.
resource "aws_db_parameter_group" "mysql_cdc" {
  name        = "${var.project_name}-${var.environment}-mysql-cdc-pg"
  family      = "mysql8.0"
  description = "Parameter group for MySQL with CDC enabled"

  # Use ROW format for granular change capture
  parameter {
    name  = "binlog_format"
    value = "ROW"
  }

  # Ensure the Full row image is captured for data integrity
  parameter {
    name  = "binlog_row_image"
    value = "Full"
  }

  # Disable checksums for binlogs to simplify DMS reading
  parameter {
    name  = "binlog_checksum"
    value = "NONE"
  }
}

# ===================================================================
# RDS DB Instance - MySQL Transactional Database
# ===================================================================
# The primary source of truth for the data engineering project.
resource "aws_db_instance" "main" {
  identifier        = "${var.project_name}-${var.environment}-mysql"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro" # Free tier eligible instance
  allocated_storage = 20 # Standard disk space for small-scale dev
  storage_type      = "gp2"
  username          = "admin"
  password          = var.db_password
  db_name           = "dev" # Default database schema

  # Advanced Configuration
  parameter_group_name    = aws_db_parameter_group.mysql_cdc.name
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  
  # Operational Settings
  skip_final_snapshot     = true # Speeds up destruction during testing
  publicly_accessible     = true # Allows local DBeaver connection for demo
  backup_retention_period = 1    # Essential to enable binary logs for CDC

  tags = {
    Name = "${var.project_name}-${var.environment}-mysql"
  }
}

# ===================================================================
# AWS Secrets Manager - Automated Credential Storage
# ===================================================================
# Securely stores the database connection details.
# Other services (DMS, Lambda) retrieve these instead of hardcoding.
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.project_name}/${var.environment}/mysql-credentials"
  recovery_window_in_days = 0 # Immediate deletion for iterative testing
}

# Secrets Version - Stores JSON Payload of Credentials
resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = aws_db_instance.main.username
    password = aws_db_instance.main.password
    engine   = aws_db_instance.main.engine
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = aws_db_instance.main.db_name
  })
}
