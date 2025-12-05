#!/bin/bash
#===============================================================================
# main.sh - Trojan-Go + Nginx + Let's Encrypt 自动部署主脚本
# 功能: 一键部署、自动申请SSL证书、自动续期
#===============================================================================

set -e

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载公共库
source "${SCRIPT_DIR}/../../lib/common.sh"
source "${SCRIPT_DIR}/../../config/versions.conf"

# 加载模块
source "${SCRIPT_DIR}/lib/env.sh"
source "${SCRIPT_DIR}/../ssl.sh"  # SSL 模块提升到上层，供多个组件复用
source "${SCRIPT_DIR}/../firewall_simple.sh"  # 防火墙模块
source "${SCRIPT_DIR}/lib/nginx.sh"
source "${SCRIPT_DIR}/lib/trojan.sh"
source "${SCRIPT_DIR}/lib/service.sh"

#===============================================================================
# 交互式配置
#===============================================================================
interactive_setup() {
    echo ""
    echo "=========================================="
    echo "  Trojan-Go 自动部署向导"
    echo "=========================================="
    echo ""
    
    # 输入域名
    while true; do
        read -p "请输入域名 (例如: example.com): " DOMAIN
        
        # 验证域名格式
        DOMAIN=$(validate_domain "$DOMAIN")
        if [[ $? -eq 0 ]] && [[ -n "$DOMAIN" ]]; then
            echo -e "${GREEN}✓ 域名: ${DOMAIN}${NC}"
            break
        else
            echo -e "${RED}✗ 域名格式不正确，请重新输入${NC}"
        fi
    done
    
    # 输入邮箱（用于 Let's Encrypt）
    read -p "请输入邮箱 (用于 SSL 证书通知，留空使用默认): " EMAIL
    if [[ -z "$EMAIL" ]]; then
        EMAIL="admin@${DOMAIN}"
    fi
    echo -e "${GREEN}✓ 邮箱: ${EMAIL}${NC}"
    
    # 生成随机密码
    TROJAN_PASSWORD=$(generate_password 32)
    echo ""
    echo -e "${GREEN}已生成 Trojan-Go 密码:${NC}"
    echo -e "${YELLOW}${TROJAN_PASSWORD}${NC}"
    echo -e "${RED}请务必保存此密码！${NC}"
    echo ""
    
    # 生成 WebSocket 路径
    WS_PATH="/ws$(generate_password 8)"
    echo -e "${GREEN}WebSocket 路径: ${WS_PATH}${NC}"
    echo ""
    
    # 确认继续
    read -p "确认以上信息并继续安装? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "安装已取消"
        exit 0
    fi
}

#===============================================================================
# 保存安装信息
#===============================================================================
save_install_info() {
    log_step "保存安装信息"
    
    cat > "${TROJAN_INSTALL_DIR}/install_info.txt" << EOF
========================================
Trojan-Go 安装信息
========================================
安装时间: $(date '+%Y-%m-%d %H:%M:%S')
域名: ${DOMAIN}
邮箱: ${EMAIL}
Trojan-Go 密码: ${TROJAN_PASSWORD}
WebSocket 路径: ${WS_PATH}
服务端口: 443 (HTTPS)

配置文件:
  - Trojan: ${TROJAN_CONFIG_FILE}
  - Nginx: ${NGINX_VHOST_DIR}/${DOMAIN}.conf

SSL 证书:
  - 证书: /etc/letsencrypt/live/${DOMAIN}/fullchain.pem
  - 私钥: /etc/letsencrypt/live/${DOMAIN}/privkey.pem
  - 自动续期: 已启用 (certbot.timer)

日志文件:
  - Trojan: ${TROJAN_LOG_DIR}/trojan-go.log
  - Nginx: /var/log/nginx/${DOMAIN}.access.log

常用命令:
  systemctl status trojan-go    # 查看状态
  systemctl restart trojan-go   # 重启服务
  certbot renew --dry-run       # 测试证书续期
  tail -f ${TROJAN_LOG_DIR}/trojan-go.log  # 查看日志
========================================
EOF

    chmod 600 "${TROJAN_INSTALL_DIR}/install_info.txt"
    log_info "✓ 安装信息已保存: ${TROJAN_INSTALL_DIR}/install_info.txt"
}

