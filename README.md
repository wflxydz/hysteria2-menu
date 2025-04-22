第一步：
sudo apt update
sudo apt install curl -y

第二步：
wget https://raw.githubusercontent.com/wflxydz/hysteria2-menu/main/hysteria2-menu.sh
chmod +x hysteria2-menu.sh
./hysteria2-menu.sh
一键安装 Hysteria2

自动生成配置文件

自签证书 / ACME 自动签发证书可选

启动、停止、重启、查看状态、查看日志等操作

设置开机自启

端口443
提前设置域名并绑定ip


以下是一键集成安装脚本的最终版本，包含以下功能：

✅ 功能总览：
安装 RustDesk Server（可选端口、自定义域名）

安装 FRP（支持自定义端口，含新版 TOML 配置）

安装 Hysteria2（支持 ACME 或自签，SSL 自动配置）

安装 FRP Web 管理面板

自动备份配置文件

查看所有服务状态（含 IP/端口展示）

远程 SSH 可视化管理（ShellHub）

退出菜单
