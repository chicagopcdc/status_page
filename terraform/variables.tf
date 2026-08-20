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

variable "manual_step" {
  description   = "The name of the environment"
  type          = bool
  default       = false
}

# --- scheduled status check -------------------------------------------------
variable "notification_emails" {
  description = "Addresses subscribed to the status alert SNS topic. Each subscription must be confirmed from the email AWS sends before alerts are delivered."
  type        = list(string)
  default     = ["pcdc_help@lists.uchicago.edu"]
}

variable "status_check_schedule" {
  description = "EventBridge schedule expression controlling how often the status check runs."
  type        = string
  default     = "rate(15 minutes)"
}

variable "status_state_key" {
  description = "Key in the state bucket holding the previous run's result, used to alert only on change."
  type        = string
  default     = "status/last_state.json"
}

variable "status_request_timeout" {
  description = "Per-endpoint HTTP timeout in seconds. Matches the timeout the React status page uses."
  type        = string
  default     = "3"
}