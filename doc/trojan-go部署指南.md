# Trojan-Go + Nginx 一键部署指南

## 概述

此脚本用于在 Debian 12 系统上一键部署 Trojan-Go + Nginx 代理服务器。

## 功能特性

- ✅ 自动环境初始化（更新系统、安装必要工具）
- ✅ 自动安装配置 Nginx (OpenResty)
- ✅ 自动安装配置 Trojan-Go
- ✅ 自动创建 systemd 服务文件
- ✅ 自动配置开机自启动
- ✅ 交互式配置（域名、SSL证书）
- ✅ 自动生成随机密码
- ✅ WebSocket 支持
- ✅ 伪装网站支持
- ✅ 服务状态监控

## 前置要求

1. **操作系统**: Debian 12 (Bookworm)
2. **权限**: 需要 root 权限
3. **网络**: 服务器需要能够访问互联网
4. **域名**: 已解析到服务器IP的域名
5. **SSL证书**: 准备好域名的 SSL 证书和私钥
6. **Nginx**: 推荐先通过主脚本安装 OpenResty（`./install.sh --openresty`），如未安装会自动使用官方源安装

## 安装步骤

### 1. 下载脚本

```bash
cd /root
git clone https://github.com/ACCS2024/deploy.git deploy
cd deploy
```

### 2. 推荐先安装 OpenResty (可选)

```bash
# 通过主脚本安装 OpenResty（编译安装，功能更完整）
./install.sh --openresty

# 如果跳过这步，Trojan-Go 脚本会自动使用官方源快速安装 OpenResty
```

### 3. 准备 SSL 证书

在运行脚本前，请准备好以下内容：
- SSL 证书文件内容（.crt 或 .pem）
- SSL 私钥文件内容（.key）

### 4. 运行安装脚本

```bash
chmod +x scripts/debian12/trojan-go.sh
bash scripts/debian12/trojan-go.sh install
```

### 5. 按照提示输入配置信息

脚本会要求你输入：

1. **域名** (例如: example.com)
2. **SSL 证书内容** (粘贴完整的证书内容，按 Ctrl+D 结束)
3. **SSL 私钥内容** (粘贴完整的私钥内容，按 Ctrl+D 结束)

脚本会自动生成：
- Trojan-Go 密码（32位随机字符串）
- WebSocket 路径（/ws + 8位随机字符串）

### 6. 等待安装完成

脚本会自动完成以下操作：
- 更新系统包
- 安装必要工具（curl, wget, unzip等）
- 检查并安装 OpenResty (如未安装，使用官方源快速安装)
- 下载安装 Trojan-Go
- 配置服务文件
- 部署 SSL 证书
- 创建 Nginx 虚拟主机配置
- 启动服务并设置开机自启

## 配置文件位置

- **Trojan-Go 配置**: `/usr/local/trojan-go/config.json`
- **Trojan-Go 日志**: `/var/log/trojan-go/trojan-go.log`
- **Nginx 虚拟主机配置**: `/usr/local/openresty/nginx/conf/vhost/<域名>.conf`
- **SSL 证书**: `/usr/local/openresty/nginx/conf/ssl/`
- **安装信息**: `/usr/local/trojan-go/install_info.txt`

## 常用命令

### 查看服务状态

```bash
# 查看 Trojan-Go 状态
systemctl status trojan-go

# 查看 Nginx 状态
systemctl status nginx

# 或使用脚本
bash scripts/debian12/trojan-go.sh status
```

### 重启服务

```bash
# 重启 Trojan-Go
systemctl restart trojan-go

# 重启 Nginx
systemctl restart nginx

# 重新加载配置
bash scripts/debian12/trojan-go.sh reload
```

### 查看日志

```bash
# 查看 Trojan-Go 日志
tail -f /var/log/trojan-go/trojan-go.log

# 查看 Nginx 访问日志
tail -f /var/log/nginx/<域名>.access.log

# 查看 Nginx 错误日志
tail -f /var/log/nginx/<域名>.error.log
```

### 停止服务

```bash
# 停止 Trojan-Go
systemctl stop trojan-go

# 停止 Nginx
systemctl stop nginx
```

### 禁用开机自启

```bash
# 禁用 Trojan-Go 开机自启
systemctl disable trojan-go

# 禁用 Nginx 开机自启
systemctl disable nginx
```

### 卸载服务

```bash
# 卸载 Trojan-Go
bash scripts/debian12/trojan-go.sh uninstall
```

## 客户端配置

安装完成后，使用以下信息配置客户端：

- **服务器地址**: 你的域名
- **端口**: 443
- **密码**: 安装时生成的密码（查看 `/usr/local/trojan-go/install_info.txt`）
- **传输协议**: WebSocket
- **WebSocket 路径**: /ws + 8位字符（查看安装信息文件）
- **TLS**: 启用
- **SNI**: 你的域名

## 示例配置信息

安装完成后，配置信息会保存在 `/usr/local/trojan-go/install_info.txt`：

```
========================================
Trojan-Go 安装信息
========================================
安装时间: 2025-12-04 10:30:00
域名: example.com
Trojan-Go 密码: AbCdEf1234567890AbCdEf1234567890
WebSocket 路径: /wsAbCdEf12
服务端口: 443 (HTTPS)
配置文件: /usr/local/trojan-go/config.json
日志目录: /var/log/trojan-go
========================================
```

## 防火墙配置

如果服务器启用了防火墙，需要开放以下端口：

```bash
# 使用 ufw
ufw allow 80/tcp
ufw allow 443/tcp

# 或使用 iptables
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
```

## 故障排查

### 1. 服务无法启动

检查配置文件是否正确：
```bash
# 测试 Nginx 配置
nginx -t

# 查看 Trojan-Go 配置
cat /usr/local/trojan-go/config.json
```

### 2. SSL 证书错误

确保证书文件格式正确，路径正确：
```bash
ls -l /usr/local/openresty/nginx/conf/ssl/
openssl x509 -in /usr/local/openresty/nginx/conf/ssl/<域名>.crt -text -noout
```

### 3. 无法连接

检查防火墙、端口监听：
```bash
# 检查端口监听
netstat -tlnp | grep -E '(:80|:443|:8443)'

# 或使用 ss
ss -tlnp | grep -E '(:80|:443|:8443)'
```

### 4. 查看详细日志

```bash
# Trojan-Go 日志
journalctl -u trojan-go -f

# Nginx 日志
journalctl -u nginx -f
```

## 安全建议

1. **定期更新系统**
   ```bash
   apt update && apt upgrade -y
   ```

2. **配置防火墙**（使用 ufw 或 iptables）

3. **定期更新 SSL 证书**

4. **监控服务运行状态**

5. **定期备份配置文件**

6. **使用强密码**（脚本已自动生成32位随机密码）

## 更新 Trojan-Go

```bash
# 停止服务
systemctl stop trojan-go

# 下载新版本
cd /tmp
wget https://github.com/p4gefau1t/trojan-go/releases/download/<新版本>/trojan-go-linux-amd64.zip
unzip trojan-go-linux-amd64.zip -d trojan-go-tmp
cp trojan-go-tmp/trojan-go /usr/local/trojan-go/
chmod +x /usr/local/trojan-go/trojan-go

# 重启服务
systemctl start trojan-go
```

## 技术支持

如遇问题，请查看：
- Trojan-Go 官方文档: https://p4gefau1t.github.io/trojan-go/
- OpenResty 官方文档: https://openresty.org/

## 许可证

本脚本遵循项目根目录的许可证。
