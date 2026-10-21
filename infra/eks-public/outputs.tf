output "public_domain" {
  value = var.domain
}

output "load_balancer_dns_name" {
  value = aws_lb.modelops.dns_name
}

output "load_balancer_arn" {
  value = aws_lb.modelops.arn
}

output "target_group_arn" {
  value = aws_lb_target_group.chat_ui.arn
}

output "certificate_arn" {
  value = var.certificate_arn
}
