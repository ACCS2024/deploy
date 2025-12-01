#!/bin/bash
#===============================================================================
# PHP 配置幂等性测试脚本
# 验证多次运行是否产生相同结果
#===============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "  PHP-FPM 配置幂等性测试"
echo "=========================================="
echo ""

# 创建测试文件
TEST_DIR="/tmp/php-test-$$"
mkdir -p "$TEST_DIR"

# 模拟 php.ini
cat > "$TEST_DIR/php.ini" << 'EOF'
upload_max_filesize = 2M
post_max_size = 8M
memory_limit = 128M
max_execution_time = 30
max_input_time = 60
realpath_cache_size = 16K
realpath_cache_ttl = 120
;opcache.enable=1
;opcache.memory_consumption=128
;opcache.max_accelerated_files=10000
;opcache.revalidate_freq=2
;opcache.fast_shutdown=0
EOF

# 模拟 pool.conf
cat > "$TEST_DIR/www.conf" << 'EOF'
[www]
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
;pm.process_idle_timeout = 10s
;pm.max_requests = 500
listen = /run/php/php8.2-fpm.sock
;listen.backlog = 511
;listen.owner = www-data
;listen.group = www-data
;listen.mode = 0660
;env[HOSTNAME] = $HOSTNAME
;env[TMP] = /tmp
;env[TMPDIR] = /tmp
;env[TEMP] = /tmp
EOF

echo "创建测试文件完成"
echo ""

# 模拟配置脚本
apply_config() {
    local iter=$1
    echo "=== 第 $iter 次应用配置 ==="
    
    # php.ini
    sed -i "s/^upload_max_filesize = .*/upload_max_filesize = 100M/" "$TEST_DIR/php.ini"
    sed -i "s/^post_max_size = .*/post_max_size = 100M/" "$TEST_DIR/php.ini"
    sed -i "s/^memory_limit = .*/memory_limit = 256M/" "$TEST_DIR/php.ini"
    sed -i "s/^max_execution_time = .*/max_execution_time = 300/" "$TEST_DIR/php.ini"
    sed -i "s/^max_input_time = .*/max_input_time = 300/" "$TEST_DIR/php.ini"
    sed -i "s/^realpath_cache_size = .*/realpath_cache_size = 4M/" "$TEST_DIR/php.ini"
    sed -i "s/^realpath_cache_ttl = .*/realpath_cache_ttl = 120/" "$TEST_DIR/php.ini"
    
    # OPcache (使用 ;* 匹配注释和非注释)
    sed -i "s/^;*opcache.enable=.*/opcache.enable=1/" "$TEST_DIR/php.ini"
    sed -i "s/^;*opcache.memory_consumption=.*/opcache.memory_consumption=256/" "$TEST_DIR/php.ini"
    sed -i "s/^;*opcache.max_accelerated_files=.*/opcache.max_accelerated_files=7963/" "$TEST_DIR/php.ini"
    sed -i "s/^;*opcache.revalidate_freq=.*/opcache.revalidate_freq=0/" "$TEST_DIR/php.ini"
    sed -i "s/^;*opcache.fast_shutdown=.*/opcache.fast_shutdown=1/" "$TEST_DIR/php.ini"
    
    # pool.conf
    sed -i "s/^;*pm.max_children = .*/pm.max_children = 112/" "$TEST_DIR/www.conf"
    sed -i "s/^;*pm.start_servers = .*/pm.start_servers = 28/" "$TEST_DIR/www.conf"
    sed -i "s/^;*pm.min_spare_servers = .*/pm.min_spare_servers = 14/" "$TEST_DIR/www.conf"
    sed -i "s/^;*pm.max_spare_servers = .*/pm.max_spare_servers = 56/" "$TEST_DIR/www.conf"
    sed -i "s/^;*pm.max_requests = .*/pm.max_requests = 4096/" "$TEST_DIR/www.conf"
    sed -i "s/^;*pm.process_idle_timeout = .*/pm.process_idle_timeout = 10s/" "$TEST_DIR/www.conf"
    sed -i "s/^;*listen.backlog = .*/listen.backlog = 65536/" "$TEST_DIR/www.conf"
    sed -i "s/^;*listen.owner = .*/listen.owner = www-data/" "$TEST_DIR/www.conf"
    sed -i "s/^;*listen.group = .*/listen.group = www-data/" "$TEST_DIR/www.conf"
    sed -i "s/^;*listen.mode = .*/listen.mode = 0660/" "$TEST_DIR/www.conf"
    sed -i "s/^;*env\[HOSTNAME\] = .*/env[HOSTNAME] = \$HOSTNAME/" "$TEST_DIR/www.conf"
    sed -i "s/^;*env\[TMP\] = .*/env[TMP] = \/tmp/" "$TEST_DIR/www.conf"
    sed -i "s/^;*env\[TMPDIR\] = .*/env[TMPDIR] = \/tmp/" "$TEST_DIR/www.conf"
    sed -i "s/^;*env\[TEMP\] = .*/env[TEMP] = \/tmp/" "$TEST_DIR/www.conf"
}

