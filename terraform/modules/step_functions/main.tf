# ===================================================================
# Step Functions IAM Role - Service Permissions
# ===================================================================
# Allows Step Functions to trigger Glue and Redshift Data API.
resource "aws_iam_role" "sfn_role" {
  name = "${var.project_name}-${var.environment}-sfn-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })
}

# custom policy for Glue and Redshift interaction
resource "aws_iam_policy" "sfn_policy" {
  name = "${var.project_name}-${var.environment}-sfn-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "glue:StartJobRun",
          "glue:GetJobRun",
          "glue:StartCrawler",
          "glue:GetCrawler"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "redshift-data:ExecuteStatement",
          "redshift-data:DescribeStatement",
          "redshift-data:GetStatementResult"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sfn_attach" {
  role       = aws_iam_role.sfn_role.name
  policy_arn = aws_iam_policy.sfn_policy.arn
}

# ===================================================================
# Step Functions State Machine - ETL Orchestrator
# ===================================================================
# Coordinates the sequential flow: Discovery -> Transform -> Load -> Merge.
resource "aws_sfn_state_machine" "main" {
  name     = "${var.project_name}-${var.environment}-state-machine"
  role_arn = aws_iam_role.sfn_role.arn

  definition = jsonencode({
    Comment = "Orchestrate Glue Discovery, Transform, and Redshift Load"
    StartAt = "StartCrawlers"
    States = {
      # 1. Parallel Discovery of raw Bronze data
      StartCrawlers = {
        Type = "Parallel"
        Next = "RunTransformJobs"
        Branches = [
          for crawler in var.glue_crawler_names : {
            StartAt = "Run_${crawler}"
            States = {
              "Run_${crawler}" = {
                Type     = "Task"
                Resource = "arn:aws:states:::aws-sdk:glue:startCrawler"
                Parameters = { "Name": crawler }
                End      = true
              }
            }
          }
        ]
      }

      # 2. Parallel Transform (Bronze -> Silver Parquet)
      RunTransformJobs = {
        Type = "Parallel"
        Next = "RunLoadJobs"
        Branches = [
          for path, name in var.glue_job_names : {
            StartAt = "Job_${name}"
            States = {
              "Job_${name}" = {
                Type     = "Task"
                Resource = "arn:aws:states:::glue:startJobRun.sync"
                Parameters = { "JobName": name }
                End      = true
              }
            }
          } if length(regexall("transform", path)) > 0
        ]
      }

      # 3. Parallel Load (Silver -> Redshift Staging)
      RunLoadJobs = {
        Type = "Parallel"
        Next = "MergeCustomerDim"
        Branches = [
          for path, name in var.glue_job_names : {
            StartAt = "Job_${name}"
            States = {
              "Job_${name}" = {
                Type     = "Task"
                Resource = "arn:aws:states:::glue:startJobRun.sync"
                Parameters = { "JobName": name }
                End      = true
              }
            }
          } if length(regexall("load", path)) > 0
        ]
      }

      # 4. Redshift SCD Type 2 Merge - Customer Dimension
      MergeCustomerDim = {
        Type = "Task"
        Next = "MergeProductDim"
        Resource = "arn:aws:states:::aws-sdk:redshiftdata:executeStatement"
        Parameters = {
          ClusterIdentifier = var.redshift_cluster_identifier
          Database          = var.redshift_database
          DbUser            = "adminuser"
          Sql               = "CALL sales.sp_merge_dim_customer();"
        }
      }

      # 5. Redshift SCD Type 2 Merge - Product Dimension
      MergeProductDim = {
        Type = "Task"
        End = true
        Resource = "arn:aws:states:::aws-sdk:redshiftdata:executeStatement"
        Parameters = {
          ClusterIdentifier = var.redshift_cluster_identifier
          Database          = var.redshift_database
          DbUser            = "adminuser"
          Sql               = "CALL sales.sp_merge_dim_product();"
        }
      }
    }
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-state-machine"
  }
}

# ===================================================================
# EventBridge Schedule - Pipeline Trigger
# ===================================================================
resource "aws_cloudwatch_event_rule" "sfn_schedule" {
  name                = "${var.project_name}-${var.environment}-sfn-schedule"
  description         = "Schedule for Step Functions"
  schedule_expression = "rate(1 hour)"
}

resource "aws_cloudwatch_event_target" "sfn_target" {
  rule      = aws_cloudwatch_event_rule.sfn_schedule.name
  target_id = "SendToStepFunctions"
  arn       = aws_sfn_state_machine.main.arn
  role_arn  = aws_iam_role.eventbridge_sfn_role.arn
}

# Role for EventBridge to invoke Step Functions
resource "aws_iam_role" "eventbridge_sfn_role" {
  name = "${var.project_name}-${var.environment}-eb-sfn-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "eventbridge_sfn_policy" {
  name = "${var.project_name}-${var.environment}-eb-sfn-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["states:StartExecution"]
        Resource = [aws_sfn_state_machine.main.arn]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eventbridge_sfn_attach" {
  role       = aws_iam_role.eventbridge_sfn_role.name
  policy_arn = aws_iam_policy.eventbridge_sfn_policy.arn
}
