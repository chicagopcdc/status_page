env_name                        = "dev"
base_domain_url                 = "pedscommons.org"

default_tags                    =  {
									Environment	= "Dev"
									Project		= "status-page"
								}

lambda_function_source_dir		= "./status_lambda/dist/status_lambda/"
lambda_function_output_path		="../dist/status_lambda/lambda.zip"
lambda_file_name				= "../dist/status_lambda/lambda.zip"


manual_step                     = false