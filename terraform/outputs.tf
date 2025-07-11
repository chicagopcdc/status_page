output "cloudfront_domain" {
  value = module.cloudfront.cloudfront_domain
}

output "acm_certificate_dns_validation" {
  description = "DNS records required for ACM certificate validation"
  value = module.acm_cert.acm_certificate_dns_validation
}

output "cert_dom_name" {
  value = module.acm_cert.certificate_domain_name
}



output "api_gateway_url" {
  value = aws_apigatewayv2_api.http_api.api_endpoint
}




