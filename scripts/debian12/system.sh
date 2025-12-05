#!/bin/bash
#===============================================================================
# system.sh - 基础系统配置
# 功能: 时区、DNS、目录创建、apt源配置
#===============================================================================

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/common.sh"
source "${SCRIPT_DIR}/../../config/versions.conf"

#===============================================================================
# 安装
#===============================================================================
install() {
    log_step "配置 DNS"
    if ! grep -q "8.8.8.8" /etc/resolv.conf 2>/dev/null; then
        echo "nameserver 8.8.8.8" > /etc/resolv.conf
        echo "nameserver 8.8.4.4" >> /etc/resolv.conf
    fi
    
    log_step "设置时区"
    timedatectl set-timezone Asia/Shanghai
    
    log_step "创建目录"
    mkdir -p "${DATA_DIR}"
    mkdir -p "${LOG_DIR}"
    mkdir -p "${WWWLOG_DIR}"
    
    log_step "备份并配置 apt 源"
    if [[ ! -f /etc/apt/sources.list.bak ]]; then
        cp /etc/apt/sources.list /etc/apt/sources.list.bak
    fi
    
    cat > /etc/apt/sources.list << 'EOF'
deb http://deb.debian.org/debian/ bookworm main contrib
deb-src http://deb.debian.org/debian/ bookworm main contrib
deb http://deb.debian.org/debian bookworm-updates main contrib
deb-src http://deb.debian.org/debian bookworm-updates main contrib
deb http://deb.debian.org/debian-security/ bookworm-security main contrib
deb-src http://deb.debian.org/debian-security/ bookworm-security main contrib
EOF
    
    log_step "更新 apt 缓存"
    apt-get update -y
    
    log_step "创建 www 用户组"
    groupadd www 2>/dev/null || true
    useradd -g www -s /bin/bash -m www 2>/dev/null || true
    
    log_step "下载探针"
    wget --no-check-certificate -q -O "${DATA_DIR}/proberapi.php" \
        https://github.com/kmvan/x-prober/releases/download/8.17/prober.php || true
    chmod 0444 "${DATA_DIR}/proberapi.php" 2>/dev/null || true
    chown www-data:www-data "${DATA_DIR}/proberapi.php" 2>/dev/null || true
    echo "open_basedir=/home/video/:/tmp/:/proc/" > "${DATA_DIR}/.user.ini"
    
    log_info "system 组件安装完成"
}

#===============================================================================
# 检查
#===============================================================================
check() {
    local ok=0
    
    # 检查时区
    if timedatectl | grep -q "Asia/Shanghai"; then
        log_info "✓ 时区配置正确"
    else
        log_error "✗ 时区配置失败"
        ok=1
    fi
    
    # 检查目录
    for dir in "${DATA_DIR}" "${LOG_DIR}" "${WWWLOG_DIR}"; do
        if [[ -d "$dir" ]]; then
            log_info "✓ 目录存在: $dir"
        else
            log_error "✗ 目录不存在: $dir"
            ok=1
        fi
    done
    
    # 检查 www 用户
    if id www >/dev/null 2>&1; then
        log_info "✓ www 用户存在"
    else
        log_error "✗ www 用户不存在"
        ok=1
    fi
    
    return $ok
}

#===============================================================================
# 主入口
#===============================================================================
# 解析参数
ACTION="install"
while [[ $# -gt 0 ]]; do
    case $1 in
        --mode)
            shift 2
            ;;
        --check)
            ACTION="check"
            shift
            ;;
        install|check)
            ACTION="$1"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# 执行操作
case "${ACTION}" in
    check)
        check
        ;;
    install|*)
        install && check
        ;;
esac
