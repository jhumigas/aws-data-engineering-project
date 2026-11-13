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
          "glue:GetJobRun",
          "glue:GetJobRuns",
          "glue:BatchStopJobRun",
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
# Coordinates the full medallion flow:
#   Crawl bronze -> Transform bronze to silver -> Load + merge dimensions -> Load + merge facts
# Every Redshift merge is polled with describeStatement, so a failed or
# aborted procedure fails the execution instead of being fire-and-forget.
locals {
  crawler_poll_seconds = 30
  merge_poll_seconds   = 10

  transform_jobs = {
    Customer     = "raw_customer_etl_job"
    Product      = "raw_product_etl_job"
    Orders       = "raw_orders_etl_job"
    OrderDetails = "raw_orderdetails_etl_job"
  }

  # Each entry becomes one parallel branch: Glue load into staging, then a stored procedure merge.
  load_and_merge = {
    dimensions = {
      Customer = { job = "load_processed_customers", procedure = "sales.sp_merge_dim_customer" }
      Product  = { job = "load_processed_products", procedure = "sales.sp_merge_dim_product" }
    }
    facts = {
      Orders       = { job = "load_processed_orders", procedure = "sales.sp_merge_fact_orders" }
      OrderDetails = { job = "load_processed_orderdetails", procedure = "sales.sp_merge_fact_order_details" }
    }
  }

  glue_retry = [
    {
      ErrorEquals     = ["Glue.ConcurrentRunsExceededException", "Glue.ThrottlingException"]
      IntervalSeconds = 30
      MaxAttempts     = 3
      BackoffRate     = 2
    }
  ]

  load_and_merge_branches = {
    for stage, tables in local.load_and_merge : stage => [
      for name, spec in tables : {
        StartAt = "Load_${name}"
        States = {
          "Load_${name}" = {
            Type       = "Task"
            Resource   = "arn:aws:states:::glue:startJobRun.sync"
            Parameters = { JobName = var.glue_job_names[spec.job] }
            ResultPath = null
            Retry      = local.glue_retry
            Next       = "Merge_${name}"
          }
          "Merge_${name}" = {
            Type     = "Task"
            Resource = "arn:aws:states:::aws-sdk:redshiftdata:executeStatement"
            Parameters = {
              ClusterIdentifier = var.redshift_cluster_identifier
              Database          = var.redshift_database
              DbUser            = var.redshift_db_user
              Sql               = "CALL ${spec.procedure}();"
            }
            ResultSelector = { "Id.$" = "$.Id" }
            ResultPath     = "$.merge"
            Next           = "Wait_Merge_${name}"
          }
          "Wait_Merge_${name}" = {
            Type    = "Wait"
            Seconds = local.merge_poll_seconds
            Next    = "Check_Merge_${name}"
          }
          "Check_Merge_${name}" = {
            Type       = "Task"
            Resource   = "arn:aws:states:::aws-sdk:redshiftdata:describeStatement"
            Parameters = { "Id.$" = "$.merge.Id" }
            ResultPath = "$.merge"
            Next       = "Is_Merge_${name}_Done"
          }
          "Is_Merge_${name}_Done" = {
            Type = "Choice"
            Choices = [
              { Variable = "$.merge.Status", StringEquals = "FINISHED", Next = "Merge_${name}_Succeeded" },
              { Variable = "$.merge.Status", StringEquals = "FAILED", Next = "Merge_${name}_Failed" },
              { Variable = "$.merge.Status", StringEquals = "ABORTED", Next = "Merge_${name}_Aborted" },
            ]
            Default = "Wait_Merge_${name}"
          }
          "Merge_${name}_Succeeded" = {
            Type = "Succeed"
          }
          "Merge_${name}_Failed" = {
            Type      = "Fail"
            Error     = "RedshiftMergeFailed"
            CausePath = "States.Format('${spec.procedure} failed: {}', $.merge.Error)"
          }
          "Merge_${name}_Aborted" = {
            Type  = "Fail"
            Error = "RedshiftMergeAborted"
            Cause = "${spec.procedure} was aborted before it finished"
          }
        }
      }
    ]
  }
}

