#!/bin/bash
#===============================================================================
# trojan-go.sh - Trojan-Go + Nginx 一键部署脚本
# 功能: 环境初始化、安装Trojan-Go、配置Nginx、SSL证书部署、开机自启
#===============================================================================

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/common.sh"
source "${SCRIPT_DIR}/../../config/versions.conf"

# 配置变量
TROJAN_VERSION="v0.10.6"
TROJAN_INSTALL_DIR="/usr/local/trojan-go"
TROJAN_CONFIG_FILE="${TROJAN_INSTALL_DIR}/config.json"
TROJAN_LOG_DIR="/var/log/trojan-go"
NGINX_VHOST_DIR="/usr/local/openresty/nginx/conf/vhost"
SSL_DIR="/usr/local/openresty/nginx/conf/ssl"

#===============================================================================
# 生成随机密码
#===============================================================================
generate_password() {
    local length="${1:-32}"
    openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c"${length}"
}

#===============================================================================
# 环境初始化
#===============================================================================
init_environment() {
    log_step "开始环境初始化"
    
    log_info "更新系统包列表"
    apt-get update -y
    
    log_info "安装必要的系统工具"
    apt_install curl wget unzip tar gzip openssl ca-certificates gnupg2 lsb-release jq
    
    log_info "创建必要的目录"
    mkdir -p "${TROJAN_INSTALL_DIR}"
    mkdir -p "${TROJAN_LOG_DIR}"
    mkdir -p "${NGINX_VHOST_DIR}"
    mkdir -p "${SSL_DIR}"
    
    log_info "环境初始化完成"
}

#===============================================================================
# 安装 Nginx (OpenResty)
#===============================================================================
install_nginx() {
    log_step "检查并安装 Nginx (OpenResty)"
    
    # 检查是否已安装
    if command -v openresty >/dev/null 2>&1 || command -v nginx >/dev/null 2>&1; then
        log_info "Nginx/OpenResty 已安装，跳过安装步骤"
        return 0
    fi
    
    log_info "使用官方源快速安装 OpenResty"
    
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
    
    # 创建 Nginx systemd 服务
    create_nginx_service
    
    log_info "OpenResty 安装完成"
}

