locals {  
  # TF state
  state_bucket_name           = "${var.app_name}-${var.env_name}-state-bucket"
  access_s3_state_policy      = "${var.app_name}-${var.env_name}-state-bucket-policy"
  dynamodb_table_name         = "${var.app_name}-${var.env_name}-dynamodb-table-terraform-state"

  # S3 variables
  bucket_name                 = "${var.app_name}-${var.env_name}-bucket"

  # ACM
  domain_url                  = "${var.app_name}${var.env_name != "prod" ? "-${var.env_name}" : ""}.${var.base_domain_url}"

  lambda_function_name        = "${var.app_name}-${var.env_name}-backend-lambda"
}



module "s3_backend" {
  source                      = "git::ssh://git@github.com/chicagopcdc/terraform_modules.git//aws/terraform_s3_state_storage_resources?ref=0.6.0"

  s3_bucket_name              = local.state_bucket_name
  dynamodb_table_name         = local.dynamodb_table_name
  policy_name                 = local.access_s3_state_policy

  tags = var.default_tags
}

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





