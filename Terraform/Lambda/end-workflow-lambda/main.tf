data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "end_workflow_lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "end_workflow_lambda_role" {
  name               = "lambda_execution_role-${var.env}"
  assume_role_policy = data.aws_iam_policy_document.end_workflow_lambda_assume_role.json
}

data "aws_iam_policy_document" "end_workflow_lambda_policy" {

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

resource "aws_iam_role_policy" "end_workflow_lambda_permissions" {
  name   = "lambda_permissions-${var.env}"
  role   = aws_iam_role.end_workflow_lambda_role.id
  policy = data.aws_iam_policy_document.end_workflow_lambda_policy.json
}


resource "aws_lambda_function" "end_workflow_lambda" {
  function_name = "end_workflow_lambda_${var.env}"
  role          = aws_iam_role.end_workflow_lambda_role.arn
  package_type  = "Image"
  image_uri     = "${var.end_workflow_lambda_ecr_repo_url}:latest"

  architectures = ["arm64"]

  memory_size = 512
  timeout     = 30
  environment {
    variables = {
      WORKFLOW_STATUS_TABLE   = var.workflow_statut_table_name
      WORKFLOW_METADATA_TABLE = var.workflow_metadata_table_name
    }
  }
}