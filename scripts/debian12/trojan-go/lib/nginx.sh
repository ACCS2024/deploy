#!/bin/bash
#===============================================================================
# nginx.sh - Nginx (OpenResty) 安装和配置
#===============================================================================

#===============================================================================
# 安装 Nginx/OpenResty
#===============================================================================
install_nginx() {
    log_step "安装 Nginx (OpenResty)"
    
    # 检查是否已安装
    if command -v nginx >/dev/null 2>&1 || command -v openresty >/dev/null 2>&1; then
        log_info "Nginx/OpenResty 已安装"
        return 0
    fi
    
    log_info "使用官方源安装 OpenResty"
    
    # 安装依赖
    apt_install wget gnupg ca-certificates lsb-release
    
    # 导入 GPG 密钥
    wget -qO - https://openresty.org/package/pubkey.gpg | apt-key add -
    
    # 添加官方源
    echo "deb http://openresty.org/package/debian $(lsb_release -sc) openresty" \
        > /etc/apt/sources.list.d/openresty.list
    
    # 更新并安装
    apt-get update -y
    apt_install openresty
    
    # 创建软链接
    ln -sf /usr/local/openresty/nginx/sbin/nginx /usr/bin/nginx 2>/dev/null || true
    ln -sf /usr/local/openresty/bin/openresty /usr/bin/openresty 2>/dev/null || true
    
    # 创建 systemd 服务
    create_nginx_service
    
    # 创建 vhost 目录
    mkdir -p /etc/openresty/vhost
    
    # 配置 nginx.conf 引入 vhost
    configure_nginx_vhost_include
    
    log_info "✓ OpenResty 安装完成"
}

#===============================================================================
# 创建 Nginx systemd 服务
#===============================================================================
create_nginx_service() {
    if [[ -f /lib/systemd/system/nginx.service ]]; then
        log_info "Nginx service 已存在"
        return 0
    fi
    
    log_info "创建 Nginx systemd 服务"
    
    cat > /lib/systemd/system/nginx.service << 'EOF'
[Unit]
Description=OpenResty - High Performance Web Server
Documentation=https://openresty.org/
After=network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target

[Service]
Type=forking
PIDFile=/usr/local/openresty/nginx/logs/nginx.pid
ExecStartPre=/usr/local/openresty/nginx/sbin/nginx -t -q -g 'daemon on; master_process on;'
ExecStart=/usr/local/openresty/nginx/sbin/nginx -g 'daemon on; master_process on;'
ExecReload=/bin/sh -c "/bin/kill -s HUP $(/bin/cat /usr/local/openresty/nginx/logs/nginx.pid)"
ExecStop=/bin/sh -c "/bin/kill -s TERM $(/bin/cat /usr/local/openresty/nginx/logs/nginx.pid)"
Restart=on-failure
RestartSec=5s
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
}

#===============================================================================
# 配置 Nginx 引入 vhost 目录
#===============================================================================
configure_nginx_vhost_include() {
    local nginx_conf="/usr/local/openresty/nginx/conf/nginx.conf"
    
    if [[ ! -f "$nginx_conf" ]]; then
        log_error "Nginx 配置文件不存在: $nginx_conf"
        return 1
    fi
    
    # 检查是否已经配置了 vhost 引入
    if grep -q "include /etc/openresty/vhost/\*.conf;" "$nginx_conf"; then
        log_info "Nginx 已配置 vhost 引入"
        return 0
    fi
    
    log_info "配置 Nginx 引入 vhost 目录"
    
    # 备份配置文件
    local backup_file="${nginx_conf}.bak.$(date +%Y%m%d_%H%M%S)"
    cp "$nginx_conf" "$backup_file"
    
    # 在 http 块的末尾添加 include 指令
    # 使用更安全的方式：在最后一个 } 前插入
    if sed -i '/^http {/,/^}/ {
        /^}/i\    # 引入虚拟主机配置\n    include /etc/openresty/vhost/*.conf;
    }' "$nginx_conf"; then
        log_info "✓ Nginx vhost 引入配置完成"
    else
        log_error "配置修改失败，恢复备份"
        cp "$backup_file" "$nginx_conf" 2>/dev/null || true
        return 1
    fi
    
    # 测试配置
    if ! nginx -t 2>/dev/null; then
        log_error "Nginx 配置测试失败，恢复备份"
        cp "$backup_file" "$nginx_conf" 2>/dev/null || true
        return 1
    fi
}

