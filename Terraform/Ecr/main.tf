resource "aws_ecr_repository" "daily_monitor_lambda_ecr_repo" {
  name = "daily_monitor_lambda_ecr_repo_${var.env}"

  image_scanning_configuration {
    scan_on_push = true
  }
}


resource "aws_ecr_repository" "end_workflow_lambda_ecr_repo" {
  name = "end_workflow_lambda_ecr_repo_${var.env}"

  image_scanning_configuration {
    scan_on_push = true
  }
}


resource "aws_ecr_repository" "files_to_process_lambda_ecr_repo" {
  name = "files_to_process_lambda_ecr_repo_${var.env}"

  image_scanning_configuration {
    scan_on_push = true
  }
}


resource "aws_ecr_repository" "start_workflow_lambda_ecr_repo" {
  name = "start_workflow_lambda_ecr_repo_${var.env}"

  image_scanning_configuration {
    scan_on_push = true
  }
}