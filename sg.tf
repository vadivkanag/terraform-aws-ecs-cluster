resource "aws_security_group" "cluster_instance" {
  name        = "${var.cluster_name}-cluster"
  description = "Allow access from the load balancer"
  vpc_id      = aws_vpc.vpc.id
}

resource "aws_security_group_rule" "ecs_cluster_ingress_all_ports" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.internal_lb.id
  security_group_id        = aws_security_group.cluster_instance.id
}

resource "aws_security_group_rule" "ecs_cluster_egress_all_ports" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.cluster_instance.id
}

resource "aws_security_group" "api_instance" {
  name        = "${var.cluster_name}-api"
  description = "Allow Access from internet facing ELB"
  vpc_id      = aws_vpc.vpc.id
}

output "api_sg_id" {
  value = aws_security_group.api_instance.id
}

resource "aws_security_group_rule" "api_instance_ingress_80" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.external_lb.id
  security_group_id        = aws_security_group.api_instance.id
}

resource "aws_security_group_rule" "api_instance_ingress_443" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr_block]
  security_group_id = aws_security_group.api_instance.id
}

resource "aws_security_group_rule" "api_instance_ingress_lb" {
  type              = "ingress"
  from_port         = 8000
  to_port           = 8000
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr_block]
  security_group_id = aws_security_group.api_instance.id
}

resource "aws_security_group_rule" "api_instance_egress_443" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.api_instance.id
}

resource "aws_security_group_rule" "api_instance_egress_80" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.api_instance.id
}

resource "aws_security_group" "external_lb" {
  name        = "${var.cluster_name}-external-lb"
  description = "For External ELB to receive traffic"
  vpc_id      = aws_vpc.vpc.id
}

resource "aws_security_group_rule" "external_lb_ingress_443" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.external_lb.id
}

resource "aws_security_group_rule" "external_lb_ingress_80_443_redirect" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.external_lb.id
}

resource "aws_security_group_rule" "external_lb_egress_80" {
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.api_instance.id
  security_group_id        = aws_security_group.external_lb.id
}

# external lb to nginx sg health check via port 443
resource "aws_security_group_rule" "external_lb_egress_https_nginx_sg" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  description              = "external-lb-to-nginx-sg-https"
  source_security_group_id = aws_security_group.nginx.id
  security_group_id        = aws_security_group.external_lb.id
}

resource "aws_security_group" "internal_lb" {
  name        = "${var.cluster_name}-internal-lb"
  description = "Allow API traffic to inner API"
  vpc_id      = aws_vpc.vpc.id
}

output "ecs_alb_sg_id" {
  value = aws_security_group.internal_lb.id
}

resource "aws_security_group_rule" "ecs_alb_egress_ALL" {
  type                     = "egress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cluster_instance.id
  security_group_id        = aws_security_group.internal_lb.id
}

# Outbound: allow all traffic to a CIDR
resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [var.vpc_cidr_block]
  security_group_id = aws_security_group.internal_lb.id
}

resource "aws_security_group_rule" "ecs_alb_ingress_ALL" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cluster_instance.id
  security_group_id        = aws_security_group.internal_lb.id
}

resource "aws_security_group_rule" "ecs_alb_ingress_nginx_sg" {
  type                     = "ingress"
  from_port                = 8000
  to_port                  = 8000
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.nginx.id
  security_group_id        = aws_security_group.internal_lb.id
}