#===============================================================================
# 显示安装完成信息
#===============================================================================
show_complete_info() {
    echo ""
    echo "=========================================="
    echo "  🎉 安装完成"
    echo "=========================================="
    echo ""
    
    cat "${TROJAN_INSTALL_DIR}/install_info.txt"
    
    echo ""
    echo "=========================================="
    echo "  客户端配置"
    echo "=========================================="
    echo "服务器地址: ${DOMAIN}"
    echo "端口: 443"
    echo "密码: ${TROJAN_PASSWORD}"
    echo "传输协议: WebSocket"
    echo "WebSocket 路径: ${WS_PATH}"
    echo "TLS: 启用"
    echo "SNI: ${DOMAIN}"
    echo "=========================================="
    echo ""
}

#===============================================================================
# 主安装流程
#===============================================================================
install() {
    log_info "开始 Trojan-Go 自动部署"
    echo ""
    
    # 1. 环境初始化
    init_environment
    
    # 2. 交互式配置
    interactive_setup
    
    # 3. 检查域名 DNS
    check_domain_dns "$DOMAIN" || {
        log_warn "DNS 检查未通过，但可以继续安装"
    }
    
    # 4. 配置防火墙
    setup_firewall
    setup_basic_firewall_rules
    open_web_ports
    
    # 5. 安装 certbot
    install_certbot
    
    # 6. 申请 SSL 证书
    request_ssl_cert "$DOMAIN" "$EMAIL" || {
        log_error "SSL 证书申请失败，无法继续"
        exit 1
    }
    
    # 7. 设置自动续期
    setup_auto_renew
    
    # 8. 安装 Nginx
    install_nginx
    
    # 9. 创建 Nginx 虚拟主机
    create_nginx_vhost "$DOMAIN" "$WS_PATH" || {
        log_error "Nginx 虚拟主机创建失败"
        exit 1
    }
    
    # 10. 安装 Trojan-Go
    install_trojan || {
        log_error "Trojan-Go 安装失败"
        exit 1
    }
    
    # 11. 创建 Trojan-Go 配置
    create_trojan_config "$DOMAIN" "$TROJAN_PASSWORD" "$WS_PATH" || {
        log_error "Trojan-Go 配置创建失败"
        exit 1
    }
    
    # 12. 创建服务
    create_trojan_service
    
    # 13. 启动服务
    start_services || {
        log_error "服务启动失败"
        show_status
        exit 1
    }
    
    # 14. 保存安装信息
    save_install_info
    
    # 15. 健康检查
    sleep 3
    health_check
    
    # 16. 显示完成信息
    show_complete_info
    
    log_info "🎉 部署完成！"
}

#===============================================================================
# 命令行参数处理
#===============================================================================
ACTION="install"

while [[ $# -gt 0 ]]; do
    case $1 in
        --mode)
            shift 2  # 兼容主安装脚本
            ;;
        install)
            ACTION="install"
            shift
            ;;
        uninstall)
            ACTION="uninstall"
            shift
            ;;
        restart)
            ACTION="restart"
            shift
            ;;
        reload)
            ACTION="reload"
            shift
            ;;
        status)
            ACTION="status"
            shift
            ;;
        renew)
            ACTION="renew"
            shift
            ;;
        test-renew)
            ACTION="test-renew"
            shift
            ;;
        health)
            ACTION="health"
            shift
            ;;
        --help|-h)
            cat << EOF
用法: $0 [命令]

命令:
  install       安装 Trojan-Go + Nginx + SSL (默认)
  uninstall     卸载 Trojan-Go
  restart       重启服务
  reload        重载配置
  status        查看服务状态
  renew         手动续期 SSL 证书
  test-renew    测试 SSL 证书续期
  health        健康检查
  
示例:
  $0 install          # 全新安装
  $0 status           # 查看状态
  $0 test-renew       # 测试证书续期
EOF
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

# 执行命令
case "${ACTION}" in
    install)
        install
        ;;
    uninstall)
        uninstall_services
        ;;
    restart)
        restart_services
        show_status
        ;;
    reload)
        reload_services
        show_status
        ;;
    status)
        show_status
        ;;
    renew)
        manual_renew
        ;;
    test-renew)
        test_renew
        ;;
    health)
        health_check
        show_status
        ;;
    *)
        log_error "未知命令: ${ACTION}"
        log_info "使用 --help 查看帮助"
        exit 1
        ;;
esac
