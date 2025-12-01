#!/bin/bash
#===============================================================================
# fail2ban.sh - Fail2ban 安装配置
# 功能: 安装 fail2ban 并配置白名单
#===============================================================================

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/common.sh"
source "${SCRIPT_DIR}/../../config/versions.conf"

#===============================================================================
# 安装
#===============================================================================
install() {
    log_step "安装 fail2ban"
    apt_install fail2ban
    
    log_step "配置 fail2ban 白名单"
    JAIL_CONF="/etc/fail2ban/jail.conf"
    if [[ -f "$JAIL_CONF" ]]; then
        # 备份并替换 ignoreip 配置
        if [[ ! -f "${JAIL_CONF}.bak" ]]; then
            cp "$JAIL_CONF" "${JAIL_CONF}.bak"
        fi
        sed -i "s/#ignoreip = 127.0.0.1\/8 ::1/ignoreip = ${FAIL2BAN_WHITELIST}/" "$JAIL_CONF"
    fi
    
    log_step "启动 fail2ban 服务"
    systemctl enable fail2ban
    systemctl restart fail2ban
    
    log_info "fail2ban 组件安装完成"
}

#===============================================================================
# 检查
#===============================================================================
check() {
    local ok=0
    
    # 检查命令
    if check_command_exists fail2ban-client; then
        log_info "✓ fail2ban 已安装"
    else
        log_error "✗ fail2ban 未安装"
        ok=1
    fi
    
    # 检查服务
    if check_service_running fail2ban; then
        log_info "✓ fail2ban 服务运行中"
    else
        log_error "✗ fail2ban 服务未运行"
        ok=1
    fi
    
    # 检查状态
    if fail2ban-client status >/dev/null 2>&1; then
        JAILS=$(fail2ban-client status 2>/dev/null | grep "Jail list" || echo "无")
        log_info "✓ fail2ban 状态正常"
    else
        log_warn "⚠ 无法获取 fail2ban 状态"
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
