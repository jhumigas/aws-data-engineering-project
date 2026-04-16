output "lambda_function_arn" {
  value = aws_lambda_function.data_generator.arn
}

output "function_name" {
  value = aws_lambda_function.data_generator.function_name
}

output "security_group_id" {
  value = aws_security_group.lambda.id
}
