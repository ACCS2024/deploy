#!/bin/bash
#===============================================================================
# ssl.sh - SSL 证书管理（使用 certbot 自动申请和续期）
#===============================================================================

#===============================================================================
# 安装 certbot
#===============================================================================
install_certbot() {
    log_step "安装 Certbot"
    
    if command -v certbot >/dev/null 2>&1; then
        log_info "Certbot 已安装"
        return 0
    fi
    
    # 安装 certbot 和 nginx 插件
    apt_install certbot python3-certbot-nginx
    
    log_info "✓ Certbot 安装完成"
}

#===============================================================================
# 申请 SSL 证书
#===============================================================================
request_ssl_cert() {
    local domain="$1"
    local email="${2:-admin@${domain}}"
    
    # 参数验证
    if [[ -z "$domain" ]]; then
        log_error "域名参数不能为空"
        return 1
    fi
    
    log_step "申请 SSL 证书: ${domain}"
    
    # 停止 nginx 以释放 80 端口
    systemctl stop nginx 2>/dev/null || true
    pkill -9 nginx 2>/dev/null || true
    sleep 2
    
    # 使用 standalone 模式申请证书
    log_info "使用 Let's Encrypt 申请证书..."
    
    if certbot certonly \
        --standalone \
        --non-interactive \
        --agree-tos \
        --email "${email}" \
        --domains "${domain}" \
        --staple-ocsp \
        --must-staple; then
        
        log_info "✓ SSL 证书申请成功"
        
        # 显示证书信息
        log_info "证书路径:"
        log_info "  - 证书: /etc/letsencrypt/live/${domain}/fullchain.pem"
        log_info "  - 私钥: /etc/letsencrypt/live/${domain}/privkey.pem"
        
        return 0
    else
        log_error "✗ SSL 证书申请失败"
        log_error "可能的原因:"
        log_error "  1. 域名未正确解析到服务器 IP"
        log_error "  2. 端口 80 被占用"
        log_error "  3. 防火墙阻止了访问"
        return 1
    fi
}

#===============================================================================
# 检查证书是否存在
#===============================================================================
check_cert_exists() {
    local domain="$1"
    
    if [[ -f "/etc/letsencrypt/live/${domain}/fullchain.pem" ]] && \
       [[ -f "/etc/letsencrypt/live/${domain}/privkey.pem" ]]; then
        return 0
    fi
    
    return 1
}

#===============================================================================
# 显示证书信息
#===============================================================================
show_cert_info() {
    local domain="$1"
    
    if ! check_cert_exists "$domain"; then
        log_warn "证书不存在: $domain"
        return 1
    fi
    
    log_info "证书信息:"
    openssl x509 -in "/etc/letsencrypt/live/${domain}/fullchain.pem" \
        -noout -subject -issuer -dates 2>/dev/null || true
}

#===============================================================================
# 设置自动续期
#===============================================================================
setup_auto_renew() {
    local domain="${1:-}"
    
    if [[ -n "$domain" ]] && ! check_cert_exists "$domain"; then
        log_warn "证书不存在，跳过续期设置: $domain"
        return 1
    fi
    log_step "配置证书自动续期"
    
    # certbot 会自动创建 systemd timer，检查是否已启用
    if systemctl is-enabled certbot.timer >/dev/null 2>&1; then
        log_info "✓ Certbot 自动续期已启用"
    else
        systemctl enable certbot.timer
        systemctl start certbot.timer
        log_info "✓ 已启用 Certbot 自动续期"
    fi
    
    # 创建续期后的钩子脚本，重载 nginx 和 trojan-go
    local hook_script="/etc/letsencrypt/renewal-hooks/deploy/reload-services.sh"
    mkdir -p "$(dirname "$hook_script")"
    
    cat > "$hook_script" << 'EOF'
#!/bin/bash
# 证书续期后重载服务

systemctl reload nginx 2>/dev/null || true
systemctl restart trojan-go 2>/dev/null || true

logger "SSL 证书已续期，服务已重载"
EOF
    
    chmod +x "$hook_script"
    
    log_info "✓ 续期钩子已配置"
    
    # 显示下次续期时间
    log_info "下次检查续期时间:"
    systemctl status certbot.timer --no-pager | grep "Trigger:" || true
}

#===============================================================================
# 测试续期
#===============================================================================
test_renew() {
    log_step "测试证书续期"
    
    log_info "执行续期测试..."
    certbot renew --dry-run
    
    if [[ $? -eq 0 ]]; then
        log_info "✓ 续期测试成功"
    else
        log_warn "续期测试失败，请检查配置"
    fi
}

#===============================================================================
# 手动续期
#===============================================================================
manual_renew() {
    log_step "手动续期证书"
    
    certbot renew --force-renewal
    
    # 重载服务
    systemctl reload nginx
    systemctl restart trojan-go
    
    log_info "✓ 证书已续期，服务已重载"
}

#===============================================================================
# 撤销证书
#===============================================================================
revoke_cert() {
    local domain="$1"
    
    log_step "撤销证书: ${domain}"
    
    if ! check_cert_exists "$domain"; then
        log_error "证书不存在"
        return 1
    fi
    
    certbot revoke --cert-path "/etc/letsencrypt/live/${domain}/fullchain.pem"
    certbot delete --cert-name "$domain"
    
    log_info "✓ 证书已撤销"
}
