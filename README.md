# 自动静默部署系统

面向 Debian 12 的模块化服务器环境自动部署工具。

## 快速开始

```bash
# 下载到服务器
cd /root
git clone https://github.com/ACCS2024/deploy.git deploy
cd deploy

# 赋予执行权限
chmod +x install.sh
chmod +x scripts/debian12/*.sh

# 更新脚本（如果有bug修复或新功能）
git pull origin master

# 如果有冲突，强制更新（会覆盖本地修改）
git reset --hard origin/master
git pull origin master

# 重新赋予执行权限（更新后可能需要）
chmod +x install.sh
chmod +x scripts/debian12/*.sh
```

# 安装指定组件
./install.sh --mysql --redis

# 安装 Trojan-Go + Nginx (交互式配置)
./install.sh --trojan-go

# 或直接运行 Trojan-Go 脚本
bash scripts/debian12/trojan-go.sh install

# 安装全部组件（编译模式）
./install.sh --all --mode compile

# 安装全部组件（快速模式，默认）
./install.sh --all --mode fast
```

> **注意**: 所有组件脚本已统一参数处理格式，完全兼容 `--mode` 参数。

## 更新脚本

如果有bug修复或新功能发布，请按以下步骤更新：

### 一键更新（推荐）
```bash
cd /root/deploy
./update.sh
```

> **说明**: 
> - 只备份 `conf/` 目录（可能被覆盖的配置文件）
> - Trojan-Go 和 MySQL 等配置文件在系统目录，不会被更新影响
> - 自动检测本地修改并询问是否强制更新

### 手动更新
```bash
cd /root/deploy
git pull origin master

# 重新赋予执行权限
chmod +x install.sh
chmod +x scripts/debian12/*.sh
```

### 强制更新（覆盖本地修改）
```bash
cd /root/deploy
git reset --hard origin/master
git pull origin master

# 重新赋予执行权限
chmod +x install.sh
chmod +x scripts/debian12/*.sh
```

### 更新前备份重要配置
```bash
cd /root/deploy

# update.sh 会自动备份 conf/ 目录（如果有修改）
# Trojan-Go 配置在 /usr/local/trojan-go/ 不受影响
# MySQL 密码在 /home/video/uboy.cbo 不受影响

# 如需手动备份
cp -r conf/ conf-backup-$(date +%Y%m%d) 2>/dev/null || true

# 然后更新
git pull origin master
```

### 处理更新冲突
如果更新时出现冲突：
```bash
cd /root/deploy

# 查看冲突文件
git status

# 放弃本地修改，接受远程版本
git checkout -- <冲突的文件名>

# 或者强制重置
git reset --hard origin/master
git pull origin master
```

### 查看更新历史
```bash
cd /root/deploy
git log --oneline -10  # 查看最近10次提交
```

### 检查当前版本
```bash
cd /root/deploy
git branch -v  # 查看当前分支和最新提交
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

## Trojan-Go 代理部署

### ✨ 全新特性

- 🚀 **全自动部署**: 一键安装，无需手动配置
- 🔒 **自动 SSL 证书**: 使用 Let's Encrypt 自动申请和续期
- 📦 **模块化设计**: 清晰的目录结构，易于维护
- ⏰ **自动续期**: Certbot 定时任务自动续期证书
- 🎯 **原生实现**: 不依赖 CDN，直接部署

### 快速部署

```bash
# 方式 1: 通过主安装脚本（推荐）
./install.sh --trojan-go

# 方式 2: 直接运行部署脚本
bash scripts/debian12/trojan-go.sh install
```

### 配置要求

安装过程中只需要提供：
- **域名**: 已解析到服务器的域名（必须）
- **邮箱**: 用于 SSL 证书通知（可选）

脚本会自动：
- ✅ 申请 Let's Encrypt SSL 证书
- ✅ 配置 Nginx 反向代理
- ✅ 安装 Trojan-Go 服务
- ✅ 生成 32 位随机密码
- ✅ 设置 WebSocket 路径
- ✅ 配置证书自动续期

### 目录结构

```
scripts/debian12/trojan-go/
├── main.sh                 # 主入口脚本
├── lib/
│   ├── env.sh             # 环境检查和初始化
│   ├── nginx.sh           # Nginx 安装配置
│   ├── trojan.sh          # Trojan-Go 安装
│   ├── ssl.sh             # SSL 证书管理（certbot）
│   └── service.sh         # 服务管理
└── templates/
    └── nginx-vhost.conf   # Nginx 虚拟主机模板
```

### 安装信息

部署完成后，配置信息保存在：
- `/usr/local/trojan-go/install_info.txt` - 完整安装信息
- `/usr/local/trojan-go/config.json` - Trojan-Go 配置
- `/usr/local/openresty/nginx/conf/vhost/{域名}.conf` - Nginx 配置
- `/etc/letsencrypt/live/{域名}/` - SSL 证书目录

### 常用命令

```bash
# 查看状态
bash scripts/debian12/trojan-go.sh status

# 重启服务
bash scripts/debian12/trojan-go.sh restart

# 重载配置
bash scripts/debian12/trojan-go.sh reload

# 健康检查
bash scripts/debian12/trojan-go.sh health

# 测试证书续期
bash scripts/debian12/trojan-go.sh test-renew

# 手动续期证书
bash scripts/debian12/trojan-go.sh renew

# 卸载
bash scripts/debian12/trojan-go.sh uninstall
```

### SSL 证书管理

证书由 certbot 自动管理：
- **自动续期**: systemd timer 每天检查两次
- **续期钩子**: 证书更新后自动重载服务
- **有效期**: Let's Encrypt 证书有效期 90 天
- **提前续期**: 剩余 30 天时自动续期

查看续期计划：
```bash
systemctl status certbot.timer
```

### 服务管理

```bash
# 查看状态
systemctl status trojan-go
systemctl status nginx
systemctl status certbot.timer

# 重启服务
systemctl restart trojan-go
systemctl restart nginx

# 查看日志
tail -f /var/log/trojan-go/trojan-go.log
tail -f /var/log/nginx/{域名}.access.log

# 使用脚本管理
bash scripts/debian12/trojan-go.sh status    # 状态
bash scripts/debian12/trojan-go.sh restart   # 重启
bash scripts/debian12/trojan-go.sh health    # 健康检查
```

### 故障排查

#### 1. 域名解析问题
```bash
# 检查域名解析
dig +short yourdomain.com A

# 检查服务器 IP
curl -4 ifconfig.me
```

#### 2. SSL 证书申请失败
```bash
# 检查端口 80 是否被占用
lsof -i :80

# 查看 certbot 日志
journalctl -u certbot -n 50
```

#### 3. Nginx 端口占用
```bash
# 使用修复脚本
bash fix-nginx-port.sh
```

详细文档请查看: `doc/trojan-go部署指南.md`

## 日志

- 主日志: `/var/log/deploy/deploy-*.log`
- 组件日志: `/var/log/deploy/components/*.log`
- Trojan-Go 日志: `/var/log/trojan-go/trojan-go.log`

## 密码

MySQL root 密码保存在: `/home/video/uboy.cbo`

## 目录结构

```
deploy/
├── install.sh           # 入口脚本
├── update.sh            # 更新脚本
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
