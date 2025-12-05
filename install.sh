#!/bin/bash
#===============================================================================
# 自动静默部署系统 - 统一入口
# 用法: ./install.sh --mysql --redis --php --openresty [--mode fast|compile]
#===============================================================================

set -o pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="/var/log/deploy"
LOG_FILE="${LOG_DIR}/deploy-$(date +%Y%m%d-%H%M%S).log"

# 默认值
MODE="fast"
PARALLEL=0
COMPONENTS=()
FAILED_COMPONENTS=()
SUCCESS_COMPONENTS=()

#===============================================================================
# 日志函数
#===============================================================================
log_info()  { echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }

#===============================================================================
# 帮助信息
#===============================================================================
show_help() {
    cat << EOF
用法: $0 [选项] [组件...]

组件选项:
  --system       基础系统配置（时区、DNS、目录）
  --network      网络优化（BBR、sysctl）
  --packages     基础软件包安装
  --php          PHP-FPM 安装配置
  --openresty    OpenResty 安装
  --mysql        MySQL 安装
  --redis        Redis 安装
  --fail2ban     Fail2ban 安装
  --firewall     防火墙配置
  --trojan-go    Trojan-Go + Nginx 代理部署（交互式）
  --all          安装所有组件

其他选项:
  --mode         部署模式: fast（快速）或 compile（编译）默认: fast
  --parallel     并行安装组件
  --help         显示此帮助

示例:
  $0 --mysql --redis
  $0 --trojan-go
  $0 --all --mode compile
  $0 --openresty --php --mode fast
EOF
    exit 0
}

#===============================================================================
# 预检函数
#===============================================================================
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "请使用 root 用户执行此脚本"
        exit 3
    fi
    log_info "✓ root 权限检查通过"
}

check_system() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "无法检测系统版本"
        exit 3
    fi
    
    source /etc/os-release
    
    OS_ID="${ID}"
    OS_VERSION="${VERSION_ID}"
    OS_CODENAME="${VERSION_CODENAME:-unknown}"
    
    log_info "检测到系统: ${PRETTY_NAME}"
    
    # 确定脚本目录
    case "${OS_ID}" in
        debian)
            case "${OS_VERSION}" in
                12*)
                    SCRIPTS_DIR="${SCRIPT_DIR}/scripts/debian12"
                    ;;
                11*)
                    SCRIPTS_DIR="${SCRIPT_DIR}/scripts/debian11"
                    ;;
                *)
                    log_error "不支持的 Debian 版本: ${OS_VERSION}"
                    exit 3
                    ;;
            esac
            ;;
        ubuntu)
            case "${OS_VERSION}" in
                22.04*)
                    SCRIPTS_DIR="${SCRIPT_DIR}/scripts/ubuntu2204"
                    ;;
                20.04*)
                    SCRIPTS_DIR="${SCRIPT_DIR}/scripts/ubuntu2004"
                    ;;
                *)
                    log_error "不支持的 Ubuntu 版本: ${OS_VERSION}"
                    exit 3
                    ;;
            esac
            ;;
        *)
            log_error "不支持的操作系统: ${OS_ID}"
            exit 3
            ;;
    esac
    
    if [[ ! -d "${SCRIPTS_DIR}" ]]; then
        log_error "未找到对应系统的脚本目录: ${SCRIPTS_DIR}"
        exit 3
    fi
    
    log_info "✓ 系统版本检查通过，使用脚本目录: ${SCRIPTS_DIR}"
}

