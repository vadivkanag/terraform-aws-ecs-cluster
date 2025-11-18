data "aws_ami" "amzn_nginxplus_ami" {
  most_recent = true
  owners      = ["amazon", "679593333241"]

  filter {
    name   = "name"
    values = ["nginx-plus-amazon-linux-2-v1.18-x86_64-standard-*"]
    # AMI ID: "eu-west-2": "ami-0f150c52b15ae576e"
    # 30 days free trial - https://aws.amazon.com/marketplace/pp/prodview-imtfcaibuxlik
  }
}

# data "templatefile" "userdata" {
#   template = file("${path.module}/nginx_user_data.tmpl")

#   vars = {
#     infra_config_bucket = var.infra_config_bucket
#     region              = var.region
#   }
# }

locals {
  user_data = templatefile("${path.module}/nginx_user_data.tmpl", {
    infra_config_bucket = var.infra_config_bucket
    region              = var.region
  })
}

# resource "local_file" "user_data" {
#   content  = local.user_data
#   filename = "${path.module}/nginx_user_data"
# }

resource "aws_launch_template" "nginx_plus" {
  name_prefix   = "nginx-plus-"
  image_id      = data.aws_ami.amzn_nginxplus_ami.id
  instance_type = "t2.medium"
  key_name      = "nginx" # created manually

  iam_instance_profile {
    arn = aws_iam_instance_profile.api_instance.arn
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.nginx.id]
  }

  user_data = base64encode(local.user_data)

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "nginx-plus-instance-${var.environment}"
    }
  }
  depends_on = [
    aws_s3_object.nginx_conf,
    aws_s3_object.awslogs_nginx,
    aws_security_group.api_instance,
  ]
}

resource "aws_autoscaling_group" "nginx_plus_asg" {
  name                = "${aws_ecs_cluster.this[0].name}-nginx-scaling-group-${var.environment}"
  max_size            = 3
  min_size            = 1
  desired_capacity    = 1
  vpc_zone_identifier = aws_subnet.dmz_subnet.*.id

  launch_template {
    id      = aws_launch_template.nginx_plus.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.nginx_https.arn]

  # Instance refresh block
  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 90
      instance_warmup        = 300
    }

    # # Triggers: when these change, Terraform starts a refresh
    # triggers = ["launch_template"]
  }

  tag {
    key                 = "Name"
    value               = "nginx-plus-asg-instance"
    propagate_at_launch = true
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300
}

output "nginx_asg_name" {
  value = aws_autoscaling_group.nginx_plus_asg.name
}

resource "aws_iam_instance_profile" "api_instance" {
  name = "api-instance-${var.environment}"
  role = aws_iam_role.api_instance_role.id
}

data "aws_iam_policy_document" "api_instance_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "api_instance_role" {
  name = "api-instance-role-${var.environment}"

  assume_role_policy = data.aws_iam_policy_document.api_instance_role_policy.json
}

resource "aws_iam_role_policy_attachment" "api_role_policy" {
  role       = aws_iam_role.api_instance_role.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_role_policy_attachment" "iam_policy" {
  role       = aws_iam_role.api_instance_role.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

data "aws_iam_policy_document" "api_config_read_policy_document" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.infra_config_bucket}/*"]
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.infra_config_bucket}"]
  }
}

resource "aws_iam_role_policy" "api_s3_read_policy" {
  name = "APIConfigReadOnly-${var.environment}"
  role = aws_iam_role.api_instance_role.id

  policy = data.aws_iam_policy_document.api_config_read_policy_document.json
}

resource "aws_iam_role_policy" "api_cloudwatch_log_push" {
  name = "APICloudWatchWrite-${var.environment}"
  role = aws_iam_role.api_instance_role.id

  policy = data.aws_iam_policy_document.api_cloudwatch_log_push.json
}

data "aws_iam_policy_document" "api_cloudwatch_log_push" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["*"]
  }
}

resource "aws_security_group" "nginx" {
  name        = "nginx-sg-${var.environment}"
  description = "Allow HTTP and SSH"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_cloudwatch_log_group" "nginx_error_log" {
  name              = "nginx-error-logs-${var.environment}"
  retention_in_days = 7
  tags              = merge(var.tags, var.cloudwatch_log_group_tags)
}
