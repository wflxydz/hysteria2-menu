#!/bin/bash

# 颜色
green(){ echo -e "\033[32m$1\033[0m"; }
red(){ echo -e "\033[31m$1\033[0m"; }

# 检查并安装依赖
check_install() {
  for cmd in curl openssl; do
    if ! command -v $cmd &>/dev/null; then
      green "正在安装依赖：$cmd"
      apt update && apt install -y $cmd
    fi
  done
}

# 安装 hysteria2
install_hysteria2() {
  if ! command -v hysteria &>/dev/null; then
    green "开始安装 Hysteria2..."
    bash <(curl -fsSL https://get.hy2.sh/)
  else
    green "Hysteria2 已安装"
  fi
}

# 配置 hysteria2
config_hysteria2() {
  read -p "请输入你的域名（已解析到本机IP）: " DOMAIN
  read -p "请输入连接密码: " PASSWORD

  mkdir -p /etc/hysteria

  # 生成自签证书
  openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
    -keyout /etc/hysteria/server.key \
    -out /etc/hysteria/server.crt \
    -subj "/CN=bing.com" -days 36500

  chown hysteria /etc/hysteria/server.key
  chown hysteria /etc/hysteria/server.crt

  cat <<EOF > /etc/hysteria/config.yaml
listen: :443

# ACME 模式（需域名已解析到本机IP）
acme:
  domains:
    - $DOMAIN
  email: te11rst@sharklasers.com

# 若使用自签证书请注释上面 acme 段并取消下面 tls 段注释
#tls:
#  cert: /etc/hysteria/server.crt
#  key: /etc/hysteria/server.key

auth:
  type: password
  password: $PASSWORD

masquerade:
  type: proxy
  proxy:
    url: https://bing.com
    rewriteHost: true
EOF

  green "✅ 配置已生成：/etc/hysteria/config.yaml"
}

# 菜单功能
menu() {
  while true; do
    echo -e "\n========= Hysteria2 管理菜单 ========="
    echo "1. 启动 Hysteria2"
    echo "2. 重启 Hysteria2"
    echo "3. 查看状态"
    echo "4. 停止服务"
    echo "5. 设置开机自启"
    echo "6. 查看日志"
    echo "7. 退出"
    echo "======================================"
    read -p "请输入选项 [1-7]: " choice

    case $choice in
      1) systemctl start hysteria-server.service && green "✅ 已启动" ;;
      2) systemctl restart hysteria-server.service && green "✅ 已重启" ;;
      3) systemctl status hysteria-server.service ;;
      4) systemctl stop hysteria-server.service && green "🛑 已停止" ;;
      5) systemctl enable hysteria-server.service && green "✅ 设置为开机自启" ;;
      6) journalctl -u hysteria-server.service -e -f ;;
      7) green "退出菜单" && exit 0 ;;
      *) red "无效输入，请重新选择" ;;
    esac
  done
}

# 执行流程
check_install
install_hysteria2
config_hysteria2
menu
