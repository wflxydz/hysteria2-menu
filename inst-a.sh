#!/bin/bash

# Ensure the script exits immediately if a command exits with a non-zero status.
set -e

# Define color codes for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Global configuration directory (used for port config file)
CONFIG_DIR="/opt/service_configs"

# --- Function to install necessary dependencies ---
function install_dependencies() {
    echo -e "${GREEN}Updating system and installing dependencies...${NC}"
    # Update package list
    apt update -y || { echo -e "${RED}Error updating apt package list.${NC}"; exit 1; }
    # Upgrade installed packages
    apt upgrade -y

    # List of required dependencies
    DEPENDENCIES="curl openssl unzip tar wget git sudo net-tools ufw jq socat docker.io docker-compose"

    # Loop through dependencies and install if not found
    for dep in $DEPENDENCIES; do
        if ! command -v $dep &>/dev/null; then
            echo -e "${GREEN}Installing missing dependency: $dep...${NC}"
            apt install -y $dep || { echo -e "${RED}Error installing dependency: $dep.${NC}"; exit 1; }
        else
            echo -e "${YELLOW}$dep is already installed.${NC}"
        fi
    done

    # Special check and installation for Docker if the command isn't found
    if ! command -v docker &>/dev/null; then
      echo -e "${GREEN}Docker command not found, attempting official script installation...${NC}"
      curl -fsSL https://get.docker.com | bash || { echo -e "${RED}Error installing Docker via official script.${NC}"; exit 1; }
      echo -e "${GREEN}Adding current user '$USER' to the 'docker' group.${NC}"
      usermod -aG docker $USER || echo -e "${YELLOW}Warning: Could not add user '$USER' to docker group. You may need to log out and log back in for changes to take effect, or run docker commands with sudo.${NC}"
    fi

    # Install acme.sh for SSL certificate management
    if [ ! -d "$HOME/.acme.sh" ]; then
        echo -e "${GREEN}Installing acme.sh for SSL certificate management...${NC}"
        # Install with auto-upgrade enabled
        curl https://get.acme.sh | sh -s -- auto-upgrade 1 || echo -e "${YELLOW}Warning: Failed to install acme.sh. SSL certificate generation might not work.${NC}"
    else
        echo -e "${YELLOW}acme.sh is already installed.${NC}"
    fi

    echo -e "${GREEN}Dependency installation complete.${NC}"
}

# --- Function to manage port configuration using jq ---
# Note: This function helps record ports but does not automatically configure service files.
# User is responsible for ensuring service configurations match.
function manage_port_config() {
    PORT_CONFIG_FILE="${CONFIG_DIR}/port_config.json"
    mkdir -p $CONFIG_DIR

    # Create port config file if it doesn't exist with an empty JSON object
    if [[ ! -f $PORT_CONFIG_FILE ]]; then
        echo '{}' > $PORT_CONFIG_FILE
    fi

    while true; do
        echo -e "${GREEN}========= 端口配置管理 =========${NC}"
        echo "这是一个记录您为不同服务配置的端口的工具。"
        echo "请注意，此工具不会自动修改服务的配置文件。"
        echo ""
        echo "1. 添加服务端口记录"
        echo "2. 删除服务端口记录"
        echo "3. 查看当前端口记录"
        echo "4. 返回主菜单"
        read -p "请输入选项 (1-4): " option

        case $option in
            1)
                read -p "请输入服务名称 (例如: rustdesk, frp_bind, frp_dashboard, hysteria, shellhub_web, shellhub_ssh): " service_name
                read -p "请输入对应的端口号: " service_port
                # Basic validation for port number
                if ! [[ "$service_port" =~ ^[0-9]+$ && "$service_port" -ge 1 && "$service_port" -le 65535 ]]; then
                    echo -e "${RED}无效的端口号. 请输入一个 1 到 65535 之间的数字.${NC}"
                    continue
                fi
                # Use jq to add the port to the array for the service name
                jq ".\"${service_name}\" |= (. // []) + [${service_port}]" $PORT_CONFIG_FILE > temp.json && mv temp.json $PORT_CONFIG_FILE
                echo -e "${GREEN}端口记录已添加：服务 '${service_name}', 端口 '${service_port}'!${NC}"
                ;;
            2)
                read -p "请输入要删除记录的服务名称: " service_name
                read -p "请输入要删除的端口号: " service_port
                 # Basic validation for port number
                if ! [[ "$service_port" =~ ^[0-9]+$ && "$service_port" -ge 1 && "$service_port" -le 65535 ]]; then
                    echo -e "${RED}无效的端口号.${NC}"
                    continue
                fi
                # Use jq to remove the port from the array for the service name
                jq ".\"${service_name}\" |= map(select(. != ${service_port}))" $PORT_CONFIG_FILE > temp.json && mv temp.json $PORT_CONFIG_FILE
                echo -e "${GREEN}端口记录已删除：服务 '${service_name}', 端口 '${service_port}'!${NC}"
                ;;
            3)
                echo -e "${GREEN}======== 当前端口记录 ========${NC}"
                # Check if the file exists and is not empty before printing
                if [[ -s $PORT_CONFIG_FILE ]]; then
                    cat $PORT_CONFIG_FILE | jq .
                else
                    echo "没有端口记录."
                fi
                echo -e "${GREEN}===============================${NC}"
                ;;
            4)
                return # Exit the port management menu loop
                ;;
            *)
                echo -e "${RED}无效的选项，请输入 1 到 4 之间的数字.${NC}"
                ;;
        esac
        echo "" # Add a newline for spacing before the menu loops again
    done
}

