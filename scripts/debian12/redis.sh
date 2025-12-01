#!/bin/bash
#===============================================================================
# redis.sh - Redis 安装配置
# 功能: 安装 Redis 服务器并启用服务
#===============================================================================

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/common.sh"
source "${SCRIPT_DIR}/../../config/versions.conf"

#===============================================================================
# 安装
#===============================================================================
install() {
    log_step "安装 Redis"
    apt_install redis-server redis-tools
    
    log_step "启动 Redis 服务"
    systemctl enable redis-server
    systemctl start redis-server
    
    log_info "redis 组件安装完成"
}

#===============================================================================
# 检查
#===============================================================================
check() {
    local ok=0
    
    # 检查命令
    if check_command_exists redis-cli; then
        log_info "✓ Redis CLI 已安装"
    else
        log_error "✗ Redis CLI 未安装"
        ok=1
    fi
    
    # 检查服务
    if check_service_running redis-server; then
        log_info "✓ Redis 服务运行中"
    else
        log_error "✗ Redis 服务未运行"
        ok=1
    fi
    
    # PING 测试
    if redis-cli ping 2>/dev/null | grep -q PONG; then
        log_info "✓ Redis PING 成功"
    else
        log_error "✗ Redis PING 失败"
        ok=1
    fi
    
    # 检查端口
    if check_port_listening 6379; then
        log_info "✓ Redis 端口 6379 已监听"
    else
        log_error "✗ Redis 端口 6379 未监听"
        ok=1
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
