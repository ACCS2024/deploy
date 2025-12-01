#!/bin/bash
#===============================================================================
# mysql.sh - MySQL 安装
# 功能: 安装 MySQL 8.0、自动生成 root 密码
#===============================================================================

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/common.sh"
source "${SCRIPT_DIR}/../../config/versions.conf"

PASSWORD_FILE="${DATA_DIR}/uboy.cbo"

#===============================================================================
# 安装
#===============================================================================
install() {
    # 检查是否已安装
    if check_command_exists mysql; then
        log_info "MySQL 已安装，跳过"
        return 0
    fi
    
    log_step "下载 MySQL APT 配置"
    wget -q "https://repo.mysql.com/mysql-apt-config_${MYSQL_APT_CONFIG_VERSION}_all.deb" \
        -O /tmp/mysql-apt-config.deb
    
    log_step "生成随机密码"
    MYSQL_ROOT_PASSWORD=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24)
    echo "$MYSQL_ROOT_PASSWORD" > "$PASSWORD_FILE"
    chmod 600 "$PASSWORD_FILE"
    
    log_step "配置 debconf"
    debconf-set-selections <<EOF
mysql-apt-config mysql-apt-config/select-server select mysql-8.0
mysql-community-server mysql-community-server/root-pass password ${MYSQL_ROOT_PASSWORD}
mysql-community-server mysql-community-server/re-root-pass password ${MYSQL_ROOT_PASSWORD}
mysql-community-server mysql-server/default-auth-override select Use Legacy Authentication Method (Retain MySQL 5.x Compatibility)
EOF
    
    log_step "安装 MySQL APT 配置包"
    dpkg -i /tmp/mysql-apt-config.deb || true
    
    log_step "更新 apt 并安装 MySQL"
    apt-get update -y
    apt_install mysql-server
    
    log_step "启动 MySQL 服务"
    systemctl enable mysql
    systemctl start mysql
    
    rm -f /tmp/mysql-apt-config.deb
    
    log_info "mysql 组件安装完成"
    log_info "MySQL root 密码已保存到: ${PASSWORD_FILE}"
}

#===============================================================================
# 检查
#===============================================================================
check() {
    local ok=0
    
    # 检查命令
    if check_command_exists mysql; then
        VERSION=$(mysql --version 2>/dev/null | head -1)
        log_info "✓ MySQL 已安装: $VERSION"
    else
        log_error "✗ MySQL 未安装"
        ok=1
    fi
    
    # 检查服务
    if check_service_running mysql; then
        log_info "✓ MySQL 服务运行中"
    else
        log_error "✗ MySQL 服务未运行"
        ok=1
    fi
    
    # 检查密码文件
    if check_file_exists "$PASSWORD_FILE"; then
        log_info "✓ 密码文件存在: ${PASSWORD_FILE}"
    else
        log_warn "⚠ 密码文件不存在"
    fi
    
    # 检查端口
    if check_port_listening 3306; then
        log_info "✓ MySQL 端口 3306 已监听"
    else
        log_error "✗ MySQL 端口 3306 未监听"
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
