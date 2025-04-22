# Hysteria2 一键安装脚本（带交互菜单）

本项目提供了一个简单易用的 Bash 脚本，用于在 Linux VPS 上一键安装、配置并管理 [Hysteria2](https://v2.hysteria.network/)，支持自签证书或 ACME 自动签发证书（Let's Encrypt），并提供交互式管理菜单。

---

## 🚀 一键安装使用方法

### 1. 下载脚本并赋予权限

```bash
wget https://raw.githubusercontent.com/wflxydz/hysteria2-menu/main/hysteria2-menu.sh
chmod +x hysteria2-menu.sh


./hysteria2-menu.sh
一键安装 Hysteria2

自动生成配置文件

自签证书 / ACME 自动签发证书可选

启动、停止、重启、查看状态、查看日志等操作

设置开机自启

退出菜单
listen: :443

acme:
  domains:
    - your.domain.com
  email: your-email@example.com

auth:
  type: password
  password: your-password

masquerade:
  type: proxy
  proxy:
    url: https://bing.com
    rewriteHost: true
请提前将你的域名解析至 VPS 的公网 IP。

如果使用 ACME 自动签发证书，请确保 443 端口未被占用（如关闭 Nginx）。
