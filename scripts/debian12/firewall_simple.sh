#!/bin/bash
#===============================================================================
# firewall_simple.sh - 简单防火墙管理（iptables）
# 用途：全局防火墙配置，供各组件使用
#===============================================================================

#===============================================================================
# 安装 iptables 并禁用 ufw
#===============================================================================
setup_firewall() {
    log_step "配置防火墙"
    
    # 安装 iptables 和持久化工具
    log_info "安装 iptables-persistent"
    apt_install iptables iptables-persistent
    
    # 尝试停止并禁用 ufw（如果存在）
    if systemctl list-unit-files | grep -q ufw.service; then
        log_info "检测到 ufw，正在禁用..."
        systemctl stop ufw 2>/dev/null || true
        systemctl disable ufw 2>/dev/null || true
        ufw disable 2>/dev/null || true
        log_info "✓ ufw 已禁用"
    fi
    
    log_info "✓ 防火墙工具安装完成"
}

#===============================================================================
# 开放端口
#===============================================================================
open_port() {
    local port="$1"
    local protocol="${2:-tcp}"
    local comment="${3:-}"
    
    # 参数验证
    if [[ -z "$port" ]]; then
        log_error "端口参数不能为空"
        return 1
    fi
    
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        log_error "端口必须是数字: $port"
        return 1
    fi
    
    log_info "开放端口: $port/$protocol ${comment:+($comment)}"
    
    # 检查规则是否已存在
    if iptables -C INPUT -p "$protocol" --dport "$port" -j ACCEPT 2>/dev/null; then
        log_info "端口 $port/$protocol 规则已存在"
        return 0
    fi
    
    # 添加 iptables 规则
    iptables -A INPUT -p "$protocol" --dport "$port" -j ACCEPT
    
    log_info "✓ 端口 $port/$protocol 已开放"
}

#===============================================================================
# 保存 iptables 规则（持久化）
#===============================================================================
save_firewall_rules() {
    log_info "保存防火墙规则..."
    
    # Debian/Ubuntu 使用 iptables-persistent
    if command -v netfilter-persistent >/dev/null 2>&1; then
        netfilter-persistent save
        log_info "✓ 防火墙规则已保存 (netfilter-persistent)"
    elif command -v iptables-save >/dev/null 2>&1; then
        # 手动保存到配置文件
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || \
        iptables-save > /etc/iptables.rules 2>/dev/null || true
        log_info "✓ 防火墙规则已保存 (iptables-save)"
    fi
}

#===============================================================================
# 配置基础防火墙规则
#===============================================================================
setup_basic_firewall_rules() {
    log_step "配置基础防火墙规则"
    
    # 允许本地回环
    if ! iptables -C INPUT -i lo -j ACCEPT 2>/dev/null; then
        iptables -A INPUT -i lo -j ACCEPT
        log_info "✓ 允许 loopback 接口"
    fi
    
    # 允许已建立的连接
    if ! iptables -C INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null; then
        iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
        log_info "✓ 允许已建立的连接"
    fi
    
    # 允许 SSH（防止锁死）
    open_port 22 tcp "SSH"
    
    log_info "✓ 基础规则配置完成"
}

#===============================================================================
# 开放 Web 端口（80, 443）
#===============================================================================
open_web_ports() {
    log_step "开放 Web 端口"
    
    open_port 80 tcp "HTTP"
    open_port 443 tcp "HTTPS"
    
    # 保存规则
    save_firewall_rules
    
    log_info "✓ Web 端口已开放并持久化"
}

#===============================================================================
# 查看防火墙规则
#===============================================================================
show_firewall_rules() {
    log_info "当前防火墙规则:"
    echo "=================================================="
    iptables -L INPUT -n -v --line-numbers
    echo "=================================================="
}

#===============================================================================
# 完整配置（用于新系统初始化）
#===============================================================================
setup_firewall_full() {
    setup_firewall
    setup_basic_firewall_rules
    open_web_ports
    show_firewall_rules
}

#===============================================================================
# 快速开放端口并持久化（便捷函数）
#===============================================================================
quick_open_port() {
    local port="$1"
    local protocol="${2:-tcp}"
    local comment="${3:-}"
    
    open_port "$port" "$protocol" "$comment"
    save_firewall_rules
}
