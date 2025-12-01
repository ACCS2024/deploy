#!/bin/bash
#===============================================================================
# 配置文件清理脚本
# 删除无用的默认文件、备份文件和重复配置
#===============================================================================

CONF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "开始清理配置目录: $CONF_DIR"

# 根目录清理
echo "清理根目录..."
rm -f "$CONF_DIR"/*.default
rm -f "$CONF_DIR"/*_bk
rm -f "$CONF_DIR"/*.bak
rm -f "$CONF_DIR"/local.conf_
rm -f "$CONF_DIR"/koi-utf
rm -f "$CONF_DIR"/koi-win
rm -f "$CONF_DIR"/win-utf
rm -f "$CONF_DIR"/fstab

# rewrite 目录清理
echo "清理 rewrite 目录..."
rm -f "$CONF_DIR"/rewrite/bfzyfire.conf
rm -f "$CONF_DIR"/rewrite/bfzyfire1.conf
rm -f "$CONF_DIR"/rewrite/geo_back.conf
rm -f "$CONF_DIR"/rewrite/maccms-fire.lua

echo "清理完成！"
echo ""
echo "已删除文件类型："
echo "  - *.default (官方默认文件)"
echo "  - *_bk (备份文件)"
echo "  - *.bak (临时备份)"
echo "  - 重复/未使用的配置文件"
echo ""
echo "保留的有效配置请查看 CLEANUP.md"
