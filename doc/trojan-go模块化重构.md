# Trojan-Go 模块化重构完成

## 🎯 重构目标

1. ✅ **模块化设计** - 不同功能分层管理
2. ✅ **原生实现** - 不考虑 CDN，直接部署
3. ✅ **自动 SSL** - 使用 certbot 自动申请和续期
4. ✅ **自动续期** - 配置定时任务自动续期证书
5. ✅ **简化流程** - 只需输入域名即可完成部署

## 📁 新目录结构

```
scripts/debian12/
├── ssl.sh                          # ⭐ SSL 模块（提升到上层，供多组件复用）
├── trojan-go.sh                    # 入口脚本（兼容旧版）
└── trojan-go/                      # 模块化目录
    ├── main.sh                     # 主流程控制
    ├── lib/                        # 功能模块
    │   ├── env.sh                  # 环境检查和初始化
    │   ├── nginx.sh                # Nginx 安装配置
    │   ├── trojan.sh               # Trojan-Go 安装
    │   └── service.sh              # 服务管理
    └── templates/                  # 配置模板
        └── nginx-vhost.conf        # Nginx 虚拟主机模板
```

## 🏗️ 架构设计

### SSL 模块提升
- **位置**: `scripts/debian12/ssl.sh`
- **原因**: SSL 证书管理是通用功能，不仅 Trojan-Go 需要，其他组件（如自定义 Nginx vhost）也会用到
- **复用性**: 任何需要 SSL 的组件都可以引用此模块

### Nginx vhost 目录
- **位置**: `/etc/openresty/vhost/`
- **配置**: nginx.conf 自动引入 `include /etc/openresty/vhost/*.conf;`
- **优势**: 方便后续添加多个虚拟主机，无需修改主配置文件

## 🚀 核心功能

### 1. 环境模块 (env.sh)
- ✅ Root 权限检查
- ✅ 系统版本检查（Debian 11+）
- ✅ 域名格式验证（正则表达式）
- ✅ DNS 解析检查（带超时控制）
- ✅ 基础工具安装
- ✅ 目录创建
- ✅ 密码生成

### 2. SSL 模块 (ssl.sh) ⭐ 通用模块
- ✅ 安装 certbot
- ✅ 自动申请 Let's Encrypt 证书
- ✅ 参数验证（域名非空检查）
- ✅ 证书存在性检查
- ✅ 配置自动续期（systemd timer）
- ✅ 续期钩子（自动重载服务）
- ✅ 证书测试和续期
- ✅ 证书信息查看

### 3. Nginx 模块 (nginx.sh)
- ✅ 安装 OpenResty
- ✅ 创建 systemd 服务
- ✅ 自动创建 `/etc/openresty/vhost/` 目录
- ✅ 配置 nginx.conf 引入 vhost 目录
- ✅ 配置修改前自动备份
- ✅ 配置测试验证
- ✅ 虚拟主机配置（参数验证）
- ✅ 伪装网站创建
- ✅ 配置重载

### 4. Trojan 模块 (trojan.sh)
- ✅ 下载安装 Trojan-Go（带重试机制）
- ✅ 下载超时控制（30秒）
- ✅ 文件完整性验证
- ✅ 配置文件生成（参数完整性检查）
- ✅ SSL 证书存在性验证
- ✅ systemd 服务创建
- ✅ 配置测试

### 5. 服务模块 (service.sh)
- ✅ 进程清理
- ✅ Service 文件存在性检查
- ✅ 服务启动/停止/重启
- ✅ 配置重载
- ✅ 状态查看
- ✅ 健康检查
- ✅ 服务卸载

## 🔄 工作流程

```
1. 环境初始化
   ├── 检查 root 权限
   ├── 检查系统版本
   ├── 安装基础工具
   └── 创建必要目录

2. 交互式配置
   ├── 输入域名（自动验证格式）
   ├── 输入邮箱（用于证书通知）
   ├── 自动生成密码
   └── 自动生成 WebSocket 路径

3. DNS 检查
   ├── 获取服务器公网 IP
   ├── 解析域名 IP
   └── 对比验证

4. SSL 证书
   ├── 安装 certbot
   ├── 使用 standalone 模式申请证书
   ├── 配置 systemd timer 自动续期
   └── 创建续期钩子脚本

5. Nginx 部署
   ├── 安装 OpenResty
   ├── 创建虚拟主机配置
   ├── 配置 WebSocket 代理
   └── 创建伪装网站

6. Trojan-Go 部署
   ├── 下载安装 Trojan-Go
   ├── 生成配置文件
   └── 创建 systemd 服务

7. 启动服务
   ├── 清理孤立进程
   ├── 启动 Nginx
   ├── 启动 Trojan-Go
   └── 健康检查

8. 完成
   ├── 保存安装信息
   └── 显示客户端配置
```

