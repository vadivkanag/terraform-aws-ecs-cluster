locals {
  nginx_config = templatefile("${path.module}/nginx-base-confs/nginx.conf.tpl", {
    listen_port        = "443"
    domain_name        = var.public_dns_zone_name # nginx ssl certs are named after domain
    worker_processes   = "auto"
    worker_connections = "1024"
  })
}

# resource "local_file" "nginx_config" {
#   content  = local.nginx_config
#   filename = "${path.module}/nginx-base-confs/nginx.conf"
# }

resource "aws_s3_object" "nginx_conf" {
  bucket  = var.infra_config_bucket
  key     = "nginx.conf"
  content = local.nginx_config
}

resource "aws_s3_object" "awslogs_nginx" {
  bucket = var.infra_config_bucket
  key    = "awslogs/nginx-error.conf"
  source = "${path.module}/nginx-base-confs/awslogs-nginx.conf"
}
