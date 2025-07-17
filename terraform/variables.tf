variable "aws_region" {
  description = "The region in AWS"
  type        = string
  default = "us-east-2"
}

variable "env_name" {
  description = "The name of the environment"
  type        = string
  default = "dev"
}

variable "app_name" {
  description   = "The name of the environment"
  type          = string
  default       = "d4cg-status"
}

variable "s3_force_delete" {
  description   = "The name of the environment"
  type          = bool
  default       = true
}

variable "base_domain_url" {
  description = "The base domain for the DNS for this application"
  type        = string
}

variable "default_tags" {
  description = "Tags to apply to the resources"
  type        = map(string)
  default     = {}
}

variable "lambda_function_source_dir" {
  type = string
  default = "string used for the s3 bucket access role"
}

variable "lambda_function_output_path" {
  type = string
  default = "string used for the s3 bucket access role"
}

variable "lambda_file_name" {
  type = string
  default = "string used for the s3 bucket access role"
}