#===============================================================================
# 参数解析
#===============================================================================
parse_args() {
    if [[ $# -eq 0 ]]; then
        show_help
    fi
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --system)    COMPONENTS+=("system"); shift ;;
            --network)   COMPONENTS+=("network"); shift ;;
            --packages)  COMPONENTS+=("packages"); shift ;;
            --php)       COMPONENTS+=("php"); shift ;;
            --openresty) COMPONENTS+=("openresty"); shift ;;
            --mysql)     COMPONENTS+=("mysql"); shift ;;
            --redis)     COMPONENTS+=("redis"); shift ;;
            --fail2ban)  COMPONENTS+=("fail2ban"); shift ;;
            --firewall)  COMPONENTS+=("firewall"); shift ;;
            --trojan-go) COMPONENTS+=("trojan-go"); shift ;;
            --all)
                COMPONENTS=("system" "network" "packages" "php" "openresty" "mysql" "redis" "fail2ban" "firewall")
                shift
                ;;
            --mode)
                MODE="$2"
                if [[ "$MODE" != "fast" && "$MODE" != "compile" ]]; then
                    log_error "无效的模式: $MODE (应为 fast 或 compile)"
                    exit 2
                fi
                shift 2
                ;;
            --parallel)  PARALLEL=1; shift ;;
            --help|-h)   show_help ;;
            *)
                log_error "未知参数: $1"
                exit 2
                ;;
        esac
    done
    
    if [[ ${#COMPONENTS[@]} -eq 0 ]]; then
        log_error "未指定任何组件"
        exit 2
    fi
    
    log_info "部署模式: ${MODE}"
    log_info "待安装组件: ${COMPONENTS[*]}"
}

#===============================================================================
# 组件执行
#===============================================================================
run_component() {
    local component=$1
    local script="${SCRIPTS_DIR}/${component}.sh"
    local component_log="${LOG_DIR}/components/${component}.log"
    
    mkdir -p "${LOG_DIR}/components"
    
    if [[ ! -f "$script" ]]; then
        log_warn "组件脚本不存在: ${script}"
        FAILED_COMPONENTS+=("$component")
        return 1
    fi
    
    log_info ">>> 开始安装组件: ${component}"
    echo "[详细日志保存至: ${component_log}]"
    echo ""
    
    # 执行组件脚本，同时显示日志和保存到文件
    if bash "$script" --mode "$MODE" 2>&1 | tee "$component_log"; then
        echo ""
        log_info "✓ 组件 ${component} 安装成功"
        SUCCESS_COMPONENTS+=("$component")
        return 0
    else
        echo ""
        log_error "✗ 组件 ${component} 安装失败，详见: ${component_log}"
        FAILED_COMPONENTS+=("$component")
        return 1
    fi
}

run_all_components() {
    for component in "${COMPONENTS[@]}"; do
        run_component "$component"
        # 单个组件失败不影响其他组件
    done
}

#===============================================================================
# 报告生成
#===============================================================================
generate_report() {
    echo ""
    echo "=============================================="
    echo "           部署完成报告"
    echo "=============================================="
    echo "部署模式: ${MODE}"
    echo "日志文件: ${LOG_FILE}"
    echo ""
    
    if [[ ${#SUCCESS_COMPONENTS[@]} -gt 0 ]]; then
        echo -e "${GREEN}成功组件 (${#SUCCESS_COMPONENTS[@]}):${NC}"
        for c in "${SUCCESS_COMPONENTS[@]}"; do
            echo "  ✓ $c"
        done
    fi
    
    if [[ ${#FAILED_COMPONENTS[@]} -gt 0 ]]; then
        echo ""
        echo -e "${RED}失败组件 (${#FAILED_COMPONENTS[@]}):${NC}"
        for c in "${FAILED_COMPONENTS[@]}"; do
            echo "  ✗ $c"
        done
    fi
    
    echo ""
    echo "=============================================="
    
    # 退出码
    if [[ ${#FAILED_COMPONENTS[@]} -gt 0 ]]; then
        return 4
    fi
    return 0
}

#===============================================================================
# 主流程
#===============================================================================
main() {
    # 创建日志目录
    mkdir -p "$LOG_DIR"
    
    log_info "========== 部署开始 $(date) =========="
    
    # 预检
    check_root
    check_system
    
    # 解析参数
    parse_args "$@"
    
    # 执行组件安装
    run_all_components
    
    # 生成报告
    generate_report
    exit_code=$?
    
    log_info "========== 部署结束 $(date) =========="
    
    exit $exit_code
}

main "$@"
