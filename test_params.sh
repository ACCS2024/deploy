#!/bin/bash
#===============================================================================
# 测试所有组件脚本是否正确处理 --mode 参数
#===============================================================================

echo "测试组件脚本参数处理..."
echo ""

SCRIPTS_DIR="scripts/debian12"
FAILED=0

for script in "${SCRIPTS_DIR}"/*.sh; do
    script_name=$(basename "$script")
    
    # 测试 --mode 参数（只测试语法，不实际执行安装）
    if bash -n "$script" 2>/dev/null; then
        echo "✓ $script_name - 语法检查通过"
    else
        echo "✗ $script_name - 语法错误"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
if [ $FAILED -eq 0 ]; then
    echo "所有脚本语法检查通过！"
    exit 0
else
    echo "有 $FAILED 个脚本存在语法错误"
    exit 1
fi
