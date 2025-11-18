############ vpc ############
data "aws_availability_zones" "zones" {}

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.region}-${var.cluster_name}-vpc"
  }
}

output "vpc_id" {
  value = aws_vpc.vpc.id
}


############ subnets ############
resource "aws_subnet" "dmz_subnet" {
  count                   = var.subnet_count
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(cidrsubnet(var.vpc_cidr_block, 4, 2), 2, count.index)
  map_public_ip_on_launch = false
  availability_zone       = element(data.aws_availability_zones.zones.names, count.index % length(data.aws_availability_zones.zones.names))

  tags = {
    Name = (format("%s-%s-dmz-subnet-%s",
      element(data.aws_availability_zones.zones.names, count.index % length(data.aws_availability_zones.zones.names)),
      var.cluster_name,
      substr(element(data.aws_availability_zones.zones.names, count.index % length(data.aws_availability_zones.zones.names)),
      length(element(data.aws_availability_zones.zones.names, count.index % length(data.aws_availability_zones.zones.names))) - 1, 1)
    ))
  }
}

output "dmz_subnet_ids" {
  value = aws_subnet.dmz_subnet.*.id
}

resource "aws_subnet" "api_subnet" {
  count                   = var.subnet_count
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(cidrsubnet(var.vpc_cidr_block, 4, 3), 2, count.index)
  map_public_ip_on_launch = false
  availability_zone       = element(data.aws_availability_zones.zones.names, count.index % length(data.aws_availability_zones.zones.names))

  tags = {
    Name = (format("%s-%s-api-subnet-%s",
      element(data.aws_availability_zones.zones.names, count.index % length(data.aws_availability_zones.zones.names)),
      var.cluster_name,
      substr(element(data.aws_availability_zones.zones.names, count.index % length(data.aws_availability_zones.zones.names)),
      length(element(data.aws_availability_zones.zones.names, count.index % length(data.aws_availability_zones.zones.names))) - 1, 1)
    ))
  }
}

output "api_subnet_ids" {
  value = aws_subnet.api_subnet.*.id
}

resource "aws_subnet" "ecs_subnet" {
  count                   = var.subnet_count
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(cidrsubnet(var.vpc_cidr_block, 4, 1), 2, count.index)
  map_public_ip_on_launch = false
  availability_zone       = element(data.aws_availability_zones.zones.names, count.index % length(data.aws_availability_zones.zones.names))

  tags = {
    Name = "${format("%s-%s-ecs-subnet-%s",
      element(data.aws_availability_zones.zones.names, count.index % length(data.aws_availability_zones.zones.names)),
      var.cluster_name,
      substr(element(data.aws_availability_zones.zones.names, count.index % length(data.aws_availability_zones.zones.names)),
      length(element(data.aws_availability_zones.zones.names, count.index % length(data.aws_availability_zones.zones.names))) - 1, 1)
    )}"
  }
}

output "ecs_subnet_ids" {
  value = aws_subnet.ecs_subnet.*.id
}

############ Elastic IP ############
resource "aws_eip" "nat" {
  count  = var.subnet_count
  domain = "vpc"

  lifecycle {
    prevent_destroy = false # true
  }
}

output "nat_gw_ips" {
  value = aws_eip.nat.*.public_ip
}

############ Nat Gateway ############
resource "aws_nat_gateway" "nat_gw" {
  count         = var.subnet_count
  allocation_id = element(aws_eip.nat.*.id, count.index)
  subnet_id     = element(aws_subnet.dmz_subnet.*.id, count.index)
}

############ Internet Gateway ############
resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "Internet Gateway"
  }
}


############ Route Table ############

resource "aws_route_table" "dmz_route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway.id
  }

  tags = {
    Name = "DMZ"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc.id
  count  = var.subnet_count

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = element(aws_nat_gateway.nat_gw.*.id, count.index)
  }

  tags = {
    Name = format("ECS-%d", count.index + 1)
  }
}

############ Route Table Associations ############
resource "aws_route_table_association" "dmz_route_association" {
  count          = var.subnet_count
  subnet_id      = element(aws_subnet.dmz_subnet.*.id, count.index)
  route_table_id = aws_route_table.dmz_route_table.id
}

resource "aws_route_table_association" "api_route_association" {
  count          = var.subnet_count
  subnet_id      = element(aws_subnet.api_subnet.*.id, count.index)
  route_table_id = element(aws_route_table.private_route_table.*.id, count.index)
}

resource "aws_route_table_association" "cluster_route_association" {
  count          = var.subnet_count
  subnet_id      = element(aws_subnet.ecs_subnet.*.id, count.index)
  route_table_id = element(aws_route_table.private_route_table.*.id, count.index)
}

############ VPC Endpoints ############
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${var.region}.s3"
  route_table_ids   = aws_route_table.private_route_table.*.id
  vpc_endpoint_type = "Gateway"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "s3:GetObject"
      ],
      "Resource": "*"
    }
  ]
}
POLICY
  tags = {
    Environment = "dev"
    Name        = "ecr-s3-endpoint"
  }
}

resource "aws_vpc_endpoint" "ecr_dkr_endpoint" {
  vpc_id              = aws_vpc.vpc.id
  private_dns_enabled = true
  service_name        = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.api_instance.id]
  subnet_ids          = aws_subnet.api_subnet.*.id
  tags = {
    Environment = "dev"
    Name        = "ecr-dkr-endpoint"
  }
}

resource "aws_vpc_endpoint" "ecr_api_endpoint" {
  vpc_id              = aws_vpc.vpc.id
  service_name        = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.api_instance.id]
  subnet_ids          = aws_subnet.api_subnet.*.id
  tags = {
    Environment = "dev"
    Name        = "ecr-api-endpoint"
  }
}

resource "aws_vpc_endpoint" "ecs_agent" {
  vpc_id              = aws_vpc.vpc.id
  service_name        = "com.amazonaws.${var.region}.ecs-agent"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.api_instance.id]
  subnet_ids          = aws_subnet.api_subnet.*.id
  tags = {
    Environment = "dev"
    Name        = "ecr-ecs-agent-endpoint"
  }
}

resource "aws_vpc_endpoint" "dynamodb_interface" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${var.region}.dynamodb"
  vpc_endpoint_type = "Interface"
  # private_dns_enabled = true # NOT SUPPORTED: https://stackoverflow.com/questions/78487603/aws-dynamodb-interface-vpc-endpoint-privatelink-cannot-enable-private-dns
  security_group_ids = [aws_security_group.api_instance.id]
  subnet_ids         = aws_subnet.api_subnet.*.id
  tags = {
    Environment = "dev"
    Name        = "dynamodb-interface-endpoint"
  }
}

resource "aws_vpc_endpoint" "dynamodb_gateway" {
  service_name = "com.amazonaws.${var.region}.dynamodb"
  vpc_id       = aws_vpc.vpc.id
  tags = {
    Environment = "dev"
    Name        = "dynamodb-gateway-endpoint"
  }
}

resource "aws_vpc_endpoint_policy" "dynamodb_gateway_policy" {
  vpc_endpoint_id = aws_vpc_endpoint.dynamodb_gateway.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "Allow-access-from-specific-endpoint",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "*"
        },
        "Action" : [
          "dynamodb:*"
        ],
        "Resource" : "arn:aws:dynamodb:${var.region}:${local.account_id}:table/*",
      }
    ]
  })
}
