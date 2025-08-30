output "workflow_metadata_table_name" {
  value = aws_dynamodb_table.workflow_metadata_table.name
}

output "workflow_statut_table_name" {
  value = aws_dynamodb_table.workflow_statut_table.name
}

output "workflow_statut_table_stream_arn" {
  value = aws_dynamodb_table.workflow_statut_table.stream_arn
}