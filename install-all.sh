#!/bin/bash
# 一键部署与管理 RustDesk / FRPS / Hysteria2 / ShellHub

install_dependencies() {
    echo "正在安装必要依赖..."
    apt update && apt install -y curl wget unzip tar openssl sudo net-tools socat
}

menu() {
clear
echo "========= 多服务部署与管理菜单 ========="
echo "1. 安装 RustDesk 服务端"
echo "2. 安装 FRP (frps) 服务端"
echo "3. 安装 Hysteria2"
echo "4. 安装 ShellHub WebSSH"
echo "5. 查看服务运行状态"
echo "6. 管理服务（启动/重启/停止）"
echo "7. 多端口管理助手"
echo "0. 退出"
echo "======================================="
read -p "请输入选项: " num
case "$num" in
1) install_rustdesk ;;
2) install_frps ;;
3) install_hysteria2 ;;
4) install_shellhub ;;
5) check_status ;;
6) service_control ;;
7) multi_port_helper ;;
0) exit ;;
*) echo "请输入正确的数字" ; sleep 1 ; menu ;;
esac
}

install_rustdesk() {
    echo "请输入 RustDesk 公网端口（默认 21117）:"
    read -p "端口: " rust_port
    rust_port=${rust_port:-21117}
    mkdir -p /opt/rustdesk && cd /opt/rustdesk
    curl -L -o rustdesk-server.zip https://github.com/rustdesk/rustdesk-server/releases/download/1.1.14/rustdesk-server-linux-amd64.zip
    unzip rustdesk-server.zip
    chmod +x amd64/hbbs amd64/hbbr

    cat <<EOF >/etc/systemd/system/rustdesk.service
[Unit]
Description=RustDesk Server
After=network.target

[Service]
Type=simple
ExecStart=/opt/rustdesk/amd64/hbbs -p $rust_port
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reexec
    systemctl daemon-reload
    systemctl enable rustdesk --now
    echo "RustDesk 安装完毕，监听端口: $rust_port"
    sleep 2
    menu
}

install_frps() {
    echo "请输入 FRPS 监听端口（默认 7000）:"
    read -p "端口: " frp_port
    frp_port=${frp_port:-7000}
    mkdir -p /opt/frps && cd /opt/frps
    curl -L -o frp.tar.gz https://github.com/fatedier/frp/releases/download/v0.62.0/frp_0.62.0_linux_amd64.tar.gz
    tar -xzvf frp.tar.gz
    mv frp_0.62.0_linux_amd64/* . && rm -rf frp_0.62.0_linux_amd64
    cat <<EOF >frps.toml
bindPort = $frp_port
dashboardPort = 7500
dashboardUser = admin
dashboardPwd = admin
EOF

    cat <<EOF >/etc/systemd/system/frps.service
[Unit]
Description=Frps Service
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/frps
ExecStart=/opt/frps/frps -c /opt/frps/frps.toml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable frps --now
    echo "FRPS 安装成功，监听端口: $frp_port，Web面板: 7500 用户:admin 密码:admin"
    sleep 2
    menu
}

install_hysteria2() {
    bash <(curl -fsSL https://get.hy2.sh/)
    echo "请输入你的域名（已解析到本机）:"
    read domain
    echo "请输入连接密码:"
    read passwd
    cat <<EOF > /etc/hysteria/config.yaml
listen: :443
acme:
  domains:
    - $domain
  email: fake@hysteria.com
auth:
  type: password
  password: $passwd
masquerade:
  type: proxy
  proxy:
    url: https://bing.com
    rewriteHost: true
EOF
    systemctl enable hysteria-server.service --now
    echo "Hysteria2 配置完成，监听443端口，域名: $domain"
    sleep 2
    menu
}

install_shellhub() {
    curl -fsSL https://get.shellhub.io | sh
    echo "ShellHub Web 管理端安装完成"
    echo "默认访问地址：http://$(curl -s ifconfig.me):8080"
    sleep 2
    menu
}

check_status() {
    echo "========= 服务运行状态 ========="
    echo -n "RustDesk:    "; systemctl is-active rustdesk 2>/dev/null || echo inactive
    echo -n "FRPS:        "; systemctl is-active frps 2>/dev/null || echo inactive
    echo -n "Hysteria2:   "; systemctl is-active hysteria-server.service 2>/dev/null || echo inactive
    echo "ShellHub:    http://$(curl -s ifconfig.me):8080"
    echo "================================"
    read -p "按回车键返回菜单..." temp
    menu
}

service_control() {
    echo "========= 服务控制菜单 ========="
    echo "1. 启动所有服务"
    echo "2. 重启所有服务"
    echo "3. 停止所有服务"
    echo "4. 返回主菜单"
    echo "================================"
    read -p "选择操作: " act
    case "$act" in
        1) systemctl start rustdesk frps hysteria-server.service ;;
        2) systemctl restart rustdesk frps hysteria-server.service ;;
        3) systemctl stop rustdesk frps hysteria-server.service ;;
        4) menu ;;
        *) echo "无效选项" ; sleep 1 ;;
    esac
    sleep 2
    menu
}

multi_port_helper() {
    echo "===== 多端口管理助手 ====="
    echo "例如可用于 FRP 多端口配置、Hysteria fallback 多监听等"
    echo "请输入你要添加的额外监听端口（多个用逗号分隔，例如 7001,7002）:"
    read ports
    IFS=',' read -ra ADDR <<< "$ports"
    for port in "${ADDR[@]}"; do
        echo "已记录端口：$port （请自行添加到具体配置文件中）"
    done
    read -p "按回车键返回菜单..." temp
    menu
}

# 初始化脚本执行
install_dependencies
menu
