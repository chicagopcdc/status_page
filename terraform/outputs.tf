output "cloudfront_domain" {
  value = aws_cloudfront_distribution.react_cf.domain_name
}

output "api_gateway_url" {
  value = aws_apigatewayv2_api.http_api.api_endpoint
}