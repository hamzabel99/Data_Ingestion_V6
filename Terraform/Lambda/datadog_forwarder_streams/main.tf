data "aws_caller_identity" "current" {}
data "aws_region" "current" {}


data "aws_iam_policy_document" "datadog_forwarder_streams_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}


resource "aws_iam_role" "datadog_forwarder_streams_role" {
  name               = "datadog_forwarder_streams_execution_role-${var.env}"
  assume_role_policy = data.aws_iam_policy_document.datadog_forwarder_streams_assume_role.json
}


data "aws_iam_policy_document" "datadog_forwarder_streams_policy" {



  statement {
    sid    = "DynamoReadWorkflowMetadata"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:BatchGetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:BatchWriteItem",
      "dynamodb:GetRecords",
      "dynamodb:GetShardIterator",
      "dynamodb:DescribeStream",
      "dynamodb:ListStreams"
    ]
    resources = [
      "arn:aws:dynamodb:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:table/${var.workflow_statut_table_name}"
    ]
  }

  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*"
    ]
  }
}


resource "aws_iam_role_policy" "datadog_forwarder_streams_permissions" {
  name   = "lambda_permissions-${var.env}"
  role   = aws_iam_role.datadog_forwarder_streams_role.id
  policy = data.aws_iam_policy_document.datadog_forwarder_streams_policy.json
}


data "archive_file" "data_datadog_forwarder_streams" {
  type        = "zip"
  source_file = "${path.module}/../Code/datadog_forwarder_streams/datadog_forwarder_streams.py"
  output_path = "${path.module}/../Code/datadog_forwarder_streams/datadog_forwarder_streams.zip"
}


resource "aws_lambda_function" "datadog_forwarder_streams" {
  function_name = "datadog_forwarder_streams_${var.env}"
  role          = aws_iam_role.datadog_forwarder_streams_role.arn
  package_type  = "Image"
  image_uri     = "${var.datadog_forwarder_streams_ecr_repo_url}:latest"
 
  architectures = ["arm64"]

  memory_size = 512
  timeout     = 30
}