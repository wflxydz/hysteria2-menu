#!/bin/bash

set -e

CONFIG_FILE="/etc/hysteria/config.yaml"

function install_hysteria2() {
  echo "==== Hysteria2 安装和配置 ===="

  read -p "请输入你的域名（需已解析到此服务器 IP）: " DOMAIN
  read -p "请输入连接密码: " PASSWORD

  echo "✅ 安装 Hysteria2..."
  bash <(curl -fsSL https://get.hy2.sh/)

  echo "✅ 创建配置目录..."
  mkdir -p /etc/hysteria

  echo "🔐 生成自签证书（ACME 可用则默认使用 ACME）"
  openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
    -keyout /etc/hysteria/server.key \
    -out /etc/hysteria/server.crt \
    -subj "/CN=bing.com" -days 36500

  chown hysteria /etc/hysteria/server.key
  chown hysteria /etc/hysteria/server.crt

  echo "⚙️ 写入配置文件: $CONFIG_FILE"
  cat << EOF > "$CONFIG_FILE"
listen: :443

acme:
  domains:
    - ${DOMAIN}
  email: te11rst@sharklasers.com

# 如需改为使用自签证书，注释上面 acme，取消下方注释
#tls:
#  cert: /etc/hysteria/server.crt
#  key: /etc/hysteria/server.key

auth:
  type: password
  password: ${PASSWORD}

masquerade:
  type: proxy
  proxy:
    url: https://bing.com
    rewriteHost: true
EOF

  echo "🚀 启动并设置开机自启"
  systemctl restart hysteria-server
  systemctl enable hysteria-server

  echo "✅ 安装完成！"
  echo "🔐 域名: $DOMAIN"
  echo "🔑 密码: $PASSWORD"
}

function menu() {
  while true; do
    echo
    echo "===== Hysteria2 管理菜单 ====="
    echo "1. 安装并配置 Hysteria2"
    echo "2. 启动 Hysteria2"
    echo "3. 重启 Hysteria2"
    echo "4. 查看 Hysteria2 状态"
    echo "5. 停止 Hysteria2"
    echo "6. 设置开机自启"
    echo "7. 查看运行日志"
    echo "0. 退出"
    echo "=============================="

    read -p "请选择操作编号: " choice
    case "$choice" in
      1) install_hysteria2 ;;
      2) systemctl start hysteria-server.service ;;
      3) systemctl restart hysteria-server.service ;;
      4) systemctl status hysteria-server.service ;;
      5) systemctl stop hysteria-server.service ;;
      6) systemctl enable hysteria-server.service ;;
      7) journalctl -u hysteria-server.service -e ;;
      0) echo "👋 退出脚本"; exit 0 ;;
      *) echo "❌ 无效的选项，请重新输入。" ;;
    esac
  done
}

menu
