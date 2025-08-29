data "aws_caller_identity" "current" {}
data "aws_region" "current" {}


data "aws_iam_policy_document" "daily_monitor_lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}


resource "aws_iam_role" "daily_monitor_lambda_role" {
  name               = "daily_monitor_lambda_execution_role-${var.env}"
  assume_role_policy = data.aws_iam_policy_document.daily_monitor_lambda_assume_role.json
}


data "aws_iam_policy_document" "daily_monitor_lambda_policy" {

  statement {
    sid    = "SQSPoller"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ]
    resources = [
      "arn:aws:sqs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:Preprocess_Queue"
    ]
  }

  statement {
    sid    = "SNSSubscription"
    effect = "Allow"
    actions = [
      "sns:Publish"
    ]
    resources = [
      "arn:aws:sns:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:${var.daily_monitor_topic_name}"
    ]
  }


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
      "dynamodb:BatchWriteItem"
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


resource "aws_iam_role_policy" "daily_monitor_lambda_permissions" {
  name   = "lambda_permissions-${var.env}"
  role   = aws_iam_role.daily_monitor_lambda_role.id
  policy = data.aws_iam_policy_document.daily_monitor_lambda_policy.json
}


data "archive_file" "data_daily_monitor_lambda" {
  type        = "zip"
  source_file = "${path.module}/../Code/daily_monitor_lambda/daily_monitor_lambda.py"
  output_path = "${path.module}/../Code/daily_monitor_lambda/daily_monitor_lambda.zip"
}


resource "aws_lambda_function" "daily_monitor_lambda" {
  function_name = "daily_monitor_lambda_${var.env}"
  role          = aws_iam_role.daily_monitor_lambda_role.arn
  package_type  = "Image"
  image_uri     = "${var.daily_monitor_lambda_ecr_repo_url}:latest"

  architectures = ["arm64"]

  memory_size = 512
  timeout     = 30
  environment {
    variables = {
      WORKFLOW_STATUS_TABLE = var.workflow_statut_table_name
      SNS_TOPIC_ARN         = var.daily_monitor_topic_arn
    }
  }
}