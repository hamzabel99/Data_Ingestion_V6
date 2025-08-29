variable "env" {
}

variable "workflow_statut_table_name" {
  description = "Name of the Dynamo DB workflow-statut"
  type        = string

}

variable "workflow_metadata_table_name" {
  description = "Name of the Dynamo DB workflow-statut"
  type        = string

}

variable "csv_to_parquet_sfn_name" {
  description = "Name of the csv to parquet sfn"
  type        = string

}

variable "start_workflow_lambda_ecr_repo_url" {
  description = "URL of the ECR repo of the end_workflow_lambda"
  type        = string
}