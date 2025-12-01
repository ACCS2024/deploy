#!/bin/bash
#===============================================================================
# 公共函数库
#===============================================================================

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 静默模式环境变量
export DEBIAN_FRONTEND=noninteractive

#===============================================================================
# 日志函数
#===============================================================================
log_info()  { echo -e "${GREEN}[INFO]${NC} $(date '+%H:%M:%S') $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $(date '+%H:%M:%S') $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $(date '+%H:%M:%S') $1"; }
log_step()  { echo -e "${GREEN}[STEP]${NC} $(date '+%H:%M:%S') >>> $1"; }

#===============================================================================
# 命令执行（带重试）
#===============================================================================
run_cmd() {
    local cmd="$1"
    local max_retry="${2:-1}"
    local retry=0
    
    while [[ $retry -lt $max_retry ]]; do
        if eval "$cmd"; then
            return 0
        fi
        retry=$((retry + 1))
        if [[ $retry -lt $max_retry ]]; then
            log_warn "命令失败，${retry}/${max_retry} 次重试..."
            sleep 2
        fi
    done
    
    log_error "命令执行失败: $cmd"
    return 1
}

#===============================================================================
# apt 安装（静默）
#===============================================================================
apt_install() {
    apt-get install -y --no-install-recommends "$@"
}

#===============================================================================
# 服务管理
#===============================================================================
service_enable() {
    systemctl enable "$1" 2>/dev/null || true
}

service_start() {
    systemctl start "$1" 2>/dev/null || true
}

service_restart() {
    systemctl restart "$1" 2>/dev/null || true
}

service_is_active() {
    systemctl is-active --quiet "$1"
}

#===============================================================================
# 检查函数
#===============================================================================
check_command_exists() {
    command -v "$1" >/dev/null 2>&1
}

check_file_exists() {
    [[ -f "$1" ]]
}

check_service_running() {
    systemctl is-active --quiet "$1"
}

check_port_listening() {
    ss -ltn | grep -q ":$1 "
}
