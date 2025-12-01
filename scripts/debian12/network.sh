#!/bin/bash
#===============================================================================
# network.sh - 网络优化配置
# 功能: BBR 启用、sysctl 内核参数优化
#===============================================================================

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/common.sh"
source "${SCRIPT_DIR}/../../config/versions.conf"

#===============================================================================
# 安装
#===============================================================================
install() {
    log_step "检查 BBR 状态"
    if sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q bbr; then
        log_info "BBR 已启用，跳过"
    else
        log_step "启用 BBR"
        echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    fi
    
    log_step "配置 sysctl 内核参数"
    
    declare -a params=(
        "net.core.default_qdisc=fq"
        "net.ipv4.tcp_congestion_control=bbr"
        "fs.file-max=1000000"
        "fs.inotify.max_user_instances=8192"
        "net.ipv4.tcp_syncookies=1"
        "net.ipv4.tcp_fin_timeout=30"
        "net.ipv4.tcp_tw_reuse=1"
        "net.ipv4.ip_local_port_range=1024 65000"
        "net.ipv4.tcp_max_syn_backlog=16384"
        "net.ipv4.tcp_max_tw_buckets=6000"
        "net.ipv4.route.gc_timeout=100"
        "net.ipv4.tcp_syn_retries=1"
        "net.ipv4.tcp_synack_retries=1"
        "net.core.somaxconn=32768"
        "net.core.netdev_max_backlog=32768"
        "net.ipv4.tcp_timestamps=0"
        "net.ipv4.tcp_max_orphans=32768"
    )
    
    for param in "${params[@]}"; do
        key="${param%%=*}"
        if ! grep -q "^${key}" /etc/sysctl.conf 2>/dev/null; then
            echo "$param" >> /etc/sysctl.conf
        fi
    done
    
    log_step "应用 sysctl 配置"
    sysctl -p >/dev/null 2>&1 || true
    
    log_info "network 组件安装完成"
}

#===============================================================================
# 检查
#===============================================================================
check() {
    local ok=0
    
    # 检查 BBR
    if sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q bbr; then
        log_info "✓ BBR 已启用"
    else
        log_error "✗ BBR 未启用"
        ok=1
    fi
    
    # 检查 file-max
    current=$(sysctl -n fs.file-max 2>/dev/null)
    if [[ "$current" -ge 1000000 ]]; then
        log_info "✓ fs.file-max = $current"
    else
        log_warn "⚠ fs.file-max = $current (建议 >= 1000000)"
    fi
    
    return $ok
}

#===============================================================================
# 主入口
#===============================================================================
case "${1:-install}" in
    --check) check ;;
    *)       install && check ;;
esac
