#!/bin/bash
#===============================================================================
# firewall.sh - 防火墙配置
# 功能: 配置 iptables 规则并持久化
#===============================================================================

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/common.sh"
source "${SCRIPT_DIR}/../../config/versions.conf"

#===============================================================================
# 安装
#===============================================================================
install() {
    log_step "安装 iptables 相关包"
    apt_install iptables ipset iptables-persistent
    
    log_step "配置防火墙规则"
    
    # 开放端口列表
    for port in ${OPEN_PORTS}; do
        # 检查规则是否已存在
        if ! iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null; then
            iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
            log_info "  开放端口: $port"
        fi
    done
    
    log_step "持久化防火墙规则"
    netfilter-persistent save
    
    log_info "firewall 组件安装完成"
}

#===============================================================================
# 检查
#===============================================================================
check() {
    local ok=0
    
    # 检查 iptables 命令
    if check_command_exists iptables; then
        log_info "✓ iptables 已安装"
    else
        log_error "✗ iptables 未安装"
        ok=1
    fi
    
    # 检查各端口规则
    for port in ${OPEN_PORTS}; do
        if iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null; then
            log_info "✓ 端口 $port 规则已配置"
        else
            log_warn "⚠ 端口 $port 规则未配置"
        fi
    done
    
    return $ok
}

#===============================================================================
# 主入口
#===============================================================================
case "${1:-install}" in
    --check) check ;;
    *)       install && check ;;
esac
