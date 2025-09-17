locals {  
  # S3 variables
  bucket_name                 = "${var.app_name}-${var.env_name}-bucket"

  # ACM
  domain_url                  = "${var.app_name}${var.env_name != "prod" ? "-${var.env_name}" : ""}.${var.base_domain_url}"

  lambda_function_name        = "${var.app_name}-${var.env_name}-backend-lambda"
}


data "aws_caller_identity" "current" {}

module "s3_website" {
  source                      = "git::ssh://git@github.com/chicagopcdc/terraform_modules.git//aws/s3?ref=0.6.0"
  
  bucket_name                 = "${local.bucket_name}"
  force_delete                = var.s3_force_delete
  enable_lifecycle            = false
  versioning                  = "Disabled"
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
  source                    = "git::ssh://git@github.com/chicagopcdc/terraform_modules.git//aws/acm?ref=0.6.0"
  
  domain_url                = "${local.domain_url}"
  tags = var.default_tags

  providers = {
    aws = aws.use1
  }
}

module "cloudfront" {
  source                          = "git::ssh://git@github.com/chicagopcdc/terraform_modules.git//aws/cloudfront?ref=0.6.0"
  
  domain_alias                    = "${local.domain_url}"
  bucket_regional_domain_name     = module.s3_website.bucket_regional_domain_name
  cert_arn                        = module.acm_cert.acm_cert_arn

  count                           = var.manual_step ? 1 : 0
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

module "lambda_backend" {
  source                          = "git::ssh://git@github.com/chicagopcdc/terraform_modules.git//aws/lambda_local_file?ref=0.6.0"
  
  lambda_function_name            = local.lambda_function_name
  lambda_function_source_dir      = var.lambda_function_source_dir
  lambda_function_output_path     = var.lambda_function_output_path
  lambda_file_name                = var.lambda_file_name
  lambda_role_arn                 = aws_iam_role.lambda_exec.arn
  handler                         = "status_lambda.handler"
  timeout                         = "600"
  memory_size                     = "128"
  runtime                         = "python3.10"
  lambda_environment_variables    = {
                                      VAR_1       = "test"
                                    }
  tags                            =  var.default_tags
}

module "api_gateway" {
  source                          = "git::ssh://git@github.com/chicagopcdc/terraform_modules.git//aws/api_gateway?ref=0.6.0"
  
  app_name                        = "react-backend"
  endpoint_path                   = "$default"
  stage                           = ""
  http_method                     = ""
  http_method_integration         = ""
  lambda_invoke_arn               = module.lambda_backend.lambda_invoke_arn
  lambda_name                     = module.lambda_backend.lambda_name
  allowed_source_ips              = ["*"]
  api_type                        = "HTTP"
}


resource "aws_iam_user" "github_actions" {
  name = "github-actions-deployer"
  
  count                           = var.manual_step ? 1 : 0
}
resource "aws_iam_access_key" "github_actions_key" {
  user = aws_iam_user.github_actions[0].name

  count                           = var.manual_step ? 1 : 0
}
resource "aws_iam_policy" "github_actions_policy" {
  name        = "github-actions-deploy-policy"
  description = "Permissions for GitHub Actions to deploy to S3 and invalidate CloudFront"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ],
        Resource = [
          "${module.s3_website.bucket_arn}",
          "${module.s3_website.bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = "cloudfront:CreateInvalidation",
        Resource = "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/${module.cloudfront[0].cloudfront_distribution_id}"
      }
    ]
  })

  count                           = var.manual_step ? 1 : 0
}
resource "aws_iam_user_policy_attachment" "github_actions_attach" {
  user       = aws_iam_user.github_actions[0].name
  policy_arn = aws_iam_policy.github_actions_policy[0].arn

  count                           = var.manual_step ? 1 : 0
}




