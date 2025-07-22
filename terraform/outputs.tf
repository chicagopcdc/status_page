output "acm_certificate_dns_validation" {
  description = "DNS records required for ACM certificate validation"
  value = module.acm_cert.acm_certificate_dns_validation
}

output "cert_dom_name" {
  value = module.acm_cert.certificate_domain_name
}

output "api_gateway_url" {
  value = module.api_gateway.http_api_endpoint
}

output "s3_bucket_name" {
  value = module.s3_website.bucket_name
}

output "cloudfront_domain" {
  value = length(module.cloudfront) > 0 ? module.cloudfront[0].cloudfront_domain : null
}

output "cloudfront_distribution_id" {
  value = length(module.cloudfront) > 0 ? module.cloudfront[0].cloudfront_distribution_id : null
}
