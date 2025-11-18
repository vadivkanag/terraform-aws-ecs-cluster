# worker_processes auto;
# events { worker_connections 1024; }

# http {
#     # Log format for debugging
#     log_format main '$remote_addr - $remote_user [$time_local] "$request" '
#                     '$status $body_bytes_sent "$http_referer" '
#                     '"$http_user_agent" "$http_x_forwarded_for"';

#     access_log /var/log/nginx/access.log main;

#     # Upstream definitions (your private ECS services)
#     upstream service1 {
#         server api-dev.redcloud-fargate-cluster-dev.pri:8000;   # ECS task in private subnet
#     }

#     # Reverse proxy server block
#     server {
#         listen 80;

#         # Forward based on path (listener rules from ALB can send all traffic here)
#         location /service1/ {
#             proxy_pass http://service1/;
#             proxy_set_header Host $host;
#             proxy_set_header X-Real-IP $remote_addr;
#             proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
#         }

#         # nginx health
#         location /health {
#             return 200 'ok!';
#         }

#         # Default catch-all
#         location / {
#             return 404;
#         }
#     }
# }

## nginx commands for testing:

# cd /etc/nginx
# sudo cp nginx.conf nginx.conf.bak
# sudo vi nginx.conf
# sudo nginx -t
# cat nginx.conf
# sudo /usr/sbin/nginx -s reload
# sudo systemctl restart nginx
# curl localhost/health
# curl api-dev.redcloud-fargate-cluster-dev.pri:8000/
# curl api-dev.redcloud-fargate-cluster-dev.pri:8000/healthcheck
# curl services-dev.redcloud-fargate-cluster-dev.pri/hello-world-service/
# curl services-dev.redcloud-fargate-cluster-dev.pri/hello-world-service/healthcheck