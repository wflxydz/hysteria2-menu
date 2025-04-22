#!/bin/bash

set -e

GREEN='\033[0;32m'
NC='\033[0m'

# 全局配置目录
CONFIG_DIR="/opt/service_configs"

function install_dependencies() {
    echo -e "${GREEN}检测并安装 curl、openssl、unzip、docker...${NC}"
    apt update -y
    apt install -y curl openssl unzip docker.io docker-compose
}

# 设置多端口配置
function set_port() {
    PORT_CONFIG_FILE="${CONFIG_DIR}/port_config.json"
    mkdir -p $CONFIG_DIR

    # 创建端口配置文件
    if [[ ! -f $PORT_CONFIG_FILE ]]; then
        echo '{}' > $PORT_CONFIG_FILE
    fi

    echo "请选择操作："
    echo "1. 添加端口"
    echo "2. 删除端口"
    echo "3. 查看端口配置"
    echo "4. 返回"
    read -p "请输入选项： " option

    case $option in
        1)
            echo "请输入服务名称（如：rustdesk、frp、hysteria）:"
            read service_name
            echo "请输入服务端口："
            read service_port
            jq ".\"${service_name}\" += [${service_port}]" $PORT_CONFIG_FILE > temp.json && mv temp.json $PORT_CONFIG_FILE
            echo -e "${GREEN}端口配置已添加！${NC}"
            ;;
        2)
            echo "请输入服务名称（如：rustdesk、frp、hysteria）:"
            read service_name
            echo "请输入删除的服务端口："
            read service_port
            jq ".\"${service_name}\" |= map(select(. != ${service_port}))" $PORT_CONFIG_FILE > temp.json && mv temp.json $PORT_CONFIG_FILE
            echo -e "${GREEN}端口配置已删除！${NC}"
            ;;
        3)
            echo -e "${GREEN}当前端口配置：${NC}"
            cat $PORT_CONFIG_FILE
            ;;
        4)
            return
            ;;
        *)
            echo "无效选项，返回主菜单"
            ;;
    esac
}

# RustDesk 安装
function install_rustdesk() {
    read -p "请输入 RustDesk 公网端口（默认21117）: " rustdesk_port
    rustdesk_port=${rustdesk_port:-21117}

    mkdir -p /opt/rustdesk
    cd /opt/rustdesk

    echo -e "${GREEN}下载 RustDesk Server...${NC}"
    curl -LO https://github.com/rustdesk/rustdesk-server/releases/download/1.1.14/rustdesk-server-linux-amd64.zip
    unzip -o rustdesk-server-linux-amd64.zip
    chmod +x hbbs hbbr

    cat <<EOF > /etc/systemd/system/rustdesk.service
[Unit]
Description=RustDesk Server
After=network.target

[Service]
ExecStart=/opt/rustdesk/hbbs -p ${rustdesk_port}
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reexec
    systemctl enable --now rustdesk

    echo -e "${GREEN}RustDesk 安装完成！监听端口：$rustdesk_port${NC}"
}

# FRP 安装
function install_frp() {
    read -p "请输入 FRPS 公网端口（默认7000）: " frp_port
    frp_port=${frp_port:-7000}
    read -p "请输入 FRPS dashboard 端口（默认7500）: " frp_dashboard_port
    frp_dashboard_port=${frp_dashboard_port:-7500}
    read -p "设置 FRP dashboard 用户名: " frp_user
    read -p "设置 FRP dashboard 密码: " frp_pass

    mkdir -p /opt/frp
    cd /opt/frp

    curl -LO https://github.com/fatedier/frp/releases/download/v0.62.0/frp_0.62.0_linux_amd64.tar.gz
    tar -xzvf frp_0.62.0_linux_amd64.tar.gz --strip-components=1

    cat <<EOF > /opt/frp/frps.toml
bindPort = ${frp_port}
dashboardAddr = "0.0.0.0"
dashboardPort = ${frp_dashboard_port}
dashboardUser = "${frp_user}"
dashboardPwd = "${frp_pass}"
logLevel = "info"
logFile = "/opt/frp/frps.log"
EOF

    cat <<EOF > /etc/systemd/system/frps.service
[Unit]
Description=FRP Server
After=network.target

[Service]
ExecStart=/opt/frp/frps -c /opt/frp/frps.toml
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reexec
    systemctl enable --now frps

    echo -e "${GREEN}FRP 安装完成！公网端口：$frp_port，Web 面板端口：$frp_dashboard_port${NC}"
}

