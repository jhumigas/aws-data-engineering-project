resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-${var.environment}-lambda-sg"
  description = "Security group for Lambda function"
  vpc_id      = var.vpc_id

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

# Allow Lambda to access RDS (Updating RDS SG rule here or in RDS module? 
# Usually better to do it via a separate rule or referencing SG IDs.
# I'll create a rule here attached to the RDS SG to allow this Lambda SG)
resource "aws_security_group_rule" "rds_ingress_lambda" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lambda.id
  security_group_id        = var.rds_security_group_id
}

resource "null_resource" "lambda_build" {
  triggers = {
    pyproject = filemd5("${path.module}/../../../data_generator_lambda/pyproject.toml")
    lock      = filemd5("${path.module}/../../../data_generator_lambda/uv.lock")
    handler   = filemd5("${path.module}/../../../data_generator_lambda/lambda_function.py")
    fix       = "3" # Force re-run
  }

  provisioner "local-exec" {
    command = <<-EOT
      cd ${path.module}/../../../data_generator_lambda
      rm -rf build
      mkdir -p build
      uv pip install \
        --no-installer-metadata \
        --no-compile-bytecode \
        --python-platform x86_64-manylinux2014 \
        --python 3.13 \
        --target build/ \
        -r pyproject.toml
      cp lambda_function.py build/
    EOT
  }
}

data "archive_file" "lambda_zip" {
  depends_on  = [null_resource.lambda_build]
  type        = "zip"
  source_dir  = "${path.module}/../../../data_generator_lambda/build/"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "data_generator" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "${var.project_name}-${var.environment}-data-generator"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler" 
  runtime       = "python3.13" # Match the file info if possible, or leave as latest
  timeout       = 300 # 5 minutes

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      SECRET_NAME = var.rds_secret_arn # The code uses getenv("SECRET_NAME")
      REGION_NAME = var.aws_region
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-data-generator"
  }
}

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

resource "aws_iam_policy" "lambda_policy" {
  name = "${var.project_name}-${var.environment}-lambda-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
        ]
        Resource = [var.rds_secret_arn]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*" # VPC privileges needed
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

# EventBridge Schedule
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

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_generator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule.arn
}