## 📝 使用示例

### 安装
```bash
# 完全自动化安装
bash scripts/debian12/trojan-go.sh install

# 只需要输入：
# 1. 域名: example.com
# 2. 邮箱: admin@example.com（可选）
# 
# 其他全部自动完成：
# - SSL 证书申请
# - 密码生成
# - WebSocket 路径生成
# - 服务配置和启动
```

### 管理
```bash
# 查看状态
bash scripts/debian12/trojan-go.sh status

# 健康检查
bash scripts/debian12/trojan-go.sh health

# 重启服务
bash scripts/debian12/trojan-go.sh restart

# 测试证书续期
bash scripts/debian12/trojan-go.sh test-renew

# 手动续期证书
bash scripts/debian12/trojan-go.sh renew
```

## 🔐 SSL 证书自动续期

### Certbot Timer
```bash
# 查看 timer 状态
systemctl status certbot.timer

# 查看下次运行时间
systemctl list-timers certbot.timer

# certbot 每天检查两次证书状态
# 剩余 30 天时自动续期
```

### 续期钩子
```bash
# 位置: /etc/letsencrypt/renewal-hooks/deploy/reload-services.sh
# 功能: 证书更新后自动重载 nginx 和 trojan-go
```

## 🎯 优势对比

### 旧版本
- ❌ 需要手动准备 SSL 证书
- ❌ 需要手动粘贴证书内容
- ❌ 需要手动续期证书
- ❌ 代码混在一个文件，难以维护
- ❌ 考虑 CDN 导致配置复杂

### 新版本
- ✅ 自动申请 Let's Encrypt 证书
- ✅ 只需输入域名和邮箱
- ✅ 自动续期，无需人工干预
- ✅ 模块化设计，易于维护和扩展
- ✅ 原生实现，配置简单

## 📊 文件清单

### 核心文件
1. `ssl.sh` (184 行) - **通用 SSL 模块**（提升到上层）
2. `trojan-go.sh` (9 行) - 入口脚本
3. `trojan-go/main.sh` (230 行) - 主流程
4. `trojan-go/lib/env.sh` (159 行) - 环境模块
5. `trojan-go/lib/nginx.sh` (330 行) - Nginx 模块（含 vhost 配置）
6. `trojan-go/lib/trojan.sh` (144 行) - Trojan 模块
7. `trojan-go/lib/service.sh` (211 行) - 服务模块
8. `trojan-go/templates/nginx-vhost.conf` (60 行) - Nginx 模板

### 总计
- **代码量**: ~1300 行（分散在 8 个文件）
- **模块数**: 5 个功能模块
- **模板数**: 1 个配置模板

## 🛡️ 健壮性改进

### 参数验证
- ✅ 所有关键函数都添加参数非空检查
- ✅ 域名格式验证（正则表达式）
- ✅ 配置参数完整性验证

### 文件检查
- ✅ SSL 证书文件存在性验证
- ✅ Systemd service 文件存在性检查
- ✅ 配置文件存在性验证
- ✅ 下载文件完整性检查

### 错误处理
- ✅ 关键步骤错误自动退出
- ✅ 配置修改前自动备份
- ✅ 配置测试失败自动回滚
- ✅ 下载失败自动重试（最多3次）
- ✅ 网络请求超时控制（10-30秒）

### 状态验证
- ✅ 服务启动后状态检查
- ✅ Nginx 配置测试
- ✅ 端口占用检查
- ✅ DNS 解析验证
- ✅ 健康检查机制

## 🔧 技术栈

- **系统**: Debian 12
- **Web 服务器**: OpenResty (Nginx)
- **代理**: Trojan-Go
- **SSL**: Let's Encrypt (certbot)
- **传输**: WebSocket
- **自动化**: systemd timer

## 🎉 总结

这次重构实现了：
1. **完全自动化** - 从安装到续期，全程无需人工干预
2. **模块化设计** - 清晰的代码结构，易于维护和扩展
3. **生产级别** - 自动续期、健康检查、错误处理
4. **用户友好** - 简单的交互流程，详细的提示信息
5. **原生实现** - 不依赖第三方服务，稳定可靠

现在用户只需：
```bash
bash scripts/debian12/trojan-go.sh install
```

输入域名和邮箱，就能获得一个完整的、自动续期的 Trojan-Go 代理服务！🚀