# Hysteria2 安装
function install_hysteria2() {
    read -p "请输入 Hysteria2 域名（已解析到本机IP）: " hysteria_domain
    read -p "设置访问密码: " hysteria_pass

    bash <(curl -fsSL https://get.hy2.sh/)

    mkdir -p /etc/hysteria

    cat <<EOF > /etc/hysteria/config.yaml
listen: :443
acme:
  domains:
    - ${hysteria_domain}
  email: admin@${hysteria_domain}
auth:
  type: password
  password: ${hysteria_pass}
masquerade:
  type: proxy
  proxy:
    url: https://bing.com
    rewriteHost: true
EOF

    systemctl enable --now hysteria-server

    echo -e "${GREEN}Hysteria2 安装完成，监听端口：443，域名：$hysteria_domain${NC}"
}

# 安装 Web 管理面板
function install_web_panel() {
    echo -e "${GREEN}下载 frp-panel 项目...${NC}"
    echo -e "${GREEN}（示意保留，具体部署可接接vue/Go项目）${NC}"
}

# 设置自动备份
function setup_backup() {
    mkdir -p /opt/backup
    echo -e "0 3 * * * tar -czf /opt/backup/configs_\$(date +\%F).tar.gz /etc/hysteria /opt/frp /opt/rustdesk" > /etc/cron.d/config_backup
    echo -e "${GREEN}已设置每天凌晨3点自动备份配置文件到 /opt/backup 目录${NC}"
}

# 查看服务状态
function show_status_info() {
    echo -e "${GREEN}========= 服务运行状态 =========${NC}"
    echo -e "RustDesk:    $(systemctl is-active rustdesk)"
    echo -e "FRPS:        $(systemctl is-active frps)"
    echo -e "Hysteria2:   $(systemctl is-active hysteria-server)"
    echo -e "ShellHub:    http://$(curl -s ifconfig.me):8080"
}

# 安装远程 SSH Web 管理（ShellHub）
function install_shellhub() {
    echo -e "${GREEN}安装 ShellHub（Web SSH 管理）${NC}"
    mkdir -p /opt/shellhub
    cd /opt/shellhub

    cat <<EOF > docker-compose.yml
version: '3'
services:
  shellhub:
    image: shellhubio/dashboard:latest
    ports:
      - "8022:22"
      - "8080:80"
    environment:
      SHELLHUB_ENTERPRISE: "false"
    volumes:
      - shellhub_data:/data
    restart: always
volumes:
  shellhub_data:
EOF

    docker compose -f docker-compose.yml up -d
    echo -e "${GREEN}访问地址：http://$(curl -s ifconfig.me):8080（首次需注册）${NC}"
}

# 主菜单
function main_menu() {
    while true; do
        echo -e "${GREEN}========= 多功能一键安装脚本 =========${NC}"
        echo "1. 安装 RustDesk"
        echo "2. 安装 FRP"
        echo "3. 安装 Hysteria2"
        echo "4. 安装 FRP Web 管理面板"
        echo "5. 设置配置自动备份"
        echo "6. 查看服务状态信息"
        echo "7. 安装远程SSH Web管理（ShellHub）"
        echo "8. 多端口配置管理"
        echo "9. 退出"
        read -p "请输入选项: " CHOICE
        case $CHOICE in
            1) install_rustdesk ;;
            2) install_frp ;;
            3) install_hysteria2 ;;
            4) install_web_panel ;;
            5) setup_backup ;;
            6) show_status_info ;;
            7) install_shellhub ;;
            8) set_port ;;
            9) echo -e "${GREEN}退出脚本${NC}"; exit 0 ;;
            *) echo "请输入有效选项" ;;
        esac
    done
}

install_dependencies
main_menu
