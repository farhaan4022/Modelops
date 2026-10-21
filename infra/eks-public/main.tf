# MODELOPS_TERRAFORM_MANAGED_ALB_ROOT

locals {
  common_tags = {
    Project   = "ModelOps"
    ManagedBy = "Terraform"
    Name      = "ModelOps-Public-HTTPS"
  }
}

resource "aws_security_group" "alb" {
  name        = "modelops-public-https-sg"
  description = "Public HTTPS ALB for the ModelOps chat UI"
  vpc_id      = var.vpc_id

  tags = local.common_tags
}

resource "aws_vpc_security_group_ingress_rule" "alb" {
  for_each = toset(["80", "443"])

  security_group_id = aws_security_group.alb.id
  description       = "Public HTTP/HTTPS access"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = tonumber(each.value)
  to_port           = tonumber(each.value)
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb" {
  security_group_id = aws_security_group.alb.id
  description       = "Outbound traffic from the ALB"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_lb" "modelops" {
  name               = "modelops-public-https"
  internal           = false
  load_balancer_type = "application"
  ip_address_type    = "ipv4"

  security_groups = [aws_security_group.alb.id]
  subnets         = var.public_subnet_ids

  enable_deletion_protection = false
  drop_invalid_header_fields = true

  tags = local.common_tags
}

resource "aws_lb_target_group" "chat_ui" {
  name        = "modelops-chatui-30080"
  port        = 30080
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    protocol            = "HTTP"
    port                = "traffic-port"
    path                = "/health"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = local.common_tags
}

resource "aws_vpc_security_group_ingress_rule" "nodeport" {
  for_each = toset(var.node_security_group_ids)

  security_group_id            = each.value
  description                  = "Allow ModelOps ALB to reach chat UI NodePort"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 30080
  to_port                      = 30080
  ip_protocol                  = "tcp"
}

resource "aws_autoscaling_attachment" "chat_ui" {
  autoscaling_group_name = var.autoscaling_group_name
  lb_target_group_arn    = aws_lb_target_group.chat_ui.arn
}

resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.modelops.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.modelops.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.certificate_arn
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.chat_ui.arn
  }
}

resource "kubernetes_service_v1" "chat_ui_nodeport" {
  metadata {
    name      = "modelops-chat-ui-nodeport"
    namespace = "modelops"

    labels = {
      app       = "modelops-chat-ui"
      managedBy = "terraform"
    }
  }

  spec {
    type = "NodePort"

    selector = {
      app = "modelops-chat-ui"
    }

    port {
      name        = "http"
      port        = 80
      target_port = "http"
      node_port   = 30080
      protocol    = "TCP"
    }
  }
}
