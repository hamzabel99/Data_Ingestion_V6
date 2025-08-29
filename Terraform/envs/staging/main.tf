provider "aws" {
  region = "eu-west-3"
}

module "Dynamodb" {
  source = "../../DynamoDb"
  env    = var.env
}

module "S3Bucket" {
  source                  = "../../S3Bucket"
  preprocess_bucket_name  = "preworkflow-ingestion-bucket-${var.env}"
  postprocess_bucket_name = "postworkflow-ingestion-bucket-${var.env}"
  artifacts_bucket_name   = "gluejobs-ingestion-bucket-${var.env}"
  env                     = var.env
}

module "Sqs" {
  source                = "../../Sqs"
  preprocess_bucket_arn = module.S3Bucket.preprocess_bucket_arn
  env                   = var.env

}

module "S3Notifications" {
  source                 = "../../S3Notifications"
  preprocess_bucket_name = module.S3Bucket.preprocess_bucket_name
  preprocess_queue_arn   = module.Sqs.preprocess_queue_arn
  sqs_queue_policy_id    = module.Sqs.queue_policy_id
  env                    = var.env

}

module "start-workflow-lambda" {
  source = "../../Lambda/start-workflow-lambda"
  env    = var.env

}

module "end-workflow-lambda" {
  source = "../../Lambda/end-workflow-lambda"
  env    = var.env

}

module "files_to_process_lambda" {
  source             = "../../Lambda/files_to_process_lambda"
  aws_sqs_queue_arn  = module.Sqs.preprocess_queue_arn
  env                = var.env
  aws_sqs_queue_name = module.Sqs.preprocess_queue_name



}

module "glue-job" {
  source                = "../../Glue/ingestion-glue-job"
  artifacts_bucket_name = module.S3Bucket.artifacts_bucket_name
  env                   = var.env

}

module "stepfunctions" {
  source                  = "../../Stepfunction"
  end_workflow_lambda_arn = module.end-workflow-lambda.end_workflow_lambda_arn
  ingestion_glue_job_name = module.glue-job.ingestion_glue_job_name
  env                     = var.env

}

module "sns" {
  source                  = "../../Sns"
  email_target_monitoring = "hamza.belabbes@ens2m.org"
  env                     = var.env

}

module "daily_monitor_lambda" {
  source                   = "../../Lambda/daily_monitor_lambda"
  daily_monitor_topic_name = module.sns.daily_monitor_topic_name
  daily_monitor_topic_arn  = module.sns.daily_monitor_topic_arn
  env                      = var.env

}

module "eventbridge" {
  source                    = "../../Eventbridge"
  daily_monitor_lambda_arn  = module.daily_monitor_lambda.daily_monitor_lambda_arn
  start_workflow_lambda_arn = module.start-workflow-lambda.start_workflow_lambda_arn
  env                       = var.env
}