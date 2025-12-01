#!/bin/bash
#===============================================================================
# packages.sh - 基础软件包安装
# 功能: 安装系统依赖包、开发工具、运行时环境
#===============================================================================

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/common.sh"
source "${SCRIPT_DIR}/../../config/versions.conf"

#===============================================================================
# 安装
#===============================================================================
install() {
    log_step "更新系统"
    apt-get update -y
    apt-get upgrade -y
    apt-get dist-upgrade -y
    
    log_step "安装基础工具"
    apt_install \
        locales-all \
        rsync \
        git \
        zip \
        curl \
        wget \
        iotop \
        aria2
    
    log_step "安装编译依赖"
    apt_install \
        build-essential \
        pkg-config \
        perl \
        make \
        flex \
        libpcre3-dev \
        zlib1g-dev \
        libssl-dev \
        libcurl4-openssl-dev \
        libxml2-dev \
        libxslt1-dev \
        libonig-dev \
        libfreetype6-dev \
        libpng-dev \
        libjpeg-dev \
        libgd-dev \
        libgeoip-dev \
        libsqlite3-dev \
        sqlite3 \
        openssl
    
    log_step "安装 .NET 运行时"
    if [[ ! -f /etc/apt/sources.list.d/microsoft-prod.list ]]; then
        wget -q https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb \
            -O /tmp/packages-microsoft-prod.deb
        dpkg -i /tmp/packages-microsoft-prod.deb || true
        rm -f /tmp/packages-microsoft-prod.deb
        apt-get update -y
    fi
    apt_install aspnetcore-runtime-8.0 aspnetcore-runtime-7.0 || true
    
    log_step "安装中文字体"
    apt_install \
        gnupg \
        fonts-arphic-bkai00mp \
        fonts-arphic-bsmi00lp \
        fonts-arphic-gbsn00lp \
        fonts-arphic-gkai00mp \
        fonts-arphic-ukai \
        fonts-arphic-uming || true
    
    log_step "配置 git"
    git config --global url.https://github.com/.insteadOf git://github.com/
    
    log_info "packages 组件安装完成"
}

#===============================================================================
# 检查
#===============================================================================
check() {
    local ok=0
    
    for cmd in git curl wget rsync make gcc; do
        if check_command_exists "$cmd"; then
            log_info "✓ $cmd 已安装"
        else
            log_error "✗ $cmd 未安装"
            ok=1
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
