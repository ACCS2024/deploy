#!/bin/bash
#===============================================================================
# service.sh - 服务管理
#===============================================================================

#===============================================================================
# 清理孤立进程
#===============================================================================
cleanup_processes() {
    log_info "清理孤立的进程..."
    
    # 清理 nginx
    pkill -9 nginx 2>/dev/null || true
    
    # 清理 trojan-go
    pkill -9 trojan-go 2>/dev/null || true
    
    sleep 2
    log_info "✓ 进程清理完成"
}

#===============================================================================
# 启动服务
#===============================================================================
start_services() {
    log_step "启动服务"
    
    # 清理孤立进程
    cleanup_processes
    
    # 启动 Nginx
    log_info "启动 Nginx..."
    
    # 检查 systemd 服务文件是否存在
    if [[ ! -f /lib/systemd/system/nginx.service ]]; then
        log_error "Nginx service 文件不存在"
        return 1
    fi
    
    systemctl enable nginx
    systemctl start nginx
    
    sleep 2
    
    if systemctl is-active --quiet nginx; then
        log_info "✓ Nginx 已启动"
    else
        log_error "✗ Nginx 启动失败"
        systemctl status nginx --no-pager -l
        
        # 检查端口占用
        log_info "检查端口占用:"
        lsof -i :80 2>/dev/null || netstat -tlnp | grep :80 || true
        lsof -i :443 2>/dev/null || netstat -tlnp | grep :443 || true
        
        return 1
    fi
    
    # 启动 Trojan-Go
    log_info "启动 Trojan-Go..."
    systemctl enable trojan-go
    systemctl start trojan-go
    
    sleep 2
    
    if systemctl is-active --quiet trojan-go; then
        log_info "✓ Trojan-Go 已启动"
    else
        log_error "✗ Trojan-Go 启动失败"
        systemctl status trojan-go --no-pager -l
        
        # 查看日志
        log_info "Trojan-Go 日志:"
        tail -n 20 "${TROJAN_LOG_DIR}/trojan-go.log" 2>/dev/null || true
        
        return 1
    fi
    
    log_info "✓ 所有服务已启动并设置为开机自启"
}

#===============================================================================
# 停止服务
#===============================================================================
stop_services() {
    log_step "停止服务"
    
    systemctl stop trojan-go 2>/dev/null || true
    systemctl stop nginx 2>/dev/null || true
    
    cleanup_processes
    
    log_info "✓ 服务已停止"
}

#===============================================================================
# 重启服务
#===============================================================================
restart_services() {
    log_step "重启服务"
    
    systemctl restart nginx
    systemctl restart trojan-go
    
    sleep 2
    
    if systemctl is-active --quiet nginx && systemctl is-active --quiet trojan-go; then
        log_info "✓ 服务重启成功"
    else
        log_error "服务重启失败"
        show_status
        return 1
    fi
}

#===============================================================================
# 重载配置
#===============================================================================
reload_services() {
    log_step "重载配置"
    
    # 测试配置
    nginx -t || return 1
    
    # 重载服务
    systemctl reload nginx
    systemctl restart trojan-go
    
    log_info "✓ 配置已重载"
}

#===============================================================================
# 显示服务状态
#===============================================================================
show_status() {
    echo ""
    echo "=========================================="
    echo "  服务状态"
    echo "=========================================="
    echo ""
    
    echo "--- Nginx ---"
    systemctl status nginx --no-pager | head -n 15
    echo ""
    
    echo "--- Trojan-Go ---"
    systemctl status trojan-go --no-pager | head -n 15
    echo ""
    
    echo "--- 端口监听 ---"
    netstat -tlnp 2>/dev/null | grep -E '(:80|:443|:8443)' || \
        ss -tlnp | grep -E '(:80|:443|:8443)' || true
    echo ""
}

#===============================================================================
# 检查服务健康状态
#===============================================================================
health_check() {
    log_step "服务健康检查"
    
    local all_ok=true
    
    # 检查 Nginx
    if systemctl is-active --quiet nginx; then
        log_info "✓ Nginx 运行正常"
    else
        log_error "✗ Nginx 未运行"
        all_ok=false
    fi
    
    # 检查 Trojan-Go
    if systemctl is-active --quiet trojan-go; then
        log_info "✓ Trojan-Go 运行正常"
    else
        log_error "✗ Trojan-Go 未运行"
        all_ok=false
    fi
    
    # 检查端口
    if lsof -i :443 >/dev/null 2>&1 || netstat -tln | grep -q :443; then
        log_info "✓ 端口 443 正在监听"
    else
        log_error "✗ 端口 443 未监听"
        all_ok=false
    fi
    
    if $all_ok; then
        log_info "✓ 所有服务健康"
        return 0
    else
        log_error "部分服务异常"
        return 1
    fi
}

#===============================================================================
# 卸载服务
#===============================================================================
uninstall_services() {
    log_step "卸载 Trojan-Go"
    
    # 停止服务
    systemctl stop trojan-go 2>/dev/null || true
    systemctl disable trojan-go 2>/dev/null || true
    
    # 删除服务文件
    rm -f /lib/systemd/system/trojan-go.service
    systemctl daemon-reload
    
    # 删除程序文件
    rm -rf "${TROJAN_INSTALL_DIR}"
    rm -rf "${TROJAN_LOG_DIR}"
    
    log_info "✓ Trojan-Go 已卸载"
    log_warn "Nginx 和 SSL 证书已保留，如需删除请手动操作"
}
