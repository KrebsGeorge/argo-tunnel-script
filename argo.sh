#!/bin/bash

# 控制台字体
red(){
    echo -e "\033[31m\033[01m$1\033[0m";
}

green(){
    echo -e "\033[32m\033[01m$1\033[0m";
}

yellow(){
    echo -e "\033[33m\033[01m$1\033[0m";
}

# 判断系统及定义系统安装依赖方式
REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS" "Alpine")
PACKAGE_UPDATE=("apt -y update" "apt -y update" "yum -y update" "yum -y update")
PACKAGE_REMOVE=("apt -y remove" "apt -y remove" "yum -y remove" "yum -y remove")
ARCH=`uname -m`

# 判断是否为root用户
[[ $EUID -ne 0 ]] && yellow "请在root用户下运行脚本" && exit 1

# 检测系统，本部分代码感谢fscarmen的指导
CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')")

for i in "${CMD[@]}"; do
    SYS="$i" && [[ -n $SYS ]] && break
done

for ((int=0; int<${#REGEX[@]}; int++)); do
    [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]] && SYSTEM="${RELEASE[int]}" && [[ -n $SYSTEM ]] && break
done

[[ -z $SYSTEM ]] && red "不支持VPS的当前系统，请使用主流的操作系统" && exit 1

install(){
    if [[ -n $(cloudflared -help) ]]; then
        red "检测到已安装CloudFlare Argo Tunnel，无需重复安装！！"
        exit 0
    fi
    ${PACKAGE_UPDATE[int]}
    if [ $ARCH = "x86_64" ]; then
        ARCH="amd64"
    fi
    if [ $RELEASE == "CentOS" ]; then
        wget -N https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}.rpm
        rpm -i cloudflared-linux-${ARCH}.rpm
    else
        wget -N https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}.deb
        dpkg -i cloudflared-linux-${ARCH}.deb
    fi
}

tryTunnel(){
    if [[ -z $(cloudflared -help) ]]; then
        red "检测到未安装CloudFlare Argo Tunnel客户端，无法执行操作！！！"
    fi
    read -p "请输入你需要穿透的http端口号（默认80）：" httpPort
    if [ -z $httpPort ]; then
        httpPort=80
    fi
    cloudflared tunnel --url localhost:$httpPort
}

cfargoLogin(){
    if [[ -z $(cloudflared -help) ]]; then
        red "检测到未安装CloudFlare Argo Tunnel客户端，无法执行操作！！！"
    fi
    if [[ -f /root/.cloudflared/cert.pem ]]; then
        red "已登录CloudFlare Argo Tunnel客户端，无需重复登录！！！"
    fi
    green "请访问下方提示的网址，登录自己的CloudFlare账号"
    green "然后授权自己的域名给CloudFlare Argo Tunnel即可"
    cloudflared tunnel login
}

tunnelSelection(){
    if [[ -z $(cloudflared -help) ]]; then
        red "检测到未安装CloudFlare Argo Tunnel客户端，无法执行操作！！！"
    fi
    echo "1. 创建隧道"
    echo "2. 删除隧道"
    echo "3. 配置隧道"
    echo "4. 列出隧道"
    read -p "请输入选项:" tunnelNumberInput
    case "$menuNumberInput" in
        1 ) read -p "请输入需要创建的隧道名称：" tunnelName && cloudflared tunnel create $tunnelName ;;
        2 ) read -p "请输入需要删除的隧道名称：" tunnelName && cloudflared tunnel delete $tunnelName ;;
        3 ) read -p "请输入需要配置的隧道名称：" tunnelName && read -p "请输入需要配置的域名：" tunnelDomain && cloudflared tunnel route dns $tunnelName $tunnelDomain ;;
        4 ) cloudflared tunnel list ;;
        0 ) exit 0
    esac
}

runTunnel(){
    if [[ -z $(cloudflared -help) ]]; then
        red "检测到未安装CloudFlare Argo Tunnel客户端，无法执行操作！！！"
    fi
    read -p "请输入需要运行的隧道名称：" tunnelName
    read -p "请输入你需要穿透的http端口号（默认80）：" httpPort
    if [ -z $httpPort ]; then
        httpPort=80
    fi
    cloudflared tunnel run --url localhost:$httpPort $tunnelName
}

menu(){
    clear
    red "=================================="
    echo "                           "
    red "  CloudFlare Argo Tunnel一键脚本   "
    red "          by 小御坂的破站           "
    echo "                           "
    red "  Site: https://owo.misaka.rest  "
    echo "                           "
    red "=================================="
    echo "            "
    echo "1. 安装CloudFlare Argo Tunnel客户端"
    echo "2. 体验CloudFlare Argo Tunnel隧道"
    echo "3. 登录CloudFlare Argo Tunnel客户端"
    echo "4. 创建、删除、配置和列出隧道"
    echo "5. 运行隧道"
    echo "6. 卸载CloudFlare Argo Tunnel客户端"
    read -p "请输入选项:" menuNumberInput
    case "$menuNumberInput" in
        1 ) install ;;
        2 ) tryTunnel ;;
        3 ) cfargoLogin ;;
        4 ) tunnelSelection ;;
        5 ) runTunnel ;;
        6 ) ${PACKAGE_REMOVE[int]} cloudflared ;;
        0 ) exit 0
    esac
}

menu
