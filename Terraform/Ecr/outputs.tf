output "daily_monitor_lambda_ecr_repo_url" {
  value = aws_ecr_repository.daily_monitor_lambda_ecr_repo.repository_url
}

output "end_workflow_lambda_ecr_repo_url" {
  value = aws_ecr_repository.end_workflow_lambda_ecr_repo.repository_url
}

output "files_to_process_lambda_ecr_repo" {
  value = aws_ecr_repository.files_to_process_lambda_ecr_repo.repository_url
}

output "start_workflow_lambda_ecr_repo" {
  value = aws_ecr_repository.start_workflow_lambda_ecr_repo.repository_url
}
