output "lambda_bucket_name" {
  description = "Name of the S3 bucket to store Lambda code."
  value       = aws_s3_bucket.lambda_bucket.id
}

output "login_function_name" {
  description = "Name of the Login Lambda function."

  value = aws_lambda_function.login.function_name
}

output "base_url" {
  description = "The base URL for the API Gateway stage."

  value = aws_apigatewayv2_stage.spotify_auth.invoke_url
}