#===============================================================================
# 创建 Nginx systemd 服务
#===============================================================================
create_nginx_service() {
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
# 安装 Trojan-Go
#===============================================================================
install_trojan_go() {
    log_step "安装 Trojan-Go ${TROJAN_VERSION}"
    
    log_info "下载 Trojan-Go"
    cd /tmp
    wget -q "https://github.com/p4gefau1t/trojan-go/releases/download/${TROJAN_VERSION}/trojan-go-linux-amd64.zip"
    
    log_info "解压并安装"
    unzip -q trojan-go-linux-amd64.zip -d trojan-go-tmp
    cp trojan-go-tmp/trojan-go "${TROJAN_INSTALL_DIR}/"
    chmod +x "${TROJAN_INSTALL_DIR}/trojan-go"
    
    # 复制示例配置文件（如果存在）
    if [[ -f trojan-go-tmp/geoip.dat ]]; then
        cp trojan-go-tmp/geoip.dat "${TROJAN_INSTALL_DIR}/"
    fi
    if [[ -f trojan-go-tmp/geosite.dat ]]; then
        cp trojan-go-tmp/geosite.dat "${TROJAN_INSTALL_DIR}/"
    fi
    
    rm -rf trojan-go-tmp trojan-go-linux-amd64.zip
    
    log_info "Trojan-Go 安装完成"
}

#===============================================================================
# 创建 Trojan-Go 配置文件
#===============================================================================
create_trojan_config() {
    local domain="$1"
    local password="$2"
    
    log_step "创建 Trojan-Go 配置文件"
    
    cat > "${TROJAN_CONFIG_FILE}" << EOF
{
    "run_type": "server",
    "local_addr": "127.0.0.1",
    "local_port": 8443,
    "remote_addr": "127.0.0.1",
    "remote_port": 80,
    "password": [
        "${password}"
    ],
    "log_level": 1,
    "log_file": "${TROJAN_LOG_DIR}/trojan-go.log",
    "ssl": {
        "cert": "${SSL_DIR}/${domain}.crt",
        "key": "${SSL_DIR}/${domain}.key",
        "sni": "${domain}",
        "alpn": [
            "http/1.1"
        ],
        "session_ticket": true,
        "reuse_session": true,
        "plain_http_response": "",
        "fallback_addr": "127.0.0.1",
        "fallback_port": 80,
        "fingerprint": "firefox"
    },
    "tcp": {
        "prefer_ipv4": true,
        "no_delay": true,
        "keep_alive": true,
        "fast_open": true,
        "fast_open_qlen": 20
    },
    "websocket": {
        "enabled": true,
        "path": "/ws${password:0:8}",
        "host": "${domain}"
    }
}
EOF

    log_info "配置文件已创建: ${TROJAN_CONFIG_FILE}"
}

#===============================================================================
# 创建 Trojan-Go systemd 服务
#===============================================================================
create_trojan_service() {
    log_step "创建 Trojan-Go systemd 服务"
    
    cat > /lib/systemd/system/trojan-go.service << EOF
[Unit]
Description=Trojan-Go Proxy Server
Documentation=https://p4gefau1t.github.io/trojan-go/
After=network.target network-online.target nss-lookup.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=${TROJAN_INSTALL_DIR}
ExecStart=${TROJAN_INSTALL_DIR}/trojan-go -config ${TROJAN_CONFIG_FILE}
Restart=on-failure
RestartSec=5s
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    log_info "Trojan-Go systemd 服务已创建"
}

#===============================================================================
# 配置 Nginx 虚拟主机
#===============================================================================
create_nginx_vhost() {
    local domain="$1"
    local vhost_file="${NGINX_VHOST_DIR}/${domain}.conf"
    
    log_step "创建 Nginx 虚拟主机配置: ${domain}"
    
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
    
    # SSL 证书配置
    ssl_certificate SSL_DIR_PLACEHOLDER/DOMAIN_PLACEHOLDER.crt;
    ssl_certificate_key SSL_DIR_PLACEHOLDER/DOMAIN_PLACEHOLDER.key;
    
    # SSL 优化配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # 日志
    access_log /var/log/nginx/DOMAIN_PLACEHOLDER.access.log;
    error_log /var/log/nginx/DOMAIN_PLACEHOLDER.error.log;
    
    # 伪装网站根目录
    root /var/www/DOMAIN_PLACEHOLDER;
    index index.html index.htm;
    
    # WebSocket 代理到 Trojan-Go
    location ~ ^/ws[a-zA-Z0-9]{8}$ {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:8443;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
    
    # 默认页面
    location / {
        try_files $uri $uri/ =404;
    }
}
EOFNGINX

    # 替换占位符
    sed -i "s|DOMAIN_PLACEHOLDER|${domain}|g" "${vhost_file}"
    sed -i "s|SSL_DIR_PLACEHOLDER|${SSL_DIR}|g" "${vhost_file}"
    
    # 创建伪装网站目录和默认页面
    mkdir -p "/var/www/${domain}"
    cat > "/var/www/${domain}/index.html" << 'EOFHTML'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Welcome</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; background: #f5f5f5; }
        h1 { color: #333; }
    </style>
</head>
<body>
    <h1>Welcome to Nginx</h1>
    <p>服务器运行正常</p>
</body>
</html>
EOFHTML
    
    log_info "Nginx 虚拟主机配置已创建: ${vhost_file}"
}

#===============================================================================
# 部署 SSL 证书
#===============================================================================
deploy_ssl_cert() {
    local domain="$1"
    local cert_content="$2"
    local key_content="$3"
    
    log_step "部署 SSL 证书"
    
    echo "${cert_content}" > "${SSL_DIR}/${domain}.crt"
    echo "${key_content}" > "${SSL_DIR}/${domain}.key"
    chmod 600 "${SSL_DIR}/${domain}.key"
    
    log_info "SSL 证书已部署"
}

#===============================================================================
# 交互式配置
#===============================================================================
interactive_config() {
    log_step "交互式配置向导"
    
    echo ""
    echo "=========================================="
    echo "  Trojan-Go + Nginx 部署配置"
    echo "=========================================="
    echo ""
    
    # 获取域名
    read -p "请输入域名 (例如: example.com): " DOMAIN
    while [[ -z "${DOMAIN}" ]]; do
        echo -e "${RED}域名不能为空${NC}"
        read -p "请输入域名: " DOMAIN
    done
    
    # 生成随机密码
    TROJAN_PASSWORD=$(generate_password 32)
    
    echo ""
    echo "已生成 Trojan-Go 密码: ${GREEN}${TROJAN_PASSWORD}${NC}"
    echo "请妥善保存此密码！"
    echo ""
    
    # 获取证书内容
    echo "=========================================="
    echo "请粘贴 SSL 证书内容 (以 -----BEGIN CERTIFICATE----- 开头)"
    echo "粘贴完成后按 Ctrl+D 结束输入"
    echo "=========================================="
    CERT_CONTENT=$(cat)
    
    echo ""
    echo "=========================================="
    echo "请粘贴 SSL 私钥内容 (以 -----BEGIN PRIVATE KEY----- 开头)"
    echo "粘贴完成后按 Ctrl+D 结束输入"
    echo "=========================================="
    KEY_CONTENT=$(cat)
    
    # 验证输入
    if [[ -z "${CERT_CONTENT}" ]] || [[ -z "${KEY_CONTENT}" ]]; then
        log_error "证书或私钥内容为空，退出安装"
        exit 1
    fi
    
    # 部署证书
    deploy_ssl_cert "${DOMAIN}" "${CERT_CONTENT}" "${KEY_CONTENT}"
    
    # 创建配置
    create_trojan_config "${DOMAIN}" "${TROJAN_PASSWORD}"
    create_nginx_vhost "${DOMAIN}"
    
    # 保存配置信息到文件
    cat > "${TROJAN_INSTALL_DIR}/install_info.txt" << EOF
========================================
Trojan-Go 安装信息
========================================
安装时间: $(date '+%Y-%m-%d %H:%M:%S')
域名: ${DOMAIN}
Trojan-Go 密码: ${TROJAN_PASSWORD}
WebSocket 路径: /ws${TROJAN_PASSWORD:0:8}
服务端口: 443 (HTTPS)
配置文件: ${TROJAN_CONFIG_FILE}
日志目录: ${TROJAN_LOG_DIR}
========================================
EOF
    
    echo ""
    log_info "配置信息已保存到: ${TROJAN_INSTALL_DIR}/install_info.txt"
}

#===============================================================================
# 启用服务并设置开机自启
#===============================================================================
enable_services() {
    log_step "启用服务并设置开机自启"
    
    # 启用 Nginx
    systemctl enable nginx
    systemctl restart nginx
    log_info "Nginx 已启动并设置为开机自启"
    
    # 启用 Trojan-Go
    systemctl enable trojan-go
    systemctl restart trojan-go
    log_info "Trojan-Go 已启动并设置为开机自启"
}

#===============================================================================
# 显示服务状态
#===============================================================================
show_status() {
    log_step "服务状态"
    
    echo ""
    echo "=========================================="
    echo "  Nginx 状态"
    echo "=========================================="
    systemctl status nginx --no-pager -l || true
    
    echo ""
    echo "=========================================="
    echo "  Trojan-Go 状态"
    echo "=========================================="
    systemctl status trojan-go --no-pager -l || true
    
    echo ""
    echo "=========================================="
    echo "  端口监听状态"
    echo "=========================================="
    netstat -tlnp | grep -E '(:80|:443|:8443)' || ss -tlnp | grep -E '(:80|:443|:8443)' || true
}

#===============================================================================
# 显示安装信息
#===============================================================================
show_install_info() {
    log_step "安装完成"
    
    echo ""
    echo "=========================================="
    echo "  Trojan-Go + Nginx 部署完成"
    echo "=========================================="
    
    if [[ -f "${TROJAN_INSTALL_DIR}/install_info.txt" ]]; then
        cat "${TROJAN_INSTALL_DIR}/install_info.txt"
    fi
    
    echo ""
    echo "常用命令:"
    echo "  查看 Trojan-Go 状态: systemctl status trojan-go"
    echo "  查看 Trojan-Go 日志: tail -f ${TROJAN_LOG_DIR}/trojan-go.log"
    echo "  查看 Nginx 状态: systemctl status nginx"
    echo "  重启 Trojan-Go: systemctl restart trojan-go"
    echo "  重启 Nginx: systemctl restart nginx"
    echo "=========================================="
}

#===============================================================================
# 主安装流程
#===============================================================================
install() {
    log_step "开始 Trojan-Go + Nginx 一键部署"
    
    # 检查 root 权限
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本必须以 root 权限运行"
        exit 1
    fi
    
    # 环境初始化
    init_environment
    
    # 检查并安装 Nginx（如果未安装，使用官方快速安装）
    install_nginx
    
    # 安装 Trojan-Go
    install_trojan_go
    
    # 创建 Trojan-Go 服务
    create_trojan_service
    
    # 交互式配置
    interactive_config
    
    # 启用服务
    enable_services
    
    # 显示状态
    show_status
    
    # 显示安装信息
    show_install_info
}

#===============================================================================
# 卸载
#===============================================================================
uninstall() {
    log_step "卸载 Trojan-Go"
    
    systemctl stop trojan-go 2>/dev/null || true
    systemctl disable trojan-go 2>/dev/null || true
    rm -f /lib/systemd/system/trojan-go.service
    rm -rf "${TROJAN_INSTALL_DIR}"
    rm -rf "${TROJAN_LOG_DIR}"
    
    systemctl daemon-reload
    
    log_info "Trojan-Go 已卸载"
}

#===============================================================================
# 重新加载配置
#===============================================================================
reload() {
    log_step "重新加载配置"
    
    systemctl reload nginx
    systemctl restart trojan-go
    
    show_status
}

#===============================================================================
# 命令行参数处理
#===============================================================================
case "${1:-install}" in
    install)
        install
        ;;
    uninstall)
        uninstall
        ;;
    reload)
        reload
        ;;
    status)
        show_status
        ;;
    *)
        echo "用法: $0 {install|uninstall|reload|status}"
        exit 1
        ;;
esac
