#!/bin/bash
#===============================================================================
# 自检脚本 - 验证安装后的系统状态
#===============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_ok=0

echo "=========================================="
echo "      系统部署状态自检"
echo "=========================================="
echo ""

# 检查服务状态
check_service() {
    local name=$1
    if systemctl is-active --quiet "$name"; then
        echo -e "${GREEN}✓${NC} $name 运行中"
    else
        echo -e "${RED}✗${NC} $name 未运行"
        check_ok=1
    fi
}

# 检查端口
check_port() {
    local port=$1
    if ss -ltn | grep -q ":$port "; then
        echo -e "${GREEN}✓${NC} 端口 $port 已监听"
    else
        echo -e "${YELLOW}⚠${NC} 端口 $port 未监听"
    fi
}

# 检查命令
check_command() {
    local cmd=$1
    if command -v "$cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $cmd 已安装"
    else
        echo -e "${RED}✗${NC} $cmd 未安装"
        check_ok=1
    fi
}

echo "=== 服务状态 ==="
check_service "php-fpm" || check_service "php8.2-fpm" || check_service "php8.1-fpm"
check_service "mysql"
check_service "redis-server"
check_service "openresty"
check_service "fail2ban"
echo ""

echo "=== 端口监听 ==="
check_port 80
check_port 443
check_port 3306
check_port 6379
echo ""

echo "=== 命令可用性 ==="
check_command "php"
check_command "mysql"
check_command "redis-cli"
check_command "git"
check_command "nginx" || check_command "/usr/local/openresty/nginx/sbin/nginx"
echo ""

echo "=== 系统优化 ==="
bbr=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep bbr)
if [[ -n "$bbr" ]]; then
    echo -e "${GREEN}✓${NC} BBR 已启用"
else
    echo -e "${RED}✗${NC} BBR 未启用"
    check_ok=1
fi

timezone=$(timedatectl | grep "Asia/Shanghai")
if [[ -n "$timezone" ]]; then
    echo -e "${GREEN}✓${NC} 时区: Asia/Shanghai"
else
    echo -e "${YELLOW}⚠${NC} 时区未设置为 Asia/Shanghai"
fi
echo ""

echo "=== 密码文件 ==="
if [[ -f /home/video/uboy.cbo ]]; then
    echo -e "${GREEN}✓${NC} MySQL 密码: /home/video/uboy.cbo"
    echo "    密码: $(cat /home/video/uboy.cbo 2>/dev/null || echo '读取失败')"
else
    echo -e "${YELLOW}⚠${NC} MySQL 密码文件不存在"
fi
echo ""

echo "=== OpenResty 配置 ==="
if [[ -f /usr/local/openresty/nginx/conf/nginx.conf ]]; then
    echo -e "${GREEN}✓${NC} 配置文件已部署"
    backup_count=$(ls -1d /usr/local/openresty/nginx/backup/conf-* 2>/dev/null | wc -l)
    echo "    配置备份数: $backup_count"
else
    echo -e "${YELLOW}⚠${NC} 配置文件不存在"
fi
echo ""

echo "=========================================="
if [[ $check_ok -eq 0 ]]; then
    echo -e "${GREEN}自检完成：系统状态正常${NC}"
    exit 0
else
    echo -e "${RED}自检完成：发现问题，请检查日志${NC}"
    exit 1
fi
