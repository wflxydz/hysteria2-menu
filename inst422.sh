#!/bin/bash

# 检查是否以 root 用户运行
if [[ $EUID -ne 0 ]]; then
  echo "请以 root 用户运行此脚本"
  exit 1
fi

# 端口冲突检测函数
check_port_conflict() {
  local port=$1
  if lsof -i :$port &>/dev/null; then
    echo "端口 $port 已被占用，请检查是否已有服务运行或修改配置文件中的端口。"
    exit 1
  fi
}

# 安装 RustDesk 服务端
install_rustdesk() {
  echo "正在安装 RustDesk 服务端..."
  check_port_conflict 21115
  check_port_conflict 21116
  check_port_conflict 21117

  curl -fsSL https://raw.githubusercontent.com/royalrajendran/rustdesk-server-install/main/install.sh | bash
  echo "RustDesk 服务端安装完成"
}

# 安装并配置 FRP
install_frp() {
  echo "正在安装并配置 FRP..."
  bash <(curl -fsSL https://raw.githubusercontent.com/fatedier/frp/dev/script/install.sh)

  mkdir -p /etc/frp
  cat > /etc/frp/frps.toml <<EOF
[common]
bind_port = 7000
kcp_bind_port = 7000
dashboard_port = 7500
dashboard_user = "admin"
dashboard_pwd = "admin"
log_file = "/var/log/frps.log"
log_level = "info"
log_max_days = 3
EOF

  cat > /etc/systemd/system/frps.service <<EOF
[Unit]
Description=FRP Server Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/frps -c /etc/frp/frps.toml
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

  cat > /etc/frp/frpc.toml <<EOF
[common]
server_addr = "127.0.0.1"
server_port = 7000

[ssh]
type = tcp
local_ip = "127.0.0.1"
local_port = 22
remote_port = 6000
EOF

  cat > /etc/systemd/system/frpc.service <<EOF
[Unit]
Description=FRP Client Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/frpc -c /etc/frp/frpc.toml
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reexec
  systemctl enable frps frpc
  systemctl start frps frpc
  echo "FRP 安装完成"
}

# 安装 Hysteria2
install_hysteria2() {
  echo "正在安装 Hysteria2..."
  check_port_conflict 443

  bash <(curl -fsSL https://get.hy2.sh/)

  mkdir -p /etc/hysteria
  cat > /etc/hysteria/config.yaml <<EOF
listen: :443
tls:
  cert: /etc/hysteria/cert.pem
  key: /etc/hysteria/key.pem
auth:
  type: password
  password: your_password
EOF

  echo "Hysteria2 安装完成，请将 SSL 证书和密钥文件放入 /etc/hysteria 目录"
}

# 安装 ShellHub
install_shellhub() {
  echo "正在安装 ShellHub..."
  curl -fsSL https://github.com/shellhub-io/shellhub/raw/main/install.sh | sh
  echo "ShellHub 安装完成"
}

# 卸载所有已安装服务
uninstall_all() {
  echo "正在卸载所有服务..."

  # 卸载 RustDesk
  systemctl stop hbbs hbbh &>/dev/null
  systemctl disable hbbs hbbh &>/dev/null
  rm -f /etc/systemd/system/hbbs.service /etc/systemd/system/hbbr.service
  rm -rf /usr/local/bin/hbbs /usr/local/bin/hbbr /opt/rustdesk

  # 卸载 FRP
  systemctl stop frps frpc &>/dev/null
  systemctl disable frps frpc &>/dev/null
  rm -f /etc/systemd/system/frps.service /etc/systemd/system/frpc.service
  rm -rf /usr/local/bin/frps /usr/local/bin/frpc /etc/frp

  # 卸载 Hysteria2
  systemctl stop hysteria-server &>/dev/null
  systemctl disable hysteria-server &>/dev/null
  rm -rf /etc/systemd/system/hysteria-server.service /usr/local/bin/hysteria /etc/hysteria

  # 卸载 ShellHub
  docker rm -f $(docker ps -aq --filter ancestor=shellhubio) &>/dev/null

  echo "卸载完成"
}

# 主菜单
main_menu() {
  echo "请选择要执行的操作："
  echo "1) 安装 RustDesk"
  echo "2) 安装 FRP"
  echo "3) 安装 Hysteria2"
  echo "4) 安装 ShellHub"
  echo "5) 卸载所有服务"
  echo "0) 退出"
  read -rp "请输入选项 [0-5]: " option
  case $option in
    1) install_rustdesk ;;
    2) install_frp ;;
    3) install_hysteria2 ;;
    4) install_shellhub ;;
    5) uninstall_all ;;
    0) exit 0 ;;
    *) echo "无效选项" ;;
  esac
}

main_menu