# 第一次应用
apply_config 1
cp "$TEST_DIR/php.ini" "$TEST_DIR/php.ini.run1"
cp "$TEST_DIR/www.conf" "$TEST_DIR/www.conf.run1"

# 第二次应用
apply_config 2
cp "$TEST_DIR/php.ini" "$TEST_DIR/php.ini.run2"
cp "$TEST_DIR/www.conf" "$TEST_DIR/www.conf.run2"

# 第三次应用
apply_config 3
cp "$TEST_DIR/php.ini" "$TEST_DIR/php.ini.run3"
cp "$TEST_DIR/www.conf" "$TEST_DIR/www.conf.run3"

echo ""
echo "=== 验证结果 ==="

# 对比文件
all_pass=1

if diff -q "$TEST_DIR/php.ini.run1" "$TEST_DIR/php.ini.run2" >/dev/null && \
   diff -q "$TEST_DIR/php.ini.run2" "$TEST_DIR/php.ini.run3" >/dev/null; then
    echo -e "${GREEN}✓${NC} php.ini 幂等性测试通过（三次运行结果一致）"
else
    echo -e "${RED}✗${NC} php.ini 幂等性测试失败（三次运行结果不一致）"
    all_pass=0
    echo "差异详情:"
    diff -u "$TEST_DIR/php.ini.run1" "$TEST_DIR/php.ini.run2" || true
fi

if diff -q "$TEST_DIR/www.conf.run1" "$TEST_DIR/www.conf.run2" >/dev/null && \
   diff -q "$TEST_DIR/www.conf.run2" "$TEST_DIR/www.conf.run3" >/dev/null; then
    echo -e "${GREEN}✓${NC} www.conf 幂等性测试通过（三次运行结果一致）"
else
    echo -e "${RED}✗${NC} www.conf 幂等性测试失败（三次运行结果不一致）"
    all_pass=0
    echo "差异详情:"
    diff -u "$TEST_DIR/www.conf.run1" "$TEST_DIR/www.conf.run2" || true
fi

echo ""
echo "=== 关键配置验证 ==="

# 验证 opcache 配置
if grep -q "^opcache.enable=1$" "$TEST_DIR/php.ini.run3"; then
    echo -e "${GREEN}✓${NC} opcache.enable 已正确启用（无前导分号）"
else
    echo -e "${RED}✗${NC} opcache.enable 配置错误"
    all_pass=0
fi

# 验证 pm 配置
if grep -q "^pm.max_children = 112$" "$TEST_DIR/www.conf.run3"; then
    echo -e "${GREEN}✓${NC} pm.max_children 已正确配置（无前导分号）"
else
    echo -e "${RED}✗${NC} pm.max_children 配置错误"
    all_pass=0
fi

# 验证环境变量
if grep -q "^env\[TMP\] = /tmp$" "$TEST_DIR/www.conf.run3"; then
    echo -e "${GREEN}✓${NC} env[TMP] 已正确配置（无前导分号）"
else
    echo -e "${RED}✗${NC} env[TMP] 配置错误"
    all_pass=0
fi

echo ""
echo "测试文件保存在: $TEST_DIR"
echo "可手动检查: cat $TEST_DIR/php.ini.run3"
echo ""

if [[ $all_pass -eq 1 ]]; then
    echo -e "${GREEN}=========================================="
    echo "  所有幂等性测试通过 ✓"
    echo "==========================================${NC}"
    exit 0
else
    echo -e "${RED}=========================================="
    echo "  部分测试失败 ✗"
    echo "==========================================${NC}"
    exit 1
fi
