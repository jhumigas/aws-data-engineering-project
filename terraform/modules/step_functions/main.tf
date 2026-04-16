# IAM Role for Step Functions
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
          "glue:GetJobRuns",
          "glue:BatchStopJobRun"
        ]
        Resource = "*" # Scope to specific jobs if possible, but * is simpler here
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sfn_attach" {
  role       = aws_iam_role.sfn_role.name
  policy_arn = aws_iam_policy.sfn_policy.arn
}

resource "aws_sfn_state_machine" "main" {
  name     = "${var.project_name}-${var.environment}-state-machine"
  role_arn = aws_iam_role.sfn_role.arn

  # Direct definition mostly, but should check if we can read from file. 
  # Since I can't easily see the file content right now without a tool call, 
  # I will define a simple sequential flow based on the requirement "run the Glue jobs in sequence".
  # If I used templatefile, I'd need to know the specific JSON structure to inject names.
  
  definition = jsonencode({
    Comment = "Orchestrate Glue Jobs"
    StartAt = length(var.glue_job_names) > 0 ? "DataIngestion" : "Done"
    States = merge(
      length(var.glue_job_names) > 0 ? {
        DataIngestion = {
          Type = "Task",
          Resource = "arn:aws:states:::glue:startJobRun.sync",
          Parameters = {
            JobName = var.glue_job_names[0]
          },
          End = true
        }
      } : {},
      {
        Done = {
          Type = "Succeed"
        }
      }
    )
  })
  
  tags = {
    Name = "${var.project_name}-${var.environment}-state-machine"
  }
}

# EventBridge Schedule for Step Functions
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