# --- Function to install RustDesk Server ---
function install_rustdesk() {
    echo -e "${GREEN}正在安装 RustDesk Server...${NC}"
    read -p "请输入 RustDesk 公网端口 (默认 21117): " rustdesk_port
    rustdesk_port=${rustdesk_port:-21117}

    mkdir -p /opt/rustdesk
    cd /opt/rustdesk || { echo -e "${RED}Error changing directory to /opt/rustdesk.${NC}"; return; }

    echo -e "${GREEN}下载 RustDesk Server v1.1.14...${NC}"
    # Using curl with -L to follow redirects, -f to fail silently on errors, -O to save with remote filename
    curl -fLO https://github.com/rustdesk/rustdesk-server/releases/download/1.1.14/rustdesk-server-linux-amd64.zip || { echo -e "${RED}Error downloading RustDesk server.${NC}"; return; }
    unzip -o rustdesk-server-linux-amd64.zip || { echo -e "${RED}Error unzipping RustDesk server.${NC}"; return; }
    chmod +x hbbs hbbr # Ensure execute permissions

    echo -e "${GREEN}创建 RustDesk systemd 服务文件...${NC}"
    cat <<EOF > /etc/systemd/system/rustdesk.service
[Unit]
Description=RustDesk Server
After=network.target

[Service]
ExecStart=/opt/rustdesk/hbbs -p ${rustdesk_port}
Restart=always
User=root
WorkingDirectory=/opt/rustdesk # Set working directory

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd manager configuration
    systemctl daemon-reload
    # Enable the service to start on boot and start it immediately
    systemctl enable --now rustdesk.service || { echo -e "${RED}Error enabling or starting RustDesk service.${NC}"; return; }

    echo -e "${GREEN}RustDesk Server 安装完成并已启动！监听端口：${rustdesk_port}${NC}"
    echo "请确保防火墙已放行 TCP 端口 ${rustdesk_port}."
    echo "另外 RustDesk 客户端连接时，可能还需要 21116 (TCP/UDP), 21118 (TCP), 21119 (TCP) 端口，请根据需要放行."
}