#===============================================================================
# 创建 Nginx 虚拟主机配置
#===============================================================================
create_nginx_vhost() {
    local domain="$1"
    local ws_path="$2"
    
    # 参数验证
    if [[ -z "$domain" ]]; then
        log_error "域名参数不能为空"
        return 1
    fi
    
    if [[ -z "$ws_path" ]]; then
        log_error "WebSocket 路径参数不能为空"
        return 1
    fi
    
    # 确保目录存在
    mkdir -p "${NGINX_VHOST_DIR}"
    
    local vhost_file="${NGINX_VHOST_DIR}/${domain}.conf"
    
    log_step "创建 Nginx 虚拟主机: ${domain}"
    
    # 使用模板文件
    local template_file="${SCRIPT_DIR}/../templates/nginx-vhost.conf"
    
    if [[ -f "$template_file" ]]; then
        cp "$template_file" "$vhost_file"
    else
        # 内嵌模板
        cat > "${vhost_file}" << 'EOFNGINX'
server {
    listen 80;
    listen [::]:80;
    server_name DOMAIN_PLACEHOLDER;
    
    # HTTP 重定向到 HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name DOMAIN_PLACEHOLDER;
    
    # SSL 证书配置（Let's Encrypt）
    ssl_certificate /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/privkey.pem;
    ssl_trusted_certificate /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/chain.pem;
    
    # SSL 优化配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;
    ssl_stapling on;
    ssl_stapling_verify on;
    
    # 安全头
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # 日志
    access_log /var/log/nginx/DOMAIN_PLACEHOLDER.access.log;
    error_log /var/log/nginx/DOMAIN_PLACEHOLDER.error.log;
    
    # 伪装网站根目录
    root /var/www/DOMAIN_PLACEHOLDER;
    index index.html index.htm;
    
    # WebSocket 代理到 Trojan-Go
    location WS_PATH_PLACEHOLDER {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:8443;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # 默认页面
    location / {
        try_files $uri $uri/ =404;
    }
}
EOFNGINX
    fi
    
    # 替换占位符
    sed -i "s|DOMAIN_PLACEHOLDER|${domain}|g" "${vhost_file}"
    sed -i "s|WS_PATH_PLACEHOLDER|${ws_path}|g" "${vhost_file}"
    
    # 创建伪装网站
    create_fake_website "$domain"
    
    log_info "✓ Nginx 虚拟主机配置已创建: ${vhost_file}"
}

#===============================================================================
# 创建伪装网站
#===============================================================================
create_fake_website() {
    local domain="$1"
    local webroot="/var/www/${domain}"
    
    mkdir -p "$webroot"
    
    cat > "${webroot}/index.html" << 'EOFHTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Welcome</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .container {
            background: white;
            border-radius: 20px;
            padding: 60px 40px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            text-align: center;
            max-width: 500px;
        }
        h1 {
            color: #333;
            font-size: 2.5em;
            margin-bottom: 20px;
        }
        p {
            color: #666;
            font-size: 1.1em;
            line-height: 1.6;
        }
        .status {
            display: inline-block;
            background: #10b981;
            color: white;
            padding: 10px 20px;
            border-radius: 25px;
            margin-top: 20px;
            font-weight: 600;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Welcome</h1>
        <p>Server is running normally</p>
        <div class="status">✓ Online</div>
    </div>
</body>
</html>
EOFHTML
    
    log_info "✓ 伪装网站已创建: $webroot"
}

#===============================================================================
# 测试 Nginx 配置
#===============================================================================
test_nginx_config() {
    log_info "测试 Nginx 配置..."
    
    if nginx -t 2>&1; then
        log_info "✓ Nginx 配置正确"
        return 0
    else
        log_error "✗ Nginx 配置错误"
        return 1
    fi
}

#===============================================================================
# 重载 Nginx
#===============================================================================
reload_nginx() {
    if test_nginx_config; then
        systemctl reload nginx
        log_info "✓ Nginx 已重载"
    else
        log_error "配置错误，取消重载"
        return 1
    fi
}
