resource "aws_route53_zone" "internal_dns" {
  name = "${var.cluster_name}.pri"
  vpc {
    vpc_id = aws_vpc.vpc.id
  }

  tags = {
    Name = "${var.cluster_name}"
  }
}

output "route53_dns_id" {
  value = aws_route53_zone.internal_dns.zone_id
}