# --- Function to install FRP Server ---
function install_frp() {
    echo -e "${GREEN}正在安装 FRP Server...${NC}"
    read -p "请输入 FRPS 公网绑定端口 (默认 7000): " frp_port
    frp_port=${frp_port:-7000}
    read -p "请输入 FRPS dashboard 端口 (默认 7500): " frp_dashboard_port
    frp_dashboard_port=${frp_dashboard_port:-7500}
    read -p "设置 FRP dashboard 用户名: " frp_user
    read -p "设置 FRP dashboard 密码: " frp_pass

    mkdir -p /opt/frp
    cd /opt/frp || { echo -e "${RED}Error changing directory to /opt/frp.${NC}"; return; }

    echo -e "${GREEN}下载 FRP Server v0.62.0...${NC}"
    curl -fLO https://github.com/fatedier/frp/releases/download/v0.62.0/frp_0.62.0_linux_amd64.tar.gz || { echo -e "${RED}Error downloading FRP server.${NC}"; return; }
    tar -xzvf frp_0.62.0_linux_amd64.tar.gz --strip-components=1 || { echo -e "${RED}Error extracting FRP server.${NC}"; return; } # Strip components to get files directly in /opt/frp
    chmod +x frps # Ensure execute permission

    echo -e "${GREEN}创建 FRPS 配置文件 frps.toml...${NC}"
    cat <<EOF > /opt/frp/frps.toml
bindPort = ${frp_port}
dashboardAddr = "0.0.0.0" # Listen on all interfaces
dashboardPort = ${frp_dashboard_port}
dashboardUser = "${frp_user}"
dashboardPwd = "${frp_pass}"
logLevel = "info"
logFile = "/opt/frp/frps.log"
# Optional: Add a token for client authentication
# token = "your_secret_token"
# Optional: Enable QUIC
# quicListenPort = ${frp_port}
EOF

    echo -e "${GREEN}创建 FRP systemd 服务文件...${NC}"
    cat <<EOF > /etc/systemd/system/frps.service
[Unit]
Description=FRP Server
After=network.target

[Service]
ExecStart=/opt/frp/frps -c /opt/frp/frps.toml
Restart=always
User=root
WorkingDirectory=/opt/frp # Set working directory

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload # Reload systemd manager configuration
    # Enable the service to start on boot and start it immediately
    systemctl enable --now frps.service || { echo -e "${RED}Error enabling or starting FRPS service.${NC}"; return; }

    echo -e "${GREEN}FRP Server 安装完成并已启动！公网绑定端口：${frp_port}，Web 面板端口：${frp_dashboard_port}${NC}"
    echo "访问 FRP dashboard 地址: http://您的服务器IP:${frp_dashboard_port}"
    echo "请确保防火墙已放行 TCP 端口 ${frp_port} 和 ${frp_dashboard_port}."
}

