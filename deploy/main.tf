provider "aws" {
  region = "eu-west-2"
}

resource "random_pet" "lambda_bucket_name" {
  prefix = "spotify-auth"
}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket = random_pet.lambda_bucket_name.id
}

data "archive_file" "spotify_auth" {
  type = "zip"

  source_dir  = "${path.module}/../dist"
  output_path = "${path.module}/build/spotify-auth.zip"
}

resource "aws_s3_object" "spotify_auth" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "spotify-auth.zip"
  source = data.archive_file.spotify_auth.output_path

  etag = filemd5(data.archive_file.spotify_auth.output_path)
}

resource "aws_lambda_function" "login" {
  function_name = "Login"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.spotify_auth.key

  runtime = "nodejs18.x"
  handler = "login.handler"

  source_code_hash = data.archive_file.spotify_auth.output_base64sha256

  role = aws_iam_role.lambda_exec.arn
}

resource "aws_cloudwatch_log_group" "login" {
  name = "/aws/lambda/${aws_lambda_function.login.function_name}"

  retention_in_days = 30
}

resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_apigatewayv2_api" "spotify_auth" {
  name          = "serverless_login_gw"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "spotify_auth" {
  api_id = aws_apigatewayv2_api.spotify_auth.id

  name        = "spotify_auth"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
}

resource "aws_apigatewayv2_integration" "login" {
  api_id = aws_apigatewayv2_api.spotify_auth.id

  integration_uri    = aws_lambda_function.login.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "login" {
  api_id = aws_apigatewayv2_api.spotify_auth.id

  route_key = "GET /login"
  target    = "integrations/${aws_apigatewayv2_integration.login.id}"
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.spotify_auth.name}"

  retention_in_days = 30
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.login.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.spotify_auth.execution_arn}/*/*"
}