resource "aws_sfn_state_machine" "main" {
  name     = "${var.project_name}-${var.environment}-state-machine"
  role_arn = aws_iam_role.sfn_role.arn

  definition = jsonencode({
    Comment        = "Crawl bronze, transform to silver, then load and merge dimensions and facts in Redshift"
    StartAt        = "Init"
    TimeoutSeconds = var.execution_timeout_seconds
    States = {
      # 1. Seed the crawler list for the Map state
      Init = {
        Type   = "Pass"
        Result = { crawlers = var.glue_crawler_names }
        Next   = "Run_Crawlers"
      }

      # 2. Refresh the bronze Data Catalog tables (one crawler per table)
      Run_Crawlers = {
        Type           = "Map"
        ItemsPath      = "$.crawlers"
        ItemSelector   = { "name.$" = "$$.Map.Item.Value" }
        MaxConcurrency = 0
        ResultPath     = null
        Next           = "Parallel_Transform"
        ItemProcessor = {
          ProcessorConfig = { Mode = "INLINE" }
          StartAt         = "Start_Crawler"
          States = {
            Start_Crawler = {
              Type       = "Task"
              Resource   = "arn:aws:states:::aws-sdk:glue:startCrawler"
              Parameters = { "Name.$" = "$.name" }
              ResultPath = null
              # A crawler that is already running (e.g. started by hand) is simply awaited.
              Catch = [
                { ErrorEquals = ["Glue.CrawlerRunningException"], ResultPath = null, Next = "Wait_Crawler" }
              ]
              Next = "Wait_Crawler"
            }
            Wait_Crawler = {
              Type    = "Wait"
              Seconds = local.crawler_poll_seconds
              Next    = "Check_Crawler"
            }
            Check_Crawler = {
              Type       = "Task"
              Resource   = "arn:aws:states:::aws-sdk:glue:getCrawler"
              Parameters = { "Name.$" = "$.name" }
              # Keep the whole Crawler object: LastCrawl is absent until a crawler has finished once.
              ResultSelector = { "Crawler.$" = "$.Crawler" }
              ResultPath     = "$.crawler"
              Next           = "Is_Crawler_Done"
            }
            Is_Crawler_Done = {
              Type = "Choice"
              Choices = [
                {
                  Not  = { Variable = "$.crawler.Crawler.State", StringEquals = "READY" }
                  Next = "Wait_Crawler"
                },
                {
                  And = [
                    { Variable = "$.crawler.Crawler.LastCrawl.Status", IsPresent = true },
                    { Variable = "$.crawler.Crawler.LastCrawl.Status", StringEquals = "SUCCEEDED" },
                  ]
                  Next = "Crawler_Succeeded"
                },
              ]
              Default = "Crawler_Failed"
            }
            Crawler_Succeeded = {
              Type = "Succeed"
            }
            Crawler_Failed = {
              Type      = "Fail"
              Error     = "GlueCrawlerFailed"
              CausePath = "States.Format('Crawler {} did not finish with status SUCCEEDED', $.name)"
            }
          }
        }
      }

      # 3. Transform bronze CSV into silver Parquet
      Parallel_Transform = {
        Type       = "Parallel"
        ResultPath = null
        Next       = "Parallel_Load_Dimensions"
        Branches = [
          for name, job in local.transform_jobs : {
            StartAt = "Transform_${name}"
            States = {
              "Transform_${name}" = {
                Type       = "Task"
                Resource   = "arn:aws:states:::glue:startJobRun.sync"
                Parameters = { JobName = var.glue_job_names[job] }
                ResultPath = null
                Retry      = local.glue_retry
                End        = true
              }
            }
          }
        ]
      }

      # 4. Load dimensions into staging and run the SCD Type 2 merges
      Parallel_Load_Dimensions = {
        Type       = "Parallel"
        ResultPath = null
        Next       = "Parallel_Load_Facts"
        Branches   = local.load_and_merge_branches.dimensions
      }

      # 5. Load facts into staging and upsert them into the fact tables
      Parallel_Load_Facts = {
        Type       = "Parallel"
        ResultPath = null
        End        = true
        Branches   = local.load_and_merge_branches.facts
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
        Effect   = "Allow"
        Action   = ["states:StartExecution"]
        Resource = [aws_sfn_state_machine.main.arn]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eventbridge_sfn_attach" {
  role       = aws_iam_role.eventbridge_sfn_role.name
  policy_arn = aws_iam_policy.eventbridge_sfn_policy.arn
}