# --- Function to install Hysteria2 ---
function install_hysteria2() {
    echo -e "${GREEN}正在安装 Hysteria2...${NC}"
    echo "Hysteria2 默认使用 443 端口，并集成 ACME 自动申请 SSL 证书。"
    echo "请确保您的域名已正确解析到本服务器 IP，并且 443 端口没有被其他服务占用。"

    read -p "请输入 Hysteria2 域名 (必须已解析到本机公网 IP): " hysteria_domain
    if [ -z "$hysteria_domain" ]; then
        echo -e "${RED}域名不能为空. Hysteria2 安装中止.${NC}"
        return
    fi
    read -p "设置访问密码: " hysteria_pass
    if [ -z "$hysteria_pass" ]; then
        echo -e "${RED}密码不能为空. Hysteria2 安装中止.${NC}"
        return
    fi

    # The get.hy2.sh script downloads the binary, creates the systemd service (usually hysteria-server.service),
    # and handles basic setup.
    echo -e "${GREEN}下载并运行 Hysteria2 官方安装脚本...${NC}"
    # Using curl with -fsSL for silent failure, follow redirects, and show error for non-2xx status codes
    bash <(curl -fsSL https://get.hy2.sh/) || { echo -e "${RED}Error running Hysteria2 installation script. Please check the script output.${NC}"; return; }

    mkdir -p /etc/hysteria # Ensure config directory exists

    echo -e "${GREEN}创建 Hysteria2 配置文件 /etc/hysteria/config.yaml...${NC}"
    # This configuration uses ACME for SSL on port 443
    cat <<EOF > /etc/hysteria/config.yaml
# Hysteria2 Configuration
listen: :443 # Default Hysteria2 port, uses QUIC and TCP fallback
acme:
  domains:
    - ${hysteria_domain} # Your domain name for SSL certificate
  email: admin@${hysteria_domain} # Email for ACME notifications (optional but recommended)
auth:
  type: password
  password: "${hysteria_pass}" # Your access password
# Optional: Masquerade traffic to look like HTTPS to bing.com
masquerade:
  type: proxy
  proxy:
    url: https://bing.com
    rewriteHost: true
# Optional: Bandwidth limits (example)
# bandwidth:
#   up: 100 mbps
#   down: 1 gbps
# Optional: Disable QUIC if only TCP is needed (not recommended)
# quic:
#   enabled: false
EOF

    # Ensure the service is enabled to start on boot and start it immediately
    systemctl daemon-reload # Reload systemd manager configuration in case the install script added a new service file
    systemctl enable --now hysteria-server.service || { echo -e "${RED}Error enabling or starting Hysteria2 service. Please check service logs (journalctl -u hysteria-server).${NC}"; return; }

    echo -e "${GREEN}Hysteria2 安装完成并已启动！监听端口：443，域名：${hysteria_domain}${NC}"
    echo "请确保防火墙已放行 UDP 和 TCP 的 443 端口."
    echo "ACME 将尝试自动获取 SSL 证书。如果遇到问题，请检查日志 (journalctl -u hysteria-server) 和域名解析/端口占用情况。"
}

# --- Function to install Remote SSH Web Management (ShellHub) via Docker Compose ---
function install_shellhub() {
    echo -e "${GREEN}正在安装 ShellHub (Web SSH 管理) via Docker Compose...${NC}"
    echo "ShellHub 提供了基于 Web 的终端访问管理。"
    echo "默认 Web 界面端口: 8080, SSH Agent 连接端口: 8022."
    echo "请确保这两个端口没有被占用，并在防火墙中放行。"

    mkdir -p /opt/shellhub
    cd /opt/shellhub || { echo -e "${RED}Error changing directory to /opt/shellhub.${NC}"; return; }

    echo -e "${GREEN}创建 docker-compose.yml 文件 for ShellHub...${NC}"
    cat <<EOF > docker-compose.yml
version: '3.7' # Use a recent version
services:
  shellhub:
    image: shellhubio/ui:latest # Using ui image for dashboard
    container_name: shellhub_dashboard # Add container name for easy reference
    ports:
      - "8080:80" # Map host port 8080 to container port 80 (Web UI)
      - "8022:22" # Map host port 8022 to container port 22 (SSH for agents)
    environment:
      SHELLHUB_ENTERPRISE: "false" # Use community edition features
      SHELLHUB_API: "http://shellhub_backend:8000" # Point dashboard to backend service
    volumes:
      - shellhub_ui_data:/data # Persistent storage for dashboard data (if any, less critical than backend)
    restart: always # Ensure the container starts on boot and restarts if it fails
    depends_on: # Ensure backend is running before dashboard
      - shellhub_backend

  shellhub_backend:
    image: shellhubio/shellhub:latest # Backend service image
    container_name: shellhub_backend
    ports:
      - "8000:8000" # Expose backend API port internally (or externally if needed, but usually not recommended)
      # Note: Agent connections typically come into port 8022 mapped to the backend service
      # The shellhub/shellhub image contains both SSH server and API.
      # Let's simplify and use the standard deployment with one container if possible,
      # or use the officially recommended docker-compose which might involve more services (mongo, etc.)
      # Checking latest recommended... The official one uses multiple services.
      # Let's revert to the simpler single-container model if the dashboard image includes the backend,
      # or update to a more complete docker-compose if necessary.
      # Looking at shellhubio/dashboard:latest vs shellhubio/shellhub:latest,
      # the shellhubio/shellhub image seems to be the all-in-one or backend.
      # The dashboard image is just the UI. A minimal setup needs backend+database+UI.
      # The first script's docker-compose was oversimplified. Let's use a more standard minimal setup example.

# --- Revising ShellHub Docker Compose based on typical deployments ---
# A more standard minimal ShellHub setup requires a database (like MongoDB) and the ShellHub backend service.
# The dashboard connects to the backend.
# The single container approach in the first script might be outdated or for a specific test setup.
# Let's use a docker-compose structure closer to official examples (backend + db + ui).

    echo -e "${GREEN}Creating more complete docker-compose.yml for ShellHub (Backend + DB + UI)...${NC}"
    cat <<EOF > docker-compose.yml
version: '3.7'

services:
  # MongoDB Database Service
  mongo:
    image: mongo:latest
    container_name: shellhub_mongo
    volumes:
      - shellhub_mongo_data:/data/db # Persistent storage for MongoDB data
    restart: always
    # No ports exposed externally unless needed for debugging/access, usually not required.
    # ports:
    #   - "27017:27017"

  # ShellHub Backend Service
  shellhub_backend:
    image: shellhubio/shellhub:latest
    container_name: shellhub_backend
    ports:
      # The primary port for agents to connect (mapped from host 8022)
      # This port serves SSH and potentially other protocols used by agents.
      # The API is usually accessed internally or on a different port if needed externally.
      - "8022:22" # Map host port 8022 to container SSH port 22
      # You might expose the API port if needed, but keep it internal if possible
      # - "8000:8000" # Example API port mapping (if needed externally)
    environment:
      SHELLHUB_ENTERPRISE: "false"
      SHELLHUB_MONGO_URI: "mongodb://mongo:27017/shellhub" # Connect to the mongo service
      # Add other backend configurations if necessary
    volumes:
      - shellhub_backend_data:/data # Persistent storage for backend data (e.g., configurations)
    restart: always
    depends_on: # Ensure MongoDB is running before the backend
      - mongo

  # ShellHub UI (Dashboard) Service
  shellhub_ui:
    image: shellhubio/ui:latest
    container_name: shellhub_ui
    ports:
      - "8080:80" # Map host port 8080 to container port 80 (Web UI)
    environment:
      SHELLHUB_API: "http://shellhub_backend:8000" # Point UI to the backend service's internal address/port
    # No persistent volume needed for UI in this basic setup
    restart: always
    depends_on: # Ensure backend is running before the UI
      - shellhub_backend

# Define volumes for persistent data storage
volumes:
  shellhub_mongo_data: # Volume for MongoDB
  shellhub_backend_data: # Volume for ShellHub backend data (optional, but good practice)
  shellhub_ui_data: # Volume for ShellHub UI data (less critical)
EOF

    echo -e "${GREEN}启动 ShellHub Docker 容器 (mongo, backend, ui)...${NC}"
    # Use 'docker compose' command to build and start the services
    docker compose -f docker-compose.yml up -d || { echo -e "${RED}Error starting ShellHub containers via docker compose.${NC}"; return; }

    echo -e "${GREEN}ShellHub 安装完成并已启动！${NC}"
    echo -e "访问 ShellHub Web Dashboard 地址: http://$(curl -s ifconfig.me):8080"
    echo "首次访问需要注册用户。"
    echo "ShellHub Agent 应配置连接到本服务器的 IP 或域名，端口为 8022."
    echo "请确保防火墙已放行 TCP 端口 8080 和 8022."
}

# --- Function to install Web Management Panel (Placeholder/Note) ---
# Retained as an explanation for the menu option
function install_web_panel_note() {
    echo -e "${YELLOW}说明: '安装 FRP Web 管理面板' 选项在此脚本中是一个说明项.${NC}"
    echo -e "我们已经集成了 '安装 远程SSH Web 管理 (ShellHub)' 作为 Web 管理工具.${NC}"
    echo -e "ShellHub 提供了一个 Web 界面来管理您的远程服务器 SSH 访问.${NC}"
    echo -e "如果您需要专门的 FRP Web 面板 (例如 frp-panel), 您需要单独部署该项目，通常它会连接到您在此脚本中安装的 FRPS 后端.${NC}"
    echo ""
}


# --- Function to setup automatic configuration backup ---
function setup_backup() {
    echo -e "${GREEN}正在设置自动配置备份...${NC}"
    mkdir -p /opt/backup

    # Create or update the cron job file in /etc/cron.d
    # This cron job runs daily at 3:00 AM as root user
    # It archives configuration directories and stores the tar.gz in /opt/backup
    # Adding basic logging for backup results
    echo -e "${GREEN}创建 /etc/cron.d/config_backup 定时任务文件...${NC}"
    cat <<EOF > /etc/cron.d/config_backup
# Backup configurations daily at 3:00 AM
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/opt/frp:/opt/rustdesk # Ensure necessary paths are included
MAILTO="" # Disable email alerts for cron jobs

0 3 * * * root tar -czf /opt/backup/configs_\$(date +\%F).tar.gz /etc/hysteria /opt/frp /opt/rustdesk /opt/shellhub/docker-compose.yml $HOME/.acme.sh/ || echo "Backup failed on \$(date)" >> /var/log/backup.log 2>&1
EOF
    # Set appropriate permissions for the cron file
    chmod 0644 /etc/cron.d/config_backup

    echo -e "${GREEN}自动备份已配置！每天凌晨 3:00 将备份配置文件到 /opt/backup 目录.${NC}"
    echo "备份内容包括 Hysteria2, FRP, RustDesk, ShellHub 的 docker-compose 文件 以及 acme.sh 证书相关文件."
    echo "备份日志会记录到 /var/log/backup.log (仅记录失败情况)."
}

# --- Function to generate SSL Certificate using acme.sh ---
function generate_ssl() {
    echo -e "${GREEN}正在使用 acme.sh 申请 SSL 证书...${NC}"
    echo "此过程通常需要验证您的域名所有权。常用的验证方式是 HTTP 验证 (需要 80 或 443 端口可访问) 或 DNS 验证。"
    echo "如果您的 80 或 443 端口已被其他服务占用，HTTP 验证可能会失败。"
    echo "Hysteria2 安装时已集成 ACME 证书申请到其 443 端口，此功能主要用于其他服务（如独立的 Web 服务）需要证书的情况。"

    read -p "请输入您的域名 (例如 example.com) 用于申请证书: " DOMAIN
    if [ -z "$DOMAIN" ]; then
        echo -e "${RED}域名不能为空. SSL 证书申请中止.${NC}"
        return
    }

    # Ensure acme.sh is installed (handled in install_dependencies)
    # Ensure socat is installed (handled in install_dependencies)

    echo -e "${GREEN}尝试为 ${DOMAIN} 签发证书. 将使用 http-01 模式 (需要 80 端口).${NC}"
    echo "如果端口 80 被占用，请手动停止占用 80 端口的服务后再尝试，或考虑使用 DNS 验证模式 (更复杂，需要配置 DNS API).${NC}"

    # Issue the certificate using http-01 challenge via standalone server
    # Using the --issue command with --standalone will make acme.sh run a temporary web server on port 80.
    # This WILL conflict if another service is already using port 80.
    # A common alternative is --webroot if you have a web server serving /var/www/html,
    # or the --dns method which avoids port conflicts but requires DNS provider API access.
    # For simplicity in a general script, standalone is shown, but users should be aware of conflicts.
    # We will use the webroot method assuming a basic web server *could* be set up for validation,
    # or the user manually handles the http challenge in their web server config.
    # Let's try the standalone first, as it's simpler if ports are free. If it fails, suggest alternatives.

    # Path where acme.sh is installed (usually user's home)
    ACME_SH_PATH="$HOME/.acme.sh"

    if [ ! -d "$ACME_SH_PATH" ]; then
        echo -e "${RED}acme.sh 未找到. 请先运行 '安装依赖' 确保 acme.sh 安装成功.${NC}"
        return
    fi

    # Attempt http-01 validation using standalone
    # Note: This requires port 80 to be free temporarily!
    "$ACME_SH_PATH"/acme.sh --issue -d "$DOMAIN" --standalone || {
        echo -e "${RED}使用 http-01 独立模式签发证书失败. 原因可能是 80 端口被占用.${NC}"
        echo "请尝试以下方法:"
        echo "1. 临时停止占用 80 端口的服务，然后再次尝试此选项。"
        echo "2. 如果您运行了 Web 服务器 (如 Nginx/Apache) 且域名指向本机，考虑使用 --webroot 模式 (需要手动运行 acme.sh 命令并指定 webroot 路径)。"
        echo "3. 考虑使用 DNS 验证模式 (需要配置 DNS 提供商的 API 密钥)，这可以避免端口冲突 (需要手动运行 acme.sh 命令)。"
        echo -e "${RED}证书申请失败.${NC}"
        return
    }

    # Define target paths for certificates - standard locations
    SSL_CERT_DIR="/etc/ssl/certs"
    SSL_KEY_DIR="/etc/ssl/private"
    mkdir -p "$SSL_CERT_DIR" "$SSL_KEY_DIR" # Ensure directories exist

    echo -e "${GREEN}签发成功，正在安装证书到 ${SSL_CERT_DIR} 和 ${SSL_KEY_DIR}...${NC}"
    # Install the certificate files
    "$ACME_SH_PATH"/acme.sh --installcert -d "$DOMAIN" \
        --key-file "$SSL_KEY_DIR/$DOMAIN.key" \
        --fullchain-file "$SSL_CERT_DIR/$DOMAIN.crt" \
        --reloadcmd "echo \"证书已更新，请手动重启使用此证书的服务（如 Web 服务器）以加载新证书.\" # 例如: systemctl restart nginx" || {
        echo -e "${RED}安装 SSL 证书文件失败.${NC}"
        return
    }

    echo -e "${GREEN}SSL 证书已成功为 ${DOMAIN} 申请并安装！${NC}"
    echo "私钥文件: ${SSL_KEY_DIR}/$DOMAIN.key"
    echo "完整链证书文件: ${SSL_CERT_DIR}/$DOMAIN.crt"
    echo "请将您的 Web 服务器或其他服务配置为使用这些证书文件。"
    echo "acme.sh 将自动处理证书续期。"
}

