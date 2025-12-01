# 配置文件清理说明

## 已删除的文件

### 根目录
- `fastcgi.conf.default` - 官方默认文件
- `fastcgi_params.default` - 官方默认文件
- `mime.types.default` - 官方默认文件
- `nginx.conf.default` - 官方默认备份
- `nginx.conf_bk` - 旧备份文件
- `scgi_params.default` - 官方默认文件
- `uwsgi_params.default` - 官方默认文件
- `local.conf_` - 临时配置文件
- `koi-utf` - 字符编码映射（不常用）
- `koi-win` - 字符编码映射（不常用）
- `win-utf` - 字符编码映射（不常用）
- `fstab` - 错误放置的系统文件

### rewrite 目录
- `bfzyfire.conf` - 重复的 Lua 防护配置
- `bfzyfire1.conf` - Cloudflare IP 白名单（已整合）
- `geo_back.conf` - geo.conf 的备份文件
- `maccms-fire.lua` - 未被引用的 Lua 脚本

## 保留的有效配置

### 核心配置
- `nginx.conf` - 主配置文件
- `fastcgi.conf` - FastCGI 配置
- `fastcgi_params` - FastCGI 参数
- `mime.types` - MIME 类型定义
- `proxy.conf` - 代理配置
- `scgi_params` - SCGI 参数
- `uwsgi_params` - uWSGI 参数

### rewrite 目录（有效配置）
- `ban.conf` - IP 黑名单（964条规则）
- `fire.conf` - 限流配置
- `geo.conf` - CORS 和访问控制
- `none.conf` - 空配置占位符
- `proxy.conf` - 代理规则
- `proxym3u8.conf` - M3U8 代理规则
- `service.conf` - 服务配置
- `webfire.conf` - Web 防护规则
- `wordpress.conf` - WordPress 重写规则

### 目录
- `ssl/` - SSL 证书目录
- `vhost/` - 虚拟主机配置目录

## 清理方式

配置文件会在部署时自动过滤：
- `--exclude='.git'` 排除 git 文件
- `--exclude='*.default'` 排除默认文件
- `--exclude='*_bk'` 排除备份文件

安装脚本会自动删除：
- `*.bak` 临时备份文件
- `*~` 编辑器临时文件
