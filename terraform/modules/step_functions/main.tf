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

# Custom policy for Glue and Redshift interaction
resource "aws_iam_policy" "sfn_policy" {
  name = "${var.project_name}-${var.environment}-sfn-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "glue:StartJobRun",
          "glue:GetJobRun"
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
      },
      {
        Effect = "Allow"
        Action = [
          "redshift:GetClusterCredentials"
        ]
        Resource = ["*"]
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
# Coordinates: Parallel Dimension Load/Merge -> Parallel Fact Load
resource "aws_sfn_state_machine" "main" {
  name     = "${var.project_name}-${var.environment}-state-machine"
  role_arn = aws_iam_role.sfn_role.arn

  definition = jsonencode({
    Comment = "Orchestrate Glue ETL and Redshift Merge"
    StartAt = "Parallel_Load_Dimensions"
    States = {
      # 1. Parallel Load/Merge Dimensions
      Parallel_Load_Dimensions = {
        Type = "Parallel"
        Next = "Parallel_Load_Facts"
        Branches = [
          {
            StartAt = "Glue_Transform_Load_Customer"
            States = {
              Glue_Transform_Load_Customer = {
                Type     = "Task"
                Resource = "arn:aws:states:::glue:startJobRun.sync"
                Parameters = { "JobName": var.glue_job_names["load_processed_customers"] }
                Next = "SP_Merge_Customer"
              }
              SP_Merge_Customer = {
                Type     = "Task"
                Resource = "arn:aws:states:::aws-sdk:redshiftdata:executeStatement"
                Parameters = {
                  ClusterIdentifier = var.redshift_cluster_identifier
                  Database          = var.redshift_database
                  DbUser            = "adminuser"
                  Sql               = "CALL sales.sp_merge_dim_customer();"
                }
                End = true
              }
            }
          },
          {
            StartAt = "Glue_Transform_Load_Product"
            States = {
              Glue_Transform_Load_Product = {
                Type     = "Task"
                Resource = "arn:aws:states:::glue:startJobRun.sync"
                Parameters = { "JobName": var.glue_job_names["load_processed_products"] }
                Next = "SP_Merge_Product"
              }
              SP_Merge_Product = {
                Type     = "Task"
                Resource = "arn:aws:states:::aws-sdk:redshiftdata:executeStatement"
                Parameters = {
                  ClusterIdentifier = var.redshift_cluster_identifier
                  Database          = var.redshift_database
                  DbUser            = "adminuser"
                  Sql               = "CALL sales.sp_merge_dim_product();"
                }
                End = true
              }
            }
          }
        ]
      }

      # 2. Parallel Load Facts (Orders, OrderDetails)
      Parallel_Load_Facts = {
        Type = "Parallel"
        End  = true
        Branches = [
          {
            StartAt = "Glue_Load_Orders"
            States = {
              Glue_Load_Orders = {
                Type     = "Task"
                Resource = "arn:aws:states:::glue:startJobRun.sync"
                Parameters = { "JobName": var.glue_job_names["load_processed_orders"] }
                End      = true
              }
            }
          },
          {
            StartAt = "Glue_Load_OrderDetails"
            States = {
              Glue_Load_OrderDetails = {
                Type     = "Task"
                Resource = "arn:aws:states:::glue:startJobRun.sync"
                Parameters = { "JobName": var.glue_job_names["load_processed_orderdetails"] }
                End      = true
              }
            }
          }
        ]
      }
    }
  })
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
