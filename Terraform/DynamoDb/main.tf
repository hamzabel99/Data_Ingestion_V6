resource "aws_dynamodb_table" "workflow_metadata_table" {
  name         = "workflow_metadata-${var.env}"
  hash_key     = "s3_prefix"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "s3_prefix"
    type = "S"
  }
}

resource "aws_dynamodb_table" "workflow_statut_table" {
  name         = "workflow_statut-${var.env}"
  hash_key     = "s3_prefix"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "s3_prefix"
    type = "S"
  }
}
