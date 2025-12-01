# 自动静默部署系统

面向 Debian 12 的模块化服务器环境自动部署工具。

## 快速开始

```bash
# 下载到服务器
cd /root
git clone <repo> deploy
cd deploy

# 赋予执行权限
chmod +x install.sh

# 安装指定组件
./install.sh --mysql --redis

# 安装全部组件（编译模式）
./install.sh --all --mode compile

# 安装全部组件（快速模式）
./install.sh --all --mode fast
```

## PHP-FPM 性能优化

当前配置针对 **Intel Xeon E5-2680 v4 (14核) + 128GB内存** 进行了优化：

### 关键参数
- **pm.max_children**: 112 (基于内存和CPU核心数计算)
- **pm.start_servers**: 28
- **pm.min_spare_servers**: 14
- **pm.max_spare_servers**: 56
- **memory_limit**: 256MB (每个进程)
- **upload_max_filesize**: 100MB

### 性能监控
```bash
# 运行自检脚本
./selfcheck.sh

# 查看 PHP-FPM 状态
systemctl status php8.2-fpm

# 监控进程和内存
ps aux --no-headers -o "rss,cmd" -C php-fpm | awk '{ sum+=$1 } END { printf ("平均内存: %.1fMB\n", sum/NR/1024) }'
```

### 详细配置说明
请查看 `doc/开发/PHP-FPM优化配置.md`

## 部署模式

- `--mode fast` (默认): 使用预编译包，速度快
- `--mode compile`: 从源码编译，可定制

## 日志

- 主日志: `/var/log/deploy/deploy-*.log`
- 组件日志: `/var/log/deploy/components/*.log`

## 密码

MySQL root 密码保存在: `/home/video/uboy.cbo`

## 目录结构

```
deploy/
├── install.sh           # 入口脚本
├── lib/common.sh        # 公共函数
├── config/              # 配置文件
│   └── versions.conf    # 版本和路径配置
├── conf/                # OpenResty 配置模板
│   ├── nginx.conf       # 主配置
│   ├── vhost/           # 虚拟主机
│   ├── rewrite/         # 重写规则
│   └── ssl/             # SSL 证书
├── scripts/
│   └── debian12/        # Debian 12 组件脚本
└── doc/                 # 文档
```

## 配置管理

### OpenResty 配置

安装 OpenResty 时会自动：
1. 备份现有配置到 `/usr/local/openresty/nginx/backup/conf-时间戳-随机ID/`
2. 从 `conf/` 目录部署新配置
3. 自动过滤无用文件（.default, .bak 等）

### 自定义配置

编辑 `conf/` 目录下的配置文件，然后重新执行：
```bash
./install.sh --openresty
```

### 配置回滚

如需回滚，从备份目录手动恢复：
```bash
rsync -a /usr/local/openresty/nginx/backup/conf-xxx/ /usr/local/openresty/nginx/conf/
systemctl reload openresty
```

## 扩展其他系统

1. 在 `scripts/` 下创建新目录（如 `ubuntu2204/`）
2. 复制 `debian12/` 脚本并修改包管理命令
3. `install.sh` 会自动检测并调用对应脚本