# --- Function to start all installed services ---
function start_all_services() {
    echo -e "${GREEN}正在尝试启动所有已安装的服务...${NC}"

    echo -n "启动 RustDesk 服务: "
    # Check if the systemd service file exists before trying to start
    if systemctl list-unit-files --no-legend --no-pager | grep -q "^rustdesk.service"; then
        systemctl start rustdesk.service && echo -e "${GREEN}成功.${NC}" || echo -e "${RED}失败或已运行.${NC}"
    else
        echo -e "${YELLOW}rustdesk.service 文件不存在，RustDesk 可能未安装.${NC}"
    fi

    echo -n "启动 FRPS 服务: "
    if systemctl list-unit-files --no-legend --no-pager | grep -q "^frps.service"; then
        systemctl start frps.service && echo -e "${GREEN}成功.${NC}" || echo -e "${RED}失败或已运行.${NC}"
    else
        echo -e "${YELLOW}frps.service 文件不存在，FRP 可能未安装.${NC}"
    fi

    echo -n "启动 Hysteria2 服务: "
    if systemctl list-unit-files --no-legend --no-pager | grep -q "^hysteria-server.service"; then
        systemctl start hysteria-server.service && echo -e "${GREEN}成功.${NC}" || echo -e "${RED}失败或已运行.${NC}"
    else
        echo -e "${YELLOW}hysteria-server.service 文件不存在，Hysteria2 可能未安装.${NC}"
    fi

    echo -n "启动 ShellHub Docker 容器: "
    # Check if the docker-compose file exists before trying to start
    if [ -f "/opt/shellhub/docker-compose.yml" ]; then
        docker compose -f /opt/shellhub/docker-compose.yml up -d && echo -e "${GREEN}成功.${NC}" || echo -e "${RED}失败或已运行. 请检查 Docker 状态.${NC}"
    else
        echo -e "${YELLOW}ShellHub docker-compose.yml 文件不存在，ShellHub 可能未安装.${NC}"
    fi

    echo -e "${GREEN}启动尝试完成. 请使用 '查看服务运行状态' 检查实际运行情况.${NC}"
}


