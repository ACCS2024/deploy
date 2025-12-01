#!/bin/bash
#===============================================================================
# openresty.sh - OpenResty 安装
# 功能: 编译安装 OpenResty、配置 systemd 服务
#===============================================================================

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/common.sh"
source "${SCRIPT_DIR}/../../config/versions.conf"

MODE="${2:-fast}"

#===============================================================================
# 编译安装
#===============================================================================
install_compile() {
    log_step "下载 OpenResty ${OPENRESTY_VERSION}"
    cd /root
    rm -rf "openresty-${OPENRESTY_VERSION}" 2>/dev/null || true
    wget -q "https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz"
    tar -zxf "openresty-${OPENRESTY_VERSION}.tar.gz"
    
    log_step "下载 nginx-module-vts"
    rm -rf /root/nginx-module-vts 2>/dev/null || true
    git clone --depth 1 https://github.com/vozlt/nginx-module-vts.git /root/nginx-module-vts
    
    log_step "编译 OpenResty"
    cd "/root/openresty-${OPENRESTY_VERSION}"
    ./configure -j$(nproc) \
        --prefix="${OPENRESTY_PREFIX}" \
        --with-http_v2_module \
        --with-http_geoip_module \
        --add-module=/root/nginx-module-vts \
        --with-http_image_filter_module
    
    make -j$(nproc)
    make install
    
    log_step "下载 GeoIP 数据库"
    mkdir -p /usr/share/GeoIP
    wget -q https://dl.miyuru.lk/geoip/dbip/country/dbip4.dat.gz -O /usr/share/GeoIP/dbip4.dat.gz || true
    wget -q https://dl.miyuru.lk/geoip/dbip/country/dbip.dat.gz -O /usr/share/GeoIP/dbip.dat.gz || true
    wget -q https://dl.miyuru.lk/geoip/dbip/country/dbip6.dat.gz -O /usr/share/GeoIP/dbip6.dat.gz || true
    cd /usr/share/GeoIP
    gzip -d -f dbip*.dat.gz 2>/dev/null || true
    
    log_step "配置环境变量"
    if ! grep -q "openresty" ~/.bashrc; then
        echo "export PATH=${OPENRESTY_PREFIX}/nginx/sbin:\$PATH" >> ~/.bashrc
    fi
}

#===============================================================================
# 快速安装（预编译包）
#===============================================================================
install_fast() {
    log_step "添加 OpenResty 官方源"
    apt_install gnupg2 ca-certificates lsb-release
    
    wget -qO - https://openresty.org/package/pubkey.gpg | apt-key add - || true
    echo "deb http://openresty.org/package/debian $(lsb_release -sc) openresty" \
        > /etc/apt/sources.list.d/openresty.list
    
    apt-get update -y
    apt_install openresty || {
        log_warn "官方源安装失败，回退到编译安装"
        install_compile
    }
}

#===============================================================================
# 配置 systemd 服务
#===============================================================================
setup_service() {
    log_step "创建 systemd 服务"
    cat > /etc/systemd/system/openresty.service << 'EOF'
[Unit]
Description=The OpenResty Application Platform
After=syslog.target network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target

[Service]
StartLimitIntervalSec=0
Restart=always
RestartSec=1
Type=forking
PIDFile=/usr/local/openresty/nginx/logs/nginx.pid
ExecStartPre=/usr/local/openresty/nginx/sbin/nginx -t -q -g 'daemon on; master_process on;'
ExecStart=/usr/local/openresty/nginx/sbin/nginx -g 'daemon on; master_process on;'
ExecReload=/usr/local/openresty/nginx/sbin/nginx -g 'daemon on; master_process on;' -s reload
ExecStop=-/sbin/start-stop-daemon --quiet --stop --retry QUIT/5 --pidfile /usr/local/openresty/nginx/logs/nginx.pid
TimeoutStopSec=5
KillMode=mixed
LimitNOFILE=1048576
LimitNPROC=65535
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF
    
    log_step "启用 OpenResty 服务"
    systemctl daemon-reload
    systemctl enable openresty
    
    # 清空日志
    mkdir -p "${OPENRESTY_PREFIX}/nginx/logs"
    echo '' > "${OPENRESTY_PREFIX}/nginx/logs/error.log" 2>/dev/null || true
    echo '' > "${OPENRESTY_PREFIX}/nginx/logs/access.log" 2>/dev/null || true
}

#===============================================================================
# 安装
#===============================================================================
install() {
    if [[ "$MODE" == "compile" ]]; then
        install_compile
    else
        install_fast
    fi
    
    setup_service
    
    log_info "openresty 组件安装完成 (模式: ${MODE})"
}

#===============================================================================
# 检查
#===============================================================================
check() {
    local ok=0
    
    NGINX_BIN="${OPENRESTY_PREFIX}/nginx/sbin/nginx"
    
    # 检查二进制
    if [[ -x "$NGINX_BIN" ]]; then
        VERSION=$("$NGINX_BIN" -v 2>&1 | head -1)
        log_info "✓ OpenResty 已安装: $VERSION"
    else
        log_error "✗ OpenResty 未安装"
        ok=1
    fi
    
    # 检查服务
    if check_service_running openresty; then
        log_info "✓ OpenResty 服务运行中"
    else
        log_warn "⚠ OpenResty 服务未运行（可能需要配置后启动）"
    fi
    
    return $ok
}

#===============================================================================
# 主入口
#===============================================================================
case "${1:-install}" in
    --check) check ;;
    --mode)  shift; MODE="$1"; install && check ;;
    *)       install && check ;;
esac
