worker_processes ${worker_processes};
events { worker_connections ${worker_connections}; }

http {
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    # Include upstream configs
    include /etc/nginx/conf.d/http/upstreams/*.conf;

    server {
        listen ${listen_port} ssl;

        ssl_certificate     /etc/nginx/ssl/${domain_name}.crt;
        ssl_certificate_key /etc/nginx/ssl/${domain_name}.key;

        # Include location configs
        include /etc/nginx/conf.d/http/server/locations/*.conf;

        location /health {
            return 200 'ok!';
        }

        location / {
            return 200 'Welcome to RedCloud Homepage!';
        }
    }
}