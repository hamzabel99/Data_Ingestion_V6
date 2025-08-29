output "csv_to_parquet_sfn_name" {
  value = aws_sfn_state_machine.sfn_state_machine.name

}