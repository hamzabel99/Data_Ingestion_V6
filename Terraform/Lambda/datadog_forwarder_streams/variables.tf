variable "datadog_forwarder_streams_ecr_repo_url" {
    description = "URL of the ECR repo of the datadog_forwarder_stream_lambda"
  
}

variable "env" {
}

variable "workflow_statut_table_stream_arn" {
  description = "ARN of the Dynamo DB workflow-statut"
  type        = string

}