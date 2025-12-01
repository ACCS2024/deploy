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
        # 只备份一次原始文件
        if [[ ! -f "${PHP_INI}.original" ]]; then
            cp "$PHP_INI" "${PHP_INI}.original"
        fi
        
        # 文件上传大小
        sed -i "s/^upload_max_filesize = .*/upload_max_filesize = ${PHP_UPLOAD_MAX}/" "$PHP_INI"
        sed -i "s/^post_max_size = .*/post_max_size = ${PHP_POST_MAX}/" "$PHP_INI"
        
        # 内存限制 (每个进程)
        sed -i "s/^memory_limit = .*/memory_limit = 256M/" "$PHP_INI"
        
        # 执行时间限制
        sed -i "s/^max_execution_time = .*/max_execution_time = 300/" "$PHP_INI"
        sed -i "s/^max_input_time = .*/max_input_time = 300/" "$PHP_INI"
        
        # 性能优化
        sed -i "s/^realpath_cache_size = .*/realpath_cache_size = 4M/" "$PHP_INI"
        sed -i "s/^realpath_cache_ttl = .*/realpath_cache_ttl = 120/" "$PHP_INI"
        
        # OPcache 优化 (幂等性：同时匹配注释和非注释行)
        sed -i "s/^;*opcache.enable=.*/opcache.enable=1/" "$PHP_INI"
        sed -i "s/^;*opcache.memory_consumption=.*/opcache.memory_consumption=256/" "$PHP_INI"
        sed -i "s/^;*opcache.max_accelerated_files=.*/opcache.max_accelerated_files=7963/" "$PHP_INI"
        sed -i "s/^;*opcache.revalidate_freq=.*/opcache.revalidate_freq=0/" "$PHP_INI"
        sed -i "s/^;*opcache.fast_shutdown=.*/opcache.fast_shutdown=1/" "$PHP_INI"
    fi
    
    log_step "配置 PHP-FPM pool"
    POOL_CONF="/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf"
    if [[ -f "$POOL_CONF" ]]; then
        # 只备份一次原始文件
        if [[ ! -f "${POOL_CONF}.original" ]]; then
            cp "$POOL_CONF" "${POOL_CONF}.original"
        fi
        
        # 进程管理 (匹配已存在或注释的行)
        sed -i "s/^;*pm.max_children = .*/pm.max_children = ${PHP_PM_MAX_CHILDREN}/" "$POOL_CONF"
        sed -i "s/^;*pm.start_servers = .*/pm.start_servers = ${PHP_PM_START_SERVERS}/" "$POOL_CONF"
        sed -i "s/^;*pm.min_spare_servers = .*/pm.min_spare_servers = ${PHP_PM_MIN_SPARE}/" "$POOL_CONF"
        sed -i "s/^;*pm.max_spare_servers = .*/pm.max_spare_servers = ${PHP_PM_MAX_SPARE}/" "$POOL_CONF"
        sed -i "s/^;*pm.max_requests = .*/pm.max_requests = ${PHP_PM_MAX_REQUESTS}/" "$POOL_CONF"
        
        # 性能优化
        sed -i "s/^;*pm.process_idle_timeout = .*/pm.process_idle_timeout = 10s/" "$POOL_CONF"
        
        # 监听配置
        sed -i "s/^;*listen.backlog = .*/listen.backlog = 65536/" "$POOL_CONF"
        sed -i "s/^;*listen.owner = .*/listen.owner = www-data/" "$POOL_CONF"
        sed -i "s/^;*listen.group = .*/listen.group = www-data/" "$POOL_CONF"
        sed -i "s/^;*listen.mode = .*/listen.mode = 0660/" "$POOL_CONF"
        
        # 环境变量
        sed -i "s/^;*env\[HOSTNAME\] = .*/env[HOSTNAME] = \$HOSTNAME/" "$POOL_CONF"
        sed -i "s/^;*env\[TMP\] = .*/env[TMP] = \/tmp/" "$POOL_CONF"
        sed -i "s/^;*env\[TMPDIR\] = .*/env[TMPDIR] = \/tmp/" "$POOL_CONF"
        sed -i "s/^;*env\[TEMP\] = .*/env[TEMP] = \/tmp/" "$POOL_CONF"
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
