#!/bin/bash
#===============================================================================
# trojan.sh - Trojan-Go 安装和配置
#===============================================================================

#===============================================================================
# 安装 Trojan-Go
#===============================================================================
install_trojan() {
    log_step "安装 Trojan-Go ${TROJAN_VERSION}"
    
    if [[ -f "${TROJAN_INSTALL_DIR}/trojan-go" ]]; then
        log_info "Trojan-Go 已安装"
        return 0
    fi
    
    log_info "下载 Trojan-Go"
    cd /tmp
    rm -rf trojan-go-linux-amd64.zip trojan-go-tmp 2>/dev/null
    
    wget -q "https://github.com/p4gefau1t/trojan-go/releases/download/${TROJAN_VERSION}/trojan-go-linux-amd64.zip"
    
    log_info "解压并安装"
    unzip -q trojan-go-linux-amd64.zip -d trojan-go-tmp
    cp trojan-go-tmp/trojan-go "${TROJAN_INSTALL_DIR}/"
    chmod +x "${TROJAN_INSTALL_DIR}/trojan-go"
    
    # 复制 GeoIP 数据库
    if [[ -f trojan-go-tmp/geoip.dat ]]; then
        cp trojan-go-tmp/geoip.dat "${TROJAN_INSTALL_DIR}/"
    fi
    if [[ -f trojan-go-tmp/geosite.dat ]]; then
        cp trojan-go-tmp/geosite.dat "${TROJAN_INSTALL_DIR}/"
    fi
    
    rm -rf trojan-go-tmp trojan-go-linux-amd64.zip
    
    log_info "✓ Trojan-Go 安装完成"
}

#===============================================================================
# 创建 Trojan-Go 配置
#===============================================================================
create_trojan_config() {
    local domain="$1"
    local password="$2"
    local ws_path="$3"
    
    log_step "创建 Trojan-Go 配置"
    
    cat > "${TROJAN_CONFIG_FILE}" << EOF
{
    "run_type": "server",
    "local_addr": "127.0.0.1",
    "local_port": 8443,
    "remote_addr": "127.0.0.1",
    "remote_port": 80,
    "password": [
        "${password}"
    ],
    "log_level": 1,
    "log_file": "${TROJAN_LOG_DIR}/trojan-go.log",
    "ssl": {
        "cert": "/etc/letsencrypt/live/${domain}/fullchain.pem",
        "key": "/etc/letsencrypt/live/${domain}/privkey.pem",
        "sni": "${domain}",
        "alpn": [
            "http/1.1"
        ],
        "session_ticket": true,
        "reuse_session": true,
        "plain_http_response": "",
        "fallback_addr": "127.0.0.1",
        "fallback_port": 80,
        "fingerprint": "firefox"
    },
    "tcp": {
        "prefer_ipv4": true,
        "no_delay": true,
        "keep_alive": true,
        "fast_open": true,
        "fast_open_qlen": 20
    },
    "websocket": {
        "enabled": true,
        "path": "${ws_path}",
        "host": "${domain}"
    }
}
EOF

    log_info "✓ Trojan-Go 配置已创建: ${TROJAN_CONFIG_FILE}"
}

#===============================================================================
# 创建 Trojan-Go systemd 服务
#===============================================================================
create_trojan_service() {
    if [[ -f /lib/systemd/system/trojan-go.service ]]; then
        log_info "Trojan-Go service 已存在"
        return 0
    fi
    
    log_step "创建 Trojan-Go systemd 服务"
    
    cat > /lib/systemd/system/trojan-go.service << EOF
[Unit]
Description=Trojan-Go Proxy Server
Documentation=https://p4gefau1t.github.io/trojan-go/
After=network.target network-online.target nss-lookup.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=${TROJAN_INSTALL_DIR}
ExecStart=${TROJAN_INSTALL_DIR}/trojan-go -config ${TROJAN_CONFIG_FILE}
Restart=on-failure
RestartSec=5s
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    log_info "✓ Trojan-Go service 已创建"
}

#===============================================================================
# 测试 Trojan-Go 配置
#===============================================================================
test_trojan_config() {
    log_info "测试 Trojan-Go 配置..."
    
    if "${TROJAN_INSTALL_DIR}/trojan-go" -test -config "${TROJAN_CONFIG_FILE}" 2>&1; then
        log_info "✓ Trojan-Go 配置正确"
        return 0
    else
        log_error "✗ Trojan-Go 配置错误"
        return 1
    fi
}
