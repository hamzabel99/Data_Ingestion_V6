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
    sid    = "DynamoDBStreamAccess"
    effect = "Allow"
    actions = [
    "dynamodb:GetRecords",
    "dynamodb:GetShardIterator",
    "dynamodb:DescribeStream",
    "dynamodb:ListStreams"
    ]
    resources = [
      "arn:aws:dynamodb:eu-west-3:195044943814:table/workflow_statut-dev/stream/*"
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
  
  statement {
    sid    = "SSMParameterStoreAccess"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/datadog/*"
    ]
  }
}


resource "aws_iam_role_policy" "datadog_forwarder_streams_permissions" {
  name   = "lambda_permissions-${var.env}"
  role   = aws_iam_role.datadog_forwarder_streams_role.id
  policy = data.aws_iam_policy_document.datadog_forwarder_streams_policy.json
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

resource "aws_lambda_event_source_mapping" "dynamodb_trigger_datadog_forwarder" {
  event_source_arn  = var.workflow_statut_table_stream_arn
  function_name     = aws_lambda_function.datadog_forwarder_streams.arn
  starting_position = "LATEST"
  enabled           = true
}