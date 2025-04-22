提前设置域名并绑定ip

第一步：
sudo apt update
sudo apt install curl -y

第二步：
wget https://raw.githubusercontent.com/wflxydz/hysteria2-menu/main/install-all.sh

chmod +x install-all.sh

./install-all.sh

一键安装 RustDesk Server+FRP+Hysteria2


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

将上述脚本保存为 install-all.sh 文件。

赋予执行权限：chmod +x install-all.sh

执行脚本：./install-all.sh

选择菜单并进行相关操作，支持安装多个服务、管理多个端口配置。
