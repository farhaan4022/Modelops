variable "public_domain" {
  description = "Externally managed public domain for ModelOps HTTPS"
  type        = string
  default     = "farhaanbr.changeip.co"
}

resource "aws_acm_certificate" "modelops_public" {
  domain_name       = var.public_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name      = "modelops-public-https"
    Project   = "ModelOps"
    ManagedBy = "Terraform"
  }
}

output "public_https_certificate_arn" {
  description = "ACM certificate ARN for the ModelOps public endpoint"
  value       = aws_acm_certificate.modelops_public.arn
}

output "public_https_acm_validation_records" {
  description = "DNS records required to validate the public ACM certificate"
  value = [
    for option in aws_acm_certificate.modelops_public.domain_validation_options : {
      name  = option.resource_record_name
      type  = option.resource_record_type
      value = option.resource_record_value
    }
  ]
}
