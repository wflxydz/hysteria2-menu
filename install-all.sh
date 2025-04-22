#!/bin/bash

INSTALL_DIR_BASE="/opt"
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) ARCH_TYPE="amd64" ;;
  aarch64) ARCH_TYPE="arm64" ;;
  *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

function menu() {
  while true; do
    clear
    echo "========= 一键服务管理菜单 ========="
    echo "1. 安装 RustDesk Server（hbbs + hbbr）"
    echo "2. 管理 RustDesk Server"
    echo "3. 安装并管理 FRP"
    echo "4. 安装并管理 Hysteria2"
    echo "5. 安装并管理 ShellHub"
    echo "6. 多端口助手"
    echo "7. 退出"
    read -p "请选择: " CHOICE
    case $CHOICE in
      1) install_rustdesk ;;
      2) manage_rustdesk ;;
      3) manage_frp ;;
      4) manage_hysteria ;;
      5) manage_shellhub ;;
      6) multi_port_helper ;;
      7) exit 0 ;;
      *) echo "❌ 无效输入" ; read -p "按回车继续..." ;;
    esac
  done
}

function install_rustdesk() {
  local INSTALL_DIR="$INSTALL_DIR_BASE/rustdesk"
  mkdir -p "$INSTALL_DIR" && cd "$INSTALL_DIR"

  read -p "请输入 hbbs 端口（默认 21117）: " HBBS_PORT
  read -p "请输入 hbbr 端口（默认 21118）: " HBBR_PORT
  HBBS_PORT=${HBBS_PORT:-21117}
  HBBR_PORT=${HBBR_PORT:-21118}

  echo "下载 RustDesk Server..."
  curl -L -o rustdesk.zip "https://github.com/rustdesk/rustdesk-server/releases/download/1.1.14/rustdesk-server-linux-${ARCH_TYPE}.zip"
  unzip -o rustdesk.zip

  chmod +x ${ARCH_TYPE}/hbbs ${ARCH_TYPE}/hbbr

  # Systemd
  cat <<EOF > /etc/systemd/system/rustdesk-hbbs.service
[Unit]
Description=RustDesk Rendezvous Server
After=network.target

[Service]
ExecStart=$INSTALL_DIR/$ARCH_TYPE/hbbs -p $HBBS_PORT
Restart=always

[Install]
WantedBy=multi-user.target
EOF

  cat <<EOF > /etc/systemd/system/rustdesk-hbbr.service
[Unit]
Description=RustDesk Relay Server
After=network.target

[Service]
ExecStart=$INSTALL_DIR/$ARCH_TYPE/hbbr -p $HBBR_PORT
Restart=always

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now rustdesk-hbbs rustdesk-hbbr
  echo "✅ RustDesk 安装完成并已启动"
  read -p "按回车继续..."
}

function manage_rustdesk() {
  while true; do
    echo "========= RustDesk 管理 ========="
    echo "1. 启动"
    echo "2. 停止"
    echo "3. 重启"
    echo "4. 查看状态"
    echo "5. 查看日志"
    echo "6. 返回主菜单"
    read -p "选择操作: " opt
    case $opt in
      1) systemctl start rustdesk-hbbs rustdesk-hbbr ;;
      2) systemctl stop rustdesk-hbbs rustdesk-hbbr ;;
      3) systemctl restart rustdesk-hbbs rustdesk-hbbr ;;
      4) systemctl status rustdesk-hbbs rustdesk-hbbr ; read -p "按回车继续..." ;;
      5) journalctl -u rustdesk-hbbs -e --no-pager ; read -p "按回车继续..." ;;
      6) break ;;
      *) echo "无效选项" ;;
    esac
  done
}

function manage_frp() {
  echo "📦 TODO: FRP 安装与管理功能集成中..."
  read -p "按回车继续..."
}

function manage_hysteria() {
  echo "📦 TODO: Hysteria2 安装与管理功能集成中..."
  read -p "按回车继续..."
}

function manage_shellhub() {
  echo "📦 TODO: ShellHub 安装与管理功能集成中..."
  read -p "按回车继续..."
}

function multi_port_helper() {
  echo "📦 TODO: 多端口配置助手集成中..."
  read -p "按回车继续..."
}

# 启动菜单
menu
