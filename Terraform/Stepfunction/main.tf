data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_sfn_state_machine" "sfn_state_machine" {
  name     = "csv-to-parquet-sfn-${var.env}"
  role_arn = aws_iam_role.csv_to_parquet_sfn_role.arn

  definition = jsonencode({
    "Comment" : "Workflow Glue avec suivi dans DynamoDB",
    "StartAt" : "RunGlueJob",
    "States" : {
      "RunGlueJob" : {
        "Next" : "TransformData",
        "Type" : "Task",
        "Resource" : "arn:aws:states:::glue:startJobRun.sync",
        "Parameters" : {
          "JobName" : var.ingestion_glue_job_name,
          "Arguments" : {
            "--input_event.$" : "States.JsonToString($)"
          }
        },
        "Retry" : [
          {
            "ErrorEquals" : [
              "States.ALL"
            ],
            "IntervalSeconds" : 0,
            "MaxAttempts" : 1,
            "BackoffRate" : 1
          }
        ]
      },
      "TransformData" : {
        "Type" : "Pass",
        "Next" : "EndWorkflow",
        "Parameters" : {
          "glue_output.$" : "$",
          "original_input.$" : "States.StringToJson($.Arguments['--input_event'])"
        },
        "OutputPath" : "$.original_input"
      },
      "EndWorkflow" : {
        "Type" : "Task",
        "Resource" : var.end_workflow_lambda_arn,
        "Parameters" : {
          "input_bucket.$" : "$.files_to_process[0].input_bucket",
          "s3_key.$" : "$.files_to_process[0].s3_key",
          "--input_event.$" : "$"
        },
        "End" : true
      }
    }
  })
}




resource "aws_iam_role" "csv_to_parquet_sfn_role" {
  name = "csv_to_parquet_sfn_role"
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


data "aws_iam_policy_document" "csv_to_parquet_sfn_policy" {
  statement {
    sid    = "GluePermissions"
    effect = "Allow"

    actions = [
      "glue:StartJobRun",
      "glue:GetJobRun",
      "glue:GetJobRuns",
      "glue:BatchStopJobRun"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "LambdaInvoke"
    effect = "Allow"

    actions = [
      "lambda:InvokeFunction"
    ]

    resources = [
      var.end_workflow_lambda_arn
    ]
  }

  statement {
    sid    = "XRayPermissions"
    effect = "Allow"

    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "csv_to_parquet_sfn_permissions" {
  name   = "csv_to_parquet_sfn_permissions"
  role   = aws_iam_role.csv_to_parquet_sfn_role.id
  policy = data.aws_iam_policy_document.csv_to_parquet_sfn_policy.json
}