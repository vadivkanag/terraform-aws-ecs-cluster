# Internal Application Load Balancer and associated components for ECS Cluster
resource "aws_alb" "internal_alb" {
  name            = "redcloud-${var.environment}-internal"
  security_groups = ["${aws_security_group.internal_lb.id}"]
  subnets         = [for subnet in aws_subnet.ecs_subnet : subnet.id]
  internal        = true
}

resource "aws_route53_record" "internal_api" {
  zone_id = aws_route53_zone.internal_dns.zone_id
  name    = "api-${var.environment}"
  type    = "A"

  alias {
    name                   = aws_alb.internal_alb.dns_name
    zone_id                = aws_alb.internal_alb.zone_id
    evaluate_target_health = true
  }
}

output "ecs_alb_arn" {
  value = aws_alb.internal_alb.arn
}

output "alb_dns_address" {
  value = aws_route53_record.internal_api.fqdn
}
