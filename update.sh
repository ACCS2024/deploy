#!/bin/bash
#===============================================================================
# update.sh - 一键更新部署脚本
# 功能: 备份配置、更新代码、重新赋予权限
#===============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 日志函数
log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

#===============================================================================
# 备份脚本配置（只备份可能被覆盖的 conf/ 目录）
#===============================================================================
backup_configs() {
    # 只备份 conf/ 目录，因为其他配置文件都在系统目录不会被覆盖
    if [[ -d conf/ ]]; then
        BACKUP_DIR="./backup-conf-$(date +%Y%m%d-%H%M%S)"
        cp -r conf/ "$BACKUP_DIR" 2>/dev/null || true
        if [[ -d "$BACKUP_DIR" ]]; then
            log_info "✓ conf/ 配置已备份到: $BACKUP_DIR"
        fi
    fi
}

#===============================================================================
# 更新代码
#===============================================================================
update_code() {
    log_info "检查 git 状态..."
    
    # 检查是否有未提交的修改
    if ! git diff --quiet || ! git diff --staged --quiet; then
        log_warn "检测到本地有未提交的修改"
        read -p "是否要强制更新（会丢失本地修改）? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "更新已取消"
            exit 0
        fi
        
        log_warn "强制重置到远程版本..."
        git reset --hard HEAD
        git clean -fd
    fi
    
    log_info "拉取最新代码..."
    git pull origin master
    
    log_info "✓ 代码更新完成"
}

#===============================================================================
# 重新赋予权限
#===============================================================================
set_permissions() {
    log_info "设置执行权限..."
    
    chmod +x install.sh
    chmod +x scripts/debian12/*.sh 2>/dev/null || true
    chmod +x update.sh
    
    log_info "✓ 权限设置完成"
}

#===============================================================================
# 显示更新信息
#===============================================================================
show_update_info() {
    echo ""
    echo "=========================================="
    echo "         更新完成"
    echo "=========================================="
    
    # 显示最新提交信息
    echo "最新更新:"
    git log --oneline -5
    
    echo ""
    echo "常用命令:"
    echo "  查看所有组件: ./install.sh --help"
    echo "  安装 Trojan-Go: ./install.sh --trojan-go"
    echo "  再次更新: ./update.sh"
    echo "=========================================="
}

#===============================================================================
# 主流程
#===============================================================================
main() {
    log_info "开始更新部署脚本..."
    
    # 检查是否在正确的目录
    if [[ ! -f install.sh ]] || [[ ! -d scripts/debian12 ]]; then
        log_error "请在 deploy 目录下运行此脚本"
        exit 1
    fi
    
    # 检查 git 状态
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "这不是一个 git 仓库"
        exit 1
    fi
    
    # 备份可能被覆盖的配置文件
    backup_configs
    
    # 更新代码
    update_code
    
    # 设置权限
    set_permissions
    
    # 显示信息
    show_update_info
    
    log_info "更新完成！"
    log_info "注意: Trojan-Go 和 MySQL 等配置文件在系统目录，不会被更新覆盖"
}

#===============================================================================
# 参数处理
#===============================================================================
case "${1:-}" in
    --help|-h)
        echo "用法: $0"
        echo ""
        echo "一键更新部署脚本，包括："
        echo "  - 备份 conf/ 配置目录（如有修改）"
        echo "  - 拉取最新代码"
        echo "  - 设置执行权限"
        echo ""
        echo "注意："
        echo "  - Trojan-Go 配置在 /usr/local/trojan-go/ 不会被覆盖"
        echo "  - MySQL 密码在 /home/video/uboy.cbo 不会被覆盖"
        echo "  - 如果有本地修改，会询问是否强制更新"
        exit 0
        ;;
    *)
        main
        ;;
esac