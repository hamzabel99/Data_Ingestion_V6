variable "daily_monitor_topic_name" {
  description = "Name of the SNS topic"
  type        = string

}

variable "daily_monitor_topic_arn" {
  description = "SNS topic ARN"
  type        = string

}

variable "env" {
}

variable "workflow_statut_table_name" {
  description = "Name of the Dynamo DB workflow-statut"
  type        = string

}

variable "daily_monitor_lambda_ecr_repo_url" {
  description = "URL of the daily_monitor_lambda_ecr_repo"
  type        = string

}