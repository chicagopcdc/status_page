locals {  
  # TF state
  state_bucket_name           = "${var.app_name}-${var.env_name}-state-bucket"
  access_s3_state_policy      = "${var.app_name}-${var.env_name}-state-bucket-policy"
  dynamodb_table_name         = "${var.app_name}-${var.env_name}-dynamodb-table-terraform-state"

  # S3 variables
  bucket_name                 = "${var.app_name}-${var.env_name}-bucket"

  # ACM
  domain_url                  = "${var.app_name}-${var.env_name}.${var.base_domain_url}"
}



module "s3_backend" {
  source                      = "git::ssh://git@github.com/chicagopcdc/terraform_modules.git//aws/terraform_s3_state_storage_resources?ref=dev"

  s3_bucket_name              = local.state_bucket_name
  dynamodb_table_name         = local.dynamodb_table_name
  policy_name                 = local.access_s3_state_policy

  tags = var.default_tags
}

module "s3_website" {
  source                      = "git::ssh://git@github.com/chicagopcdc/terraform_modules.git//aws/s3?ref=dev"
  
  bucket_name                 = "${local.bucket_name}"
  force_delete                = var.s3_force_delete
  enable_lifecycle            = false
  versioning                  = false
  enable_website_hosting      = true
  encryption                  = false
}

resource "aws_s3_bucket_policy" "website_policy" {
  bucket = module.s3_website.bucket_id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicReadGetObject",
        Effect    = "Allow",
        Principal = "*",
        Action    = ["s3:GetObject"],
        Resource  = ["${module.s3_website.bucket_arn}/*"]
      }
    ]
  })
}

module "acm_cert" {
  source                    = "git::ssh://git@github.com/chicagopcdc/terraform_modules.git//aws/acm?ref=dev"
  
  domain_url                = "${local.domain_url}"
  tags = var.default_tags
}







# CloudFront
resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "OAI for React S3 site"
}

resource "aws_cloudfront_distribution" "react_cf" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  aliases = ["app.yourdomain.com"]

  origin {
    domain_name = aws_s3_bucket.react_site.bucket_regional_domain_name
    origin_id   = "s3-react-origin"
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-react-origin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  price_class = "PriceClass_100"

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

# Lambda + API Gateway HTTP API backend
resource "aws_lambda_function" "backend" {
  filename         = "lambda_function_payload.zip"
  function_name    = "react-backend"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = "python3.12"
  source_code_hash = filebase64sha256("lambda_function_payload.zip")
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_apigatewayv2_api" "http_api" {
  name          = "react-backend-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.backend.invoke_arn
}

resource "aws_apigatewayv2_route" "default_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backend.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}