# --- Function to show service status ---
function show_status_info() {
    echo -e "${GREEN}========= 服务运行状态 =========${NC}"

    echo -n "RustDesk:    "
    if systemctl is-active rustdesk.service &>/dev/null; then
        echo -e "${GREEN}active${NC}"
    elif systemctl list-unit-files --no-legend --no-pager | grep -q "^rustdesk.service"; then
         echo -e "${RED}inactive${NC}"
    else
        echo -e "${YELLOW}未安装${NC}"
    fi


    echo -n "FRPS:        "
     if systemctl is-active frps.service &>/dev/null; then
        echo -e "${GREEN}active${NC}"
    elif systemctl list-unit-files --no-legend --no-pager | grep -q "^frps.service"; then
         echo -e "${RED}inactive${NC}"
    else
        echo -e "${YELLOW}未安装${NC}"
    fi

    echo -n "Hysteria2:   "
    if systemctl is-active hysteria-server.service &>/dev/null; then
        echo -e "${GREEN}active${NC}"
    elif systemctl list-unit-files --no-legend --no-pager | grep -q "^hysteria-server.service"; then
         echo -e "${RED}inactive${NC}"
    else
        echo -e "${YELLOW}未安装${NC}"
    fi

    echo -n "ShellHub:    "
    # Check if the shellhub_ui container is running
    if docker ps --filter "name=shellhub_ui" --filter "status=running" --format "{{.Names}}" | grep -q "shellhub_ui"; then
         echo -e "${GREEN}active (Docker)${NC}"
         # Attempt to get public IP robustly
         PUBLIC_IP=$(curl -s ifconfig.me)
         if [ -z "$PUBLIC_IP" ]; then
             PUBLIC_IP=$(curl -s api.ipify.org)
         fi
         if [ -n "$PUBLIC_IP" ]; then
             echo -e "ShellHub Web UI 地址: http://${PUBLIC_IP}:8080"
             echo "ShellHub Agent 连接端口: 8022"
         else
             echo -e "${YELLOW}无法获取公网 IP，ShellHub Web UI 地址可能是 http://服务器IP:8080${NC}"
         fi
    elif [ -f "/opt/shellhub/docker-compose.yml" ]; then
        echo -e "${RED}inactive (Docker)${NC}"
        echo "请检查 Docker 和 ShellHub 容器状态 (cd /opt/shellhub && docker compose ps)"
    else
        echo -e "${YELLOW}未安装 (Docker Compose 文件不存在)${NC}"
    fi

    echo -e "${GREEN}================================${NC}"
    echo "" # Add a newline for spacing
}

# --- Main Menu function ---
function main_menu() {
    while true; do
        echo -e "${GREEN}========= 多功能服务器一键安装/管理脚本 =========${NC}"
        echo "当前操作系统: Ubuntu 20.04 64 Bit"
        echo ""
        echo "请选择要执行的操作:"
        echo "1. 安装 RustDesk Server (远程桌面)"
        echo "2. 安装 FRP Server (内网穿透)"
        echo "3. 安装 Hysteria2 (代理/隧道)"
        echo "4. 安装 远程SSH Web 管理 (ShellHub)"
        echo "5. 设置配置自动备份 (Cron)"
        echo "6. 申请 SSL 证书 (acme.sh)"
        echo "7. 端口配置记录管理 (仅记录，不自动配置服务)"
        echo "8. 启动所有已安装的服务"
        echo "9. 查看服务运行状态"
        echo "10. 关于 'Web 管理面板' 的说明"
        echo "0. 退出脚本"
        echo -e "${GREEN}===============================================${NC}"
        read -p "请输入选项 (0-10): " CHOICE
        echo "" # Add a newline after prompt

        # Use a case statement to call the appropriate function based on user input
        case $CHOICE in
            1) install_rustdesk ;;
            2) install_frp ;;
            3) install_hysteria2 ;;
            4) install_shellhub ;;
            5) setup_backup ;;
            6) generate_ssl ;;
            7) manage_port_config ;;
            8) start_all_services ;;
            9) show_status_info ;;
            10) install_web_panel_note ;;
            0) echo -e "${GREEN}退出脚本. 再见!${NC}"; exit 0 ;;
            *) echo -e "${RED}无效的选项 '${CHOICE}'，请输入 0 到 10 之间的数字.${NC}" ;;
        esac
        echo "" # Add a newline before the menu loops again

        # Optional: Pause before showing the menu again
        # read -p "按 Enter 键返回主菜单..."
    done
}

# --- Script Execution Starts Here ---

# Check if the script is being run with root privileges
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}错误: 请使用 root 用户运行此脚本，例如: sudo bash script_name.sh${NC}"
    exit 1
fi

echo -e "${GREEN}脚本开始执行，请确保您的网络连接正常.${NC}"

# First, ensure all necessary dependencies are installed
install_dependencies

# Then, start the main menu loop
main_menu