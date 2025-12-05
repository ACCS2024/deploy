#!/bin/bash
#===============================================================================
# env.sh - 环境检查和初始化
#===============================================================================

# 全局配置
export TROJAN_VERSION="v0.10.6"
export TROJAN_INSTALL_DIR="/usr/local/trojan-go"
export TROJAN_CONFIG_FILE="${TROJAN_INSTALL_DIR}/config.json"
export TROJAN_LOG_DIR="/var/log/trojan-go"
export NGINX_VHOST_DIR="/usr/local/openresty/nginx/conf/vhost"
export SSL_DIR="/etc/letsencrypt/live"
export WEBROOT="/var/www"

#===============================================================================
# 检查 root 权限
#===============================================================================
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本必须以 root 权限运行"
        exit 1
    fi
}

#===============================================================================
# 检查系统要求
#===============================================================================
check_system() {
    log_step "检查系统环境"
    
    # 检查操作系统
    if [[ ! -f /etc/debian_version ]]; then
        log_error "此脚本仅支持 Debian 系统"
        exit 1
    fi
    
    local debian_version=$(cat /etc/debian_version | cut -d. -f1)
    if [[ $debian_version -lt 11 ]]; then
        log_error "需要 Debian 11 或更高版本"
        exit 1
    fi
    
    log_info "✓ 系统: Debian $(cat /etc/debian_version)"
    
    # 检查网络连接
    if ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        log_warn "网络连接可能有问题，请检查"
    else
        log_info "✓ 网络连接正常"
    fi
}

#===============================================================================
# 验证域名格式
#===============================================================================
validate_domain() {
    local domain="$1"
    
    # 移除可能的协议前缀和尾部斜杠
    domain=$(echo "$domain" | sed -e 's|^https\?://||' -e 's|/$||' -e 's|^www\.||')
    
    # 验证域名格式
    if [[ ! "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        return 1
    fi
    
    echo "$domain"
    return 0
}

#===============================================================================
# 检查域名 DNS 解析
#===============================================================================
check_domain_dns() {
    local domain="$1"
    
    log_info "检查域名 DNS 解析..."
    
    # 获取本机公网 IP
    local server_ip=$(curl -s -4 ifconfig.me || curl -s -4 icanhazip.com || curl -s -4 ipinfo.io/ip)
    
    if [[ -z "$server_ip" ]]; then
        log_warn "无法获取服务器公网 IP，跳过 DNS 检查"
        return 0
    fi
    
    log_info "服务器 IP: $server_ip"
    
    # 检查域名解析
    local domain_ip=$(dig +short "$domain" A | tail -n1)
    
    if [[ -z "$domain_ip" ]]; then
        log_error "域名 $domain 无法解析"
        log_error "请确保域名已正确解析到: $server_ip"
        return 1
    fi
    
    log_info "域名解析 IP: $domain_ip"
    
    if [[ "$domain_ip" != "$server_ip" ]]; then
        log_warn "域名解析 IP ($domain_ip) 与服务器 IP ($server_ip) 不匹配"
        read -p "是否继续安装? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "安装已取消"
            exit 0
        fi
    else
        log_info "✓ 域名解析正确"
    fi
    
    return 0
}

#===============================================================================
# 安装基础工具
#===============================================================================
install_base_tools() {
    log_step "安装基础工具"
    
    apt-get update -y
    apt_install curl wget unzip tar gzip openssl ca-certificates \
        gnupg2 lsb-release jq dnsutils net-tools
    
    log_info "✓ 基础工具安装完成"
}

#===============================================================================
# 创建必要目录
#===============================================================================
create_directories() {
    log_step "创建必要目录"
    
    mkdir -p "${TROJAN_INSTALL_DIR}"
    mkdir -p "${TROJAN_LOG_DIR}"
    mkdir -p "${NGINX_VHOST_DIR}"
    mkdir -p "${WEBROOT}"
    
    log_info "✓ 目录创建完成"
}

#===============================================================================
# 生成随机密码
#===============================================================================
generate_password() {
    local length="${1:-32}"
    openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c"${length}"
}

#===============================================================================
# 初始化环境
#===============================================================================
init_environment() {
    check_root
    check_system
    install_base_tools
    create_directories
}
