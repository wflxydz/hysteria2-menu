#!/bin/bash

# 设置默认端口和配置
RUSTDESK_PORT=21117
FRP_PORT=7000
HYSTERIA_PORT=443
DOMAIN=""
SSL_CERT_PATH="/etc/ssl/certs"
SSL_KEY_PATH="/etc/ssl/private"

# 系统更新和依赖安装
echo "正在更新系统并安装依赖..."
apt update && apt upgrade -y
apt install -y curl unzip tar wget git sudo net-tools ufw

# 检查并安装 Docker
if ! command -v docker &>/dev/null; then
  echo "Docker 未安装，正在安装 Docker..."
  curl -fsSL https://get.docker.com | bash
  sudo usermod -aG docker $USER
fi

# 安装 RustDesk
install_rustdesk() {
    echo "正在安装 RustDesk..."
    read -p "请输入 RustDesk 公网端口（默认21117）: " RUSTDESK_PORT
    if [ -z "$RUSTDESK_PORT" ]; then
        RUSTDESK_PORT=21117
    fi
    wget https://github.com/rustdesk/rustdesk-server/releases/download/1.1.14/rustdesk-server-linux-amd64.zip -O /tmp/rustdesk.zip
    unzip /tmp/rustdesk.zip -d /opt/rustdesk
    chmod +x /opt/rustdesk/amd64/hbbs /opt/rustdesk/amd64/hbbr
    echo "RustDesk 已安装，监听端口：$RUSTDESK_PORT"
}

# 安装 FRP
install_frp() {
    echo "正在安装 FRP..."
    read -p "请输入 FRP 公网端口（默认7000）: " FRP_PORT
    if [ -z "$FRP_PORT" ]; then
        FRP_PORT=7000
    fi
    wget https://github.com/fatedier/frp/releases/download/v0.62.0/frp_0.62.0_linux_amd64.tar.gz -O /tmp/frp.tar.gz
    tar -xzvf /tmp/frp.tar.gz -C /opt/frp
    chmod +x /opt/frp/frps
    echo "FRP 已安装，监听端口：$FRP_PORT"
}

# 安装 Hysteria2
install_hysteria() {
    echo "正在安装 Hysteria2..."
    bash <(curl -fsSL https://get.hy2.sh/)
    systemctl enable hysteria-server.service
    systemctl start hysteria-server.service
    echo "Hysteria2 已安装，监听端口：$HYSTERIA_PORT"
}

# 安装 Web 管理面板（ShellHub）
install_shellhub() {
    echo "正在安装 ShellHub Web 管理面板..."
    curl -fsSL https://github.com/shellhub-io/shellhub/releases/download/v0.7.0/shellhub-linux-amd64.tar.gz -o /tmp/shellhub.tar.gz
    tar -xzvf /tmp/shellhub.tar.gz -C /opt/shellhub
    /opt/shellhub/shellhub &> /dev/null &
    echo "ShellHub 已安装，访问管理面板：http://$(curl -s ifconfig.me):8080"
}

# SSL 证书申请
generate_ssl() {
    echo "正在申请 SSL 证书..."
    read -p "请输入你的域名（例如 example.com）: " DOMAIN
    if [ -z "$DOMAIN" ]; then
        echo "域名不能为空，退出 SSL 证书申请"
        exit 1
    fi
    apt install -y socat
    curl https://get.acme.sh | sh
    ~/.acme.sh/acme.sh --issue -d $DOMAIN --webroot /var/www/html
    ~/.acme.sh/acme.sh --installcert -d $DOMAIN \
        --key-file $SSL_KEY_PATH/$DOMAIN.key \
        --fullchain-file $SSL_CERT_PATH/$DOMAIN.crt
    echo "SSL 证书已申请并安装，证书路径：$SSL_KEY_PATH/$DOMAIN.key"
}

# 启动 Web 管理面板和服务
start_services() {
    echo "启动所有服务..."
    systemctl start hysteria-server.service
    systemctl start rustdesk-server.service
    systemctl start frp-server.service
    echo "所有服务已启动"
}

# 查看所有服务状态
check_services_status() {
    echo "查看服务运行状态..."
    echo "RustDesk 状态: $(systemctl is-active rustdesk-server.service)"
    echo "FRP 状态: $(systemctl is-active frp-server.service)"
    echo "Hysteria2 状态: $(systemctl is-active hysteria-server.service)"
    echo "ShellHub 状态: $(systemctl is-active shellhub.service)"
}

# 主菜单
menu() {
    PS3="请选择要执行的操作: "
    options=("安装 RustDesk Server" "安装 FRP Server" "安装 Hysteria2" "安装 Web 管理面板" "申请 SSL 证书" "启动所有服务" "查看服务状态" "退出")
    select opt in "${options[@]}"; do
        case $opt in
            "安装 RustDesk Server")
                install_rustdesk
                break
                ;;
            "安装 FRP Server")
                install_frp
                break
                ;;
            "安装 Hysteria2")
                install_hysteria
                break
                ;;
            "安装 Web 管理面板")
                install_shellhub
                break
                ;;
            "申请 SSL 证书")
                generate_ssl
                break
                ;;
            "启动所有服务")
                start_services
                break
                ;;
            "查看服务状态")
                check_services_status
                break
                ;;
            "退出")
                exit
                ;;
            *)
                echo "无效选项，请重新选择"
                ;;
        esac
    done
}

# 执行主菜单
menu
