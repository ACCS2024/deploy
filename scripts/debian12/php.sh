#!/bin/bash
#===============================================================================
# php.sh - PHP-FPM 安装配置
# 功能: 安装 PHP-FPM、配置 php.ini 和 pool
#===============================================================================

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/common.sh"
source "${SCRIPT_DIR}/../../config/versions.conf"

#===============================================================================
# 安装
#===============================================================================
install() {
    log_step "安装 PHP-FPM"
    apt_install php-fpm php-redis
    
    # 获取 PHP 版本
    PHP_VERSION=$(php -v | head -n 1 | cut -d " " -f 2 | cut -d "." -f 1,2)
    log_info "检测到 PHP 版本: ${PHP_VERSION}"
    
    log_step "配置 php.ini"
    PHP_INI="/etc/php/${PHP_VERSION}/fpm/php.ini"
    if [[ -f "$PHP_INI" ]]; then
        sed -i.bak "s/^upload_max_filesize = .*/upload_max_filesize = ${PHP_UPLOAD_MAX}/" "$PHP_INI"
        sed -i.bak "s/^post_max_size = .*/post_max_size = ${PHP_POST_MAX}/" "$PHP_INI"
    fi
    
    log_step "配置 PHP-FPM pool"
    POOL_CONF="/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf"
    if [[ -f "$POOL_CONF" ]]; then
        sed -i.bak "s/pm.max_children = [0-9]*/pm.max_children = ${PHP_PM_MAX_CHILDREN}/" "$POOL_CONF"
        sed -i.bak "s/pm.start_servers = [0-9]*/pm.start_servers = ${PHP_PM_START_SERVERS}/" "$POOL_CONF"
        sed -i.bak "s/pm.min_spare_servers = [0-9]*/pm.min_spare_servers = ${PHP_PM_MIN_SPARE}/" "$POOL_CONF"
        sed -i.bak "s/pm.max_spare_servers = [0-9]*/pm.max_spare_servers = ${PHP_PM_MAX_SPARE}/" "$POOL_CONF"
        sed -i.bak "s/pm.max_requests = [0-9]*/pm.max_requests = ${PHP_PM_MAX_REQUESTS}/" "$POOL_CONF"
    fi
    
    log_step "启动 PHP-FPM"
    systemctl enable "php${PHP_VERSION}-fpm"
    systemctl restart "php${PHP_VERSION}-fpm"
    
    log_info "php 组件安装完成"
}

#===============================================================================
# 检查
#===============================================================================
check() {
    local ok=0
    
    # 检查 PHP 命令
    if check_command_exists php; then
        PHP_VERSION=$(php -v | head -n 1 | cut -d " " -f 2 | cut -d "." -f 1,2)
        log_info "✓ PHP ${PHP_VERSION} 已安装"
    else
        log_error "✗ PHP 未安装"
        ok=1
    fi
    
    # 检查 PHP-FPM 服务
    if check_service_running "php${PHP_VERSION}-fpm"; then
        log_info "✓ PHP-FPM 服务运行中"
    else
        log_error "✗ PHP-FPM 服务未运行"
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
