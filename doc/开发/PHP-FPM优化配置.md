# PHP-FPM 性能优化配置

## 系统规格
- **CPU**: Intel Xeon E5-2680 v4 (14 cores, 28 threads)
- **内存**: 128GB DDR4
- **硬盘**: 10TB SSD/HDD
- **网络**: 10Gbps

## 配置优化说明

### 1. 进程数量计算

#### 内存基础计算
```
总内存: 128GB = 131,072MB
系统预留: 32GB (24%)
可用内存: 96GB = 98,304MB

假设每个 PHP 进程平均占用: 64MB (保守估计)
理论最大进程数: 98,304MB / 64MB = 1,536

实际考虑 CPU 核心数限制: 14 cores × 8 = 112
最终设置: pm.max_children = 112
```

#### CPU 核心数优化
```
启动进程数: pm.start_servers = 14 × 2 = 28
最小空闲进程: pm.min_spare_servers = 14
最大空闲进程: pm.max_spare_servers = 14 × 4 = 56
```

### 2. 关键配置参数

#### php.ini 优化
```ini
; 文件上传
upload_max_filesize = 100M
post_max_size = 100M

; 内存限制 (每个进程)
memory_limit = 256M

; 执行时间
max_execution_time = 300
max_input_time = 300

; 路径缓存
realpath_cache_size = 4M
realpath_cache_ttl = 120

; OPcache 优化
opcache.enable=1
opcache.memory_consumption=256
opcache.max_accelerated_files=7963
opcache.revalidate_freq=0
opcache.fast_shutdown=1
```

#### PHP-FPM Pool 优化
```ini
; 进程管理 (动态模式)
pm = dynamic
pm.max_children = 112
pm.start_servers = 28
pm.min_spare_servers = 14
pm.max_spare_servers = 56
pm.max_requests = 4096

; 性能优化
pm.process_idle_timeout = 10s

; 监听配置
listen.backlog = 65536
listen.owner = www-data
listen.group = www-data
listen.mode = 0660

; 环境变量
env[HOSTNAME] = $HOSTNAME
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] = /tmp
```

### 3. 性能监控

#### 监控命令
```bash
# 查看 PHP-FPM 状态
systemctl status php8.2-fpm

# 查看进程数量
ps aux | grep php-fpm | wc -l

# 查看内存使用
ps aux --no-headers -o "rss,cmd" -C php-fpm | awk '{ sum+=$1 } END { printf ("%d%s\n", sum/NR/1024,"M") }'

# 查看连接状态
netstat -an | grep :9000 | wc -l
```

#### 监控指标
- **活跃进程数**: 应在 min_spare_servers ~ max_spare_servers 之间
- **内存使用率**: 单个进程不应超过 256MB
- **响应时间**: 通过 Nginx access_log 监控
- **错误率**: 查看 PHP-FPM error_log

### 4. 调优建议

#### 高负载场景
如果遇到高并发，考虑：
1. 增加 `pm.max_children` (最大不超过 200)
2. 启用 `pm = static` 模式
3. 增加 `listen.backlog`

#### 内存不足场景
如果内存紧张：
1. 降低 `pm.max_children`
2. 减少 `memory_limit`
3. 启用 `pm.process_idle_timeout`

#### CPU 密集场景
1. 增加 `pm.max_requests` (减少进程重启)
2. 优化 OPcache 配置
3. 考虑使用更多 worker 进程

### 5. 安全考虑

#### 资源限制
- `pm.max_requests = 4096`: 防止内存泄漏
- `memory_limit = 256M`: 防止单个进程占用过多内存
- `max_execution_time = 300`: 防止长时间运行脚本

#### 权限控制
- `listen.owner/group = www-data`: 正确权限
- `listen.mode = 0660`: 安全访问权限

### 6. 扩展配置

#### 多 Pool 配置
如果需要隔离不同应用：
```bash
# 创建新 pool
cp /etc/php/8.2/fpm/pool.d/www.conf /etc/php/8.2/fpm/pool.d/app1.conf

# 修改配置
sed -i 's/\[www\]/[app1]/' /etc/php/8.2/fpm/pool.d/app1.conf
sed -i 's/listen = .*/listen = /run/php/php8.2-fpm-app1.sock/' /etc/php/8.2/fpm/pool.d/app1.conf

# 重启服务
systemctl restart php8.2-fpm
```

#### Nginx 配合配置
```nginx
# PHP 应用
location ~ \.php$ {
    fastcgi_pass unix:/run/php/php8.2-fpm.sock;
    fastcgi_index index.php;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    include fastcgi_params;
    
    # 超时设置
    fastcgi_connect_timeout 60;
    fastcgi_send_timeout 180;
    fastcgi_read_timeout 180;
    fastcgi_buffer_size 128k;
    fastcgi_buffers 4 256k;
    fastcgi_busy_buffers_size 256k;
}
```

### 7. 故障排查

#### 常见问题
1. **502 Bad Gateway**: 检查 PHP-FPM 是否运行
2. **504 Gateway Timeout**: 增加 `fastcgi_read_timeout`
3. **内存不足**: 降低 `pm.max_children` 或增加内存
4. **CPU 高负载**: 检查是否有死循环脚本

#### 日志位置
- PHP-FPM 日志: `/var/log/php8.2-fpm.log`
- Nginx 错误日志: `/var/log/nginx/error.log`
- 系统日志: `journalctl -u php8.2-fpm`

这个配置针对 E5-2680 v4 + 128GB 内存进行了优化，在保证性能的同时确保系统稳定性。