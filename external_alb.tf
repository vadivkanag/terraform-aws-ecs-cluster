
# Internet facing Application Load Balancer and associated components for routing requests nginx reverse proxy calls
resource "aws_lb" "external_load_balancer" {
  name                       = "redcloud-${var.environment}-external"
  subnets                    = aws_subnet.dmz_subnet.*.id
  security_groups            = ["${aws_security_group.external_lb.id}"]
  enable_deletion_protection = false # true

  idle_timeout = 400

  tags = {
    Name = "External_load_balancer"
  }
}

# promote http to https on external lb
resource "aws_lb_listener" "http_to_https" {
  load_balancer_arn = aws_lb.external_load_balancer.arn
  port              = "80"
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

resource "aws_lb_listener" "nginx_https" {
  load_balancer_arn = aws_lb.external_load_balancer.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.iam_tls_certificate_arn

  default_action {
    target_group_arn = aws_lb_target_group.nginx_https.arn
    type             = "forward"
  }
}

# resource "aws_lb_target_group" "nginx_http" {
#   name     = "nginx-${var.environment}"
#   port     = 80
#   protocol = "HTTP"
#   vpc_id   = aws_vpc.vpc.id

#   health_check {
#     timeout             = 5 # default
#     healthy_threshold   = 2
#     unhealthy_threshold = 2         # default 
#     interval            = 30        # default
#     path                = "/health" # default
#     matcher             = "200"
#   }
# }

resource "aws_lb_target_group" "nginx_https" {
  name     = "nginx-${var.environment}"
  port     = 443
  vpc_id   = aws_vpc.vpc.id
  protocol = "HTTPS"

  health_check {
    port                = "443"
    protocol            = "HTTPS" # need to set the health check protocol to HTTPS explicitly 
    timeout             = 5       # default
    healthy_threshold   = 2
    unhealthy_threshold = 2         # default 
    interval            = 30        # default
    path                = "/health" # default
    matcher             = "200"
  }
}

output "external_lb_dns_name" {
  value = aws_lb.external_load_balancer.dns_name
}

resource "aws_route53_record" "external_api" {
  zone_id = aws_route53_zone.internal_dns.zone_id
  name    = "services-${var.environment}"
  type    = "A"

  alias {
    name                   = aws_lb.external_load_balancer.dns_name
    zone_id                = aws_lb.external_load_balancer.zone_id
    evaluate_target_health = true
  }
}
