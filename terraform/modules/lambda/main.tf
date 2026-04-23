# ===================================================================
# Lambda Security Group - Network Isolation
# ===================================================================
# Provides network access for the Lambda function within the VPC.
resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-${var.environment}-lambda-sg"
  description = "Security group for Lambda function"
  vpc_id      = var.vpc_id

  # Outbound Rule: Allow all traffic to communicate with RDS and AWS Services
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-lambda-sg"
  }
}

# ===================================================================
# RDS Ingress Rule for Lambda
# ===================================================================
# Allows the Lambda function to connect to the MySQL database.
resource "aws_security_group_rule" "rds_ingress_lambda" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lambda.id
  security_group_id        = var.rds_security_group_id
}

# ===================================================================
# AWS Lambda Function - Data Generator
# ===================================================================
# Simulates application traffic by inserting/updating data in RDS.
resource "aws_lambda_function" "data_generator" {
  filename      = "${path.module}/lambda_function.zip"
  function_name = "${var.project_name}-${var.environment}-data-generator"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler" 
  runtime       = "python3.13"
  timeout       = 300 # 5 minute execution limit

  # VPC Configuration: Runs in private subnets for DB access
  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  source_code_hash = filebase64sha256("${path.module}/lambda_function.zip")

  # Environment Variables for DB Connectivity
  environment {
    variables = {
      SECRET_NAME = var.rds_secret_arn
      REGION_NAME = var.aws_region
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-data-generator"
  }
}

# ===================================================================
# IAM Role for Lambda - Execution Permissions
# ===================================================================
# Defines what AWS resources the Lambda can interact with.
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-${var.environment}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy: Secrets Manager, VPC Access, and CloudWatch Logs
resource "aws_iam_policy" "lambda_policy" {
  name = "${var.project_name}-${var.environment}-lambda-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = [var.rds_secret_arn]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
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

resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# ===================================================================
# EventBridge Schedule - Automated Triggering
# ===================================================================
# Automatically triggers the Lambda every 5 minutes to simulate load.
resource "aws_cloudwatch_event_rule" "schedule" {
  name                = "${var.project_name}-${var.environment}-data-gen-schedule"
  description         = "Schedule for data generation"
  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.schedule.name
  target_id = "SendToLambda"
  arn       = aws_lambda_function.data_generator.arn
}

# Grant EventBridge permission to invoke the Lambda
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_generator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule.arn
}
