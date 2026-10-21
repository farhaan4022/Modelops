# MODELOPS_TERRAFORM_MANAGED_FASTAPI_ROUTING
# Preserve the existing ALB, HTTPS certificate and frontend.
# API paths are routed to the existing CPU-only FastAPI service.

resource "aws_lb_target_group" "modelops_llm_api" {
  name                 = "modelops-api-30081"
  port                 = 30081
  protocol             = "HTTP"
  target_type          = "instance"
  vpc_id               = data.aws_eks_cluster.cluster.vpc_config[0].vpc_id
  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name      = "ModelOps-FastAPI"
    Project   = "ModelOps"
    ManagedBy = "Terraform"
  }
}

resource "aws_vpc_security_group_ingress_rule" "modelops_llm_api_nodeport" {
  security_group_id            = aws_vpc_security_group_ingress_rule.nodeport["sg-0f9bfd41c4142de13"].security_group_id
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = 30081
  to_port                      = 30081
  description                  = "Allow existing ALB to reach FastAPI NodePort"
}

resource "aws_autoscaling_attachment" "modelops_llm_api" {
  autoscaling_group_name = aws_autoscaling_attachment.chat_ui.autoscaling_group_name
  lb_target_group_arn    = aws_lb_target_group.modelops_llm_api.arn
}

resource "aws_lb_listener_rule" "modelops_llm_api" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.modelops_llm_api.arn
  }

  condition {
    path_pattern {
      values = ["/v1/*"]
    }
  }

  tags = {
    Name      = "ModelOps-FastAPI-Path-Routing"
    Project   = "ModelOps"
    ManagedBy = "Terraform"
  }
}
