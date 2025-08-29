variable "aws_sqs_queue_arn" {
  description = "ARN of the SQS queue"
  type        = string

}

variable "env" {
}

variable "aws_sqs_queue_name" {
  description = "Name of the SQS queue"
  type        = string

}

variable "workflow_statut_table_name" {
  description = "Name of the Dynamo DB workflow-statut"
  type        = string

}

variable "files_to_process_lambda_ecr_repo_url" {
  description = "URL of the ECR repo of the end_workflow_lambda"
  type        = string
}

