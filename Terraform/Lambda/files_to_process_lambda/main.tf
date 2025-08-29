data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# IAM role for All Lambda functions
data "aws_iam_policy_document" "files_to_process_lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}


resource "aws_iam_role" "files_to_process_lambda_role" {
  name               = "files_to_process_lambda_execution_role-${var.env}"
  assume_role_policy = data.aws_iam_policy_document.files_to_process_lambda_assume_role.json
}


data "aws_iam_policy_document" "files_to_process_lambda_policy" {

  statement {
    sid    = "SQSPoller"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ]
    resources = [
      "arn:aws:sqs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:${var.aws_sqs_queue_name}"
    ]
  }

  statement {
      
        sid    = "DynamoDBStreamAccess"
        effect = "Allow"
        actions = [
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
          "dynamodb:DescribeStream",
          "dynamodb:ListStreams"
        ]
        resources = ["arn:aws:dynamodb:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:table/workflow_statut-dev/stream/*"]
      
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


resource "aws_iam_role_policy" "files_to_process_lambda_permissions" {
  name   = "lambda_permissions-${var.env}"
  role   = aws_iam_role.files_to_process_lambda_role.id
  policy = data.aws_iam_policy_document.files_to_process_lambda_policy.json
}


resource "aws_lambda_function" "files_to_process_lambda" {
  function_name = "files_to_process_lambda_${var.env}"
  role          = aws_iam_role.files_to_process_lambda_role.arn
  package_type  = "Image"
  image_uri     = "${var.files_to_process_lambda_ecr_repo_url}:latest"

  architectures = ["arm64"]

  memory_size = 512
  timeout     = 30
  environment {
    variables = {
      WORKFLOW_STATUS_TABLE = var.workflow_statut_table_name
    }
  }
}

resource "aws_lambda_event_source_mapping" "sqs_trigger_lambda" {
  event_source_arn = var.aws_sqs_queue_arn
  function_name    = aws_lambda_function.files_to_process_lambda.arn
  batch_size       = 10
}