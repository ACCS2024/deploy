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

## 可用组件

| 组件 | 参数 | 说明 |
|------|------|------|
| system | `--system` | 时区、DNS、目录、apt源 |
| network | `--network` | BBR、sysctl 内核优化 |
| packages | `--packages` | 基础软件包、编译依赖 |
| php | `--php` | PHP-FPM |
| openresty | `--openresty` | OpenResty/Nginx |
| mysql | `--mysql` | MySQL 8.0 |
| redis | `--redis` | Redis |
| fail2ban | `--fail2ban` | Fail2ban |
| firewall | `--firewall` | iptables 规则 |

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
