#!/bin/bash
#===============================================================================
# fix-nginx-port.sh - 修复 Nginx 端口占用问题
# 用途: 清理孤立的 nginx 进程并重启服务
#===============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "=========================================="
echo "  修复 Nginx 端口占用问题"
echo "=========================================="
echo ""

# 检查端口占用
log_info "检查端口 80 占用情况..."
if lsof -i :80 2>/dev/null || netstat -tlnp 2>/dev/null | grep :80; then
    echo ""
    log_warn "检测到端口 80 被占用"
    
    # 显示占用进程
    log_info "占用端口 80 的进程:"
    lsof -i :80 2>/dev/null || netstat -tlnp | grep :80 || true
    echo ""
    
    # 停止 systemd 管理的 nginx
    log_info "停止 systemd 管理的 nginx 服务..."
    systemctl stop nginx 2>/dev/null || true
    systemctl stop openresty 2>/dev/null || true
    sleep 2
    
    # 强制杀掉所有 nginx 进程
    log_info "强制终止所有 nginx 进程..."
    pkill -9 nginx 2>/dev/null || true
    sleep 2
    
    # 再次检查
    if lsof -i :80 2>/dev/null || netstat -tlnp 2>/dev/null | grep :80; then
        log_error "端口 80 仍被占用，可能是其他程序占用"
        log_info "占用详情:"
        lsof -i :80 2>/dev/null || netstat -tlnp | grep :80 || true
        exit 1
    else
        log_info "✓ 端口 80 已释放"
    fi
else
    log_info "✓ 端口 80 未被占用"
fi

echo ""
log_info "检查端口 443 占用情况..."
if lsof -i :443 2>/dev/null || netstat -tlnp 2>/dev/null | grep :443; then
    log_info "端口 443 占用详情:"
    lsof -i :443 2>/dev/null || netstat -tlnp | grep :443 || true
fi

echo ""
log_info "测试 Nginx 配置..."
if nginx -t 2>&1; then
    log_info "✓ Nginx 配置正确"
else
    log_error "✗ Nginx 配置有错误，请先修复配置"
    exit 1
fi

echo ""
log_info "启动 Nginx 服务..."
if systemctl start nginx; then
    log_info "✓ Nginx 启动成功"
    
    # 等待服务完全启动
    sleep 2
    
    # 检查服务状态
    if systemctl is-active --quiet nginx; then
        log_info "✓ Nginx 运行正常"
        
        # 显示监听端口
        echo ""
        log_info "当前 Nginx 监听端口:"
        netstat -tlnp 2>/dev/null | grep nginx || ss -tlnp | grep nginx || true
    else
        log_error "✗ Nginx 未正常运行"
        systemctl status nginx --no-pager -l
        exit 1
    fi
else
    log_error "✗ Nginx 启动失败"
    systemctl status nginx --no-pager -l
    exit 1
fi

echo ""
log_info "检查 Trojan-Go 服务状态..."
if systemctl is-active --quiet trojan-go 2>/dev/null; then
    log_info "✓ Trojan-Go 运行正常"
else
    log_warn "Trojan-Go 未运行，尝试启动..."
    if systemctl start trojan-go 2>/dev/null; then
        log_info "✓ Trojan-Go 启动成功"
    else
        log_warn "Trojan-Go 启动失败或未安装"
    fi
fi

echo ""
echo "=========================================="
echo "  修复完成"
echo "=========================================="
echo ""
echo "服务状态:"
systemctl status nginx --no-pager | head -n 10
echo ""
echo "监听端口:"
netstat -tlnp 2>/dev/null | grep -E '(:80|:443|:8443)' || ss -tlnp | grep -E '(:80|:443|:8443)' || true
echo ""
