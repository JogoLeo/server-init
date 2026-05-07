#!/bin/bash
set -euo pipefail

# ============================================================================
# JO-SI Server Init - Ubuntu 服务器初始配置脚本
# Version: 1.0.1
# Repository: https://github.com/JogoLeo/server-init
# ============================================================================

VERSION="1.0.2"
REPO_URL="https://github.com/JogoLeo/server-init"
LOG_FILE="/var/log/server-init.log"

# ── 颜色定义 ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
BOLD='\033[1m'
NC='\033[0m'

# ── 日志函数 ──
log() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $*" >> "$LOG_FILE"
}

log_info()    { echo -e "${GREEN}[INFO]${NC} $*";    log "INFO: $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*";    log "WARN: $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*";    log "ERROR: $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; log "SUCCESS: $*"; }

# ── 辅助函数 ──
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误: 此脚本必须以 root 权限运行！${NC}"
        echo "请使用: sudo bash $0"
        exit 1
    fi
}

check_network() {
    log_info "检查网络连通性..."
    if ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1 && \
       ! ping -c 1 -W 5 114.114.114.114 >/dev/null 2>&1; then
        log_warn "网络连接不可用，部分功能可能无法正常使用"
        return 1
    fi
    log_success "网络连接正常"
    return 0
}

detect_ubuntu_version() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "无法检测系统版本：/etc/os-release 不存在"
        exit 1
    fi
    source /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        log_error "此脚本仅支持 Ubuntu 系统，当前系统: $ID"
        exit 1
    fi
    UBUNTU_VERSION="$VERSION_ID"
    UBUNTU_CODENAME="$VERSION_CODENAME"
    log_info "检测到系统: Ubuntu $UBUNTU_VERSION ($UBUNTU_CODENAME)"
}

break_end() {
    echo ""
    echo -e "${GRAY}按 Enter 键继续...${NC}"
    read -r
}

confirm() {
    local message="${1:-确认执行此操作？}"
    echo -e "${YELLOW}$message [y/N]: ${NC}"
    read -r response
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

# ============================================================================
# Logo 和系统信息
# ============================================================================
show_logo() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'

    /$$$$$                               /$$                          
   |__  $$                              | $$                          
      | $$  /$$$$$$   /$$$$$$   /$$$$$$ | $$        /$$$$$$   /$$$$$$ 
      | $$ /$$__  $$ /$$__  $$ /$$__  $$| $$       /$$__  $$ /$$__  $$
 /$$  | $$| $$  \ $$| $$  \ $$| $$  \ $$| $$      | $$$$$$$$| $$  \ $$
| $$  | $$| $$  | $$| $$  | $$| $$  | $$| $$      | $$_____/| $$  | $$
|  $$$$$$/|  $$$$$$/|  $$$$$$$|  $$$$$$/| $$$$$$$$|  $$$$$$$|  $$$$$$/
 \______/  \______/  \____  $$ \______/ |________/ \_______/ \______/ 
                     /$$  \ $$                                        
                    |  $$$$$$/                                        
                     \______/                                         
EOF
    echo -e "${NC}"
    echo -e "${WHITE}  ╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}  ║${NC}  ${CYAN}Ubuntu 服务器初始配置脚本${NC}                       ${WHITE}║${NC}"
    echo -e "${WHITE}  ║${NC}  ${GRAY}Version: $VERSION${NC}                                 ${WHITE}║${NC}"
    echo -e "${WHITE}  ║${NC}  ${GRAY}GitHub: $REPO_URL${NC}  ${WHITE}║${NC}"
    echo -e "${WHITE}  ╚═══════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_system_info() {
    echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}                    系统信息概览${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"

    # 主机名
    printf "  ${GRAY}主机名:${NC}          ${WHITE}%-30s${NC}\n" "$(hostname)"

    # CPU 信息
    local cpu_model cpu_cores
    cpu_model=$(grep -m 1 "model name" /proc/cpuinfo | cut -d: -f2 | xargs)
    cpu_cores=$(nproc)
    printf "  ${GRAY}CPU:${NC}             ${WHITE}%-30s${NC}\n" "${cpu_model} (${cpu_cores} 核)"

    # 内存信息
    local mem_total mem_used mem_info
    mem_info=$(free -m | awk '/Mem:/{printf "%dMB / %dMB (%.1f%%)", $3, $2, $3/$2*100}')
    printf "  ${GRAY}内存:${NC}            ${WHITE}%-30s${NC}\n" "$mem_info"

    # 磁盘信息
    local disk_info
    disk_info=$(df -h / | awk 'NR==2{printf "%s / %s (%s)", $3, $2, $5}')
    printf "  ${GRAY}磁盘(根分区):${NC}    ${WHITE}%-30s${NC}\n" "$disk_info"

    # 系统版本
    local os_version kernel_version
    os_version=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
    kernel_version=$(uname -r)
    printf "  ${GRAY}操作系统:${NC}        ${WHITE}%-30s${NC}\n" "$os_version"
    printf "  ${GRAY}内核版本:${NC}        ${WHITE}%-30s${NC}\n" "$kernel_version"

    # SSH 端口
    local ssh_port
    ssh_port=$(grep -E "^Port " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "22")
    printf "  ${GRAY}SSH 端口:${NC}        ${WHITE}%-30s${NC}\n" "${ssh_port}"

    # 系统运行时间
    local uptime_info
    uptime_info=$(uptime -p | sed 's/up //')
    printf "  ${GRAY}运行时间:${NC}        ${WHITE}%-30s${NC}\n" "$uptime_info"

    # 公网 IP（仅首次获取）
    if [[ -z "${PUBLIC_IP_V4:-}" ]]; then
        echo ""
        echo -ne "  ${GRAY}获取公网 IP 中...${NC}"
        PUBLIC_IP_V4=$(curl -s --connect-timeout 5 --max-time 10 https://ip.sb 2>/dev/null || echo "未获取到")
        PUBLIC_IP_V6=$(curl -s --connect-timeout 5 --max-time 10 -6 https://ip.sb 2>/dev/null || echo "未获取到")
        echo -e "\r                                                          "
    fi
    printf "  ${GRAY}公网 IPv4:${NC}       ${WHITE}%-30s${NC}\n" "$PUBLIC_IP_V4"
    printf "  ${GRAY}公网 IPv6:${NC}       ${WHITE}%-30s${NC}\n" "$PUBLIC_IP_V6"

    echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
}

# ============================================================================
# 1. Ubuntu 换源（清华源）
# ============================================================================
switch_apt_source() {
    log_info "开始配置 Ubuntu APT 源（清华镜像）..."

    local source_list="/etc/apt/sources.list"
    local source_list_d="/etc/apt/sources.list.d/ubuntu.sources"
    local backup_file

    # 备份原文件
    if [[ "$UBUNTU_VERSION" < "24.04" ]]; then
        if [[ -f "$source_list" ]]; then
            backup_file="${source_list}.bak.$(date +%Y%m%d%H%M%S)"
            cp "$source_list" "$backup_file"
            log_info "已备份原配置到: $backup_file"
        fi
    else
        if [[ -f "$source_list_d" ]]; then
            backup_file="${source_list_d}.bak.$(date +%Y%m%d%H%M%S)"
            cp "$source_list_d" "$backup_file"
            log_info "已备份原配置到: $backup_file"
        fi
    fi

    # 根据版本选择格式
    if [[ "$UBUNTU_VERSION" < "24.04" ]]; then
        # Ubuntu 20.04/22.04 - 传统 One-Line-Style 格式
        log_info "使用传统 One-Line-Style 格式（/etc/apt/sources.list）"
        cat > "$source_list" << SOURCES
# 清华大学开源软件镜像站 - Ubuntu ${UBUNTU_CODENAME}
# https://mirrors.tuna.tsinghua.edu.cn/help/ubuntu/

deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME} main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME}-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME}-backports main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME}-security main restricted universe multiverse

# 源码仓库（可选）
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME} main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME}-updates main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME}-backports main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME}-security main restricted universe multiverse
SOURCES
    else
        # Ubuntu 24.04+ - DEB822 格式
        log_info "使用 DEB822 格式（/etc/apt/sources.list.d/ubuntu.sources）"
        # 确保目录存在
        mkdir -p /etc/apt/sources.list.d
        cat > "$source_list_d" << SOURCES
# 清华大学开源软件镜像站 - Ubuntu ${UBUNTU_CODENAME}
# https://mirrors.tuna.tsinghua.edu.cn/help/ubuntu/

Types: deb
URIs: https://mirrors.tuna.tsinghua.edu.cn/ubuntu
Suites: ${UBUNTU_CODENAME} ${UBUNTU_CODENAME}-updates ${UBUNTU_CODENAME}-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: https://mirrors.tuna.tsinghua.edu.cn/ubuntu
Suites: ${UBUNTU_CODENAME}-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
SOURCES
    fi

    # 清除可能存在的旧配置
    if [[ "$UBUNTU_VERSION" < "24.04" ]]; then
        rm -f /etc/apt/sources.list.d/*.list 2>/dev/null || true
    else
        rm -f /etc/apt/sources.list 2>/dev/null || true
    fi

    # 更新包索引
    log_info "正在更新包索引..."
    if apt update -y 2>&1 | tee -a "$LOG_FILE"; then
        log_success "APT 源配置完成，包索引已更新"
    else
        log_error "APT 更新失败，请检查网络连接或源配置"
        return 1
    fi
}

# ============================================================================
# 2. 安装中文语言包和字体包
# ============================================================================
install_chinese_locale() {
    log_info "开始安装中文语言包和字体..."

    # 安装语言包和字体
    log_info "安装 language-pack-zh-hans..."
    apt install -y language-pack-zh-hans 2>&1 | tee -a "$LOG_FILE"

    log_info "安装中文字体包..."
    apt install -y fonts-wqy-microhei fonts-wqy-zenhei 2>&1 | tee -a "$LOG_FILE"

    log_info "安装输入法支持包..."
    apt install -y fcitx fcitx-googlepinyin fcitx-module-cloudpinyin 2>&1 | tee -a "$LOG_FILE" || \
    apt install -y ibus-pinyin 2>&1 | tee -a "$LOG_FILE" || \
    log_warn "输入法安装失败，可能需要手动安装"

    # 更新 locale 设置
    log_info "配置 locale 设置..."
    locale-gen zh_CN.UTF-8 2>&1 | tee -a "$LOG_FILE"
    update-locale LANG=zh_CN.UTF-8 2>&1 | tee -a "$LOG_FILE"

    # 编辑 /etc/default/locale
    if [[ -f /etc/default/locale ]]; then
        sed -i 's/^LANG=.*/LANG=zh_CN.UTF-8/' /etc/default/locale
        sed -i 's/^LANGUAGE=.*/LANGUAGE=zh_CN:zh/' /etc/default/locale 2>/dev/null || true
    fi

    # 配置 vim 中文支持
    if [[ -f /etc/vim/vimrc ]]; then
        if ! grep -q "set encoding=utf-8" /etc/vim/vimrc; then
            cat >> /etc/vim/vimrc << 'VIMRC'

" 中文支持
set encoding=utf-8
set fileencodings=utf-8,gb2312,gbk,gb18030,cp936,latin1
set termencoding=utf-8
VIMRC
            log_info "已配置 vim 中文支持"
        fi
    fi

    log_success "中文语言包和字体安装完成"
    echo -e "${YELLOW}提示: 请重新登录以使 locale 设置生效${NC}"
}

# ============================================================================
# 3. SSH 登录管理
# ============================================================================
harden_ssh() {
    log_info "开始 SSH 登录管理..."

    local sshd_config="/etc/ssh/sshd_config"
    local sshd_backup="${sshd_config}.bak.$(date +%Y%m%d%H%M%S)"

    # 备份原配置
    cp "$sshd_config" "$sshd_backup"
    log_info "已备份 SSH 配置到: $sshd_backup"

    # ── 自定义 SSH 端口 ──
    echo ""
    echo -e "${CYAN}当前 SSH 端口:${NC}"
    local current_port
    current_port=$(grep -E "^Port " "$sshd_config" 2>/dev/null | awk '{print $2}' || echo "22")
    echo -e "  当前端口: ${GREEN}${current_port}${NC}"
    echo ""
    echo -e "${YELLOW}请输入新的 SSH 端口（留空保持当前端口 ${current_port}）:${NC}"
    read -r -p "端口: " new_port
    new_port=${new_port:-$current_port}

    # 验证端口号
    if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [[ "$new_port" -lt 1 ]] || [[ "$new_port" -gt 65535 ]]; then
        log_error "无效的端口号: $new_port"
        echo -e "${RED}无效的端口号，请输入 1-65535 之间的数字${NC}"
        return 1
    fi

    if [[ "$new_port" != "$current_port" ]]; then
        log_info "SSH 端口将从 $current_port 更改为 $new_port"
    fi

    # ── SSH 密钥管理 ──
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}  SSH 密钥管理${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${WHITE}1.${NC} 自动生成新的密钥对（RSA 4096位）"
    echo -e "  ${WHITE}2.${NC} 手动输入已有的公钥"
    echo -e "  ${WHITE}3.${NC} 跳过密钥配置（保持现有配置）"
    echo ""
    read -r -p "请选择 [1/2/3，默认1]: " key_choice
    key_choice=${key_choice:-1}

    # 确保 .ssh 目录和 authorized_keys 存在
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    touch /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys

    case "$key_choice" in
        1)
            # 自动生成密钥对
            log_info "生成 SSH 密钥对..."
            if [[ -f /root/.ssh/id_rsa ]]; then
                echo -e "${YELLOW}检测到已有密钥对:${NC}"
                ls -la /root/.ssh/id_rsa* 2>/dev/null
                if ! confirm "已有密钥对，是否覆盖生成新的？"; then
                    log_info "保留现有密钥对"
                else
                    ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -N "" 2>&1 | tee -a "$LOG_FILE"
                    log_success "新密钥对已生成"
                fi
            else
                ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -N "" 2>&1 | tee -a "$LOG_FILE"
                log_success "密钥对已生成"
            fi
            echo ""
            echo -e "${CYAN}当前公钥:${NC}"
            cat /root/.ssh/id_rsa.pub
            echo ""
            echo -e "${YELLOW}请保存此公钥，用于远程登录${NC}"
            ;;
        2)
            # 手动输入公钥
            echo ""
            echo -e "${YELLOW}请输入要添加的公钥（留空结束输入）:${NC}"
            while true; do
                read -r -p "公钥: " pubkey
                [[ -z "$pubkey" ]] && break
                echo "$pubkey" >> /root/.ssh/authorized_keys
                log_info "已添加公钥: ${pubkey:0:30}..."
                echo -e "${GREEN}公钥已添加${NC}"
            done
            ;;
        3)
            log_info "跳过密钥配置，保持现有配置"
            ;;
        *)
            log_warn "无效选择，跳过密钥配置"
            ;;
    esac

    # 显示当前 authorized_keys
    echo ""
    echo -e "${CYAN}当前 authorized_keys 中的公钥:${NC}"
    if [[ -s /root/.ssh/authorized_keys ]]; then
        cat /root/.ssh/authorized_keys
    else
        echo -e "${YELLOW}（空）${NC}"
    fi

    # 提示用户继续添加更多公钥
    echo ""
    echo -e "${YELLOW}是否继续添加更多公钥？（留空跳过）:${NC}"
    while true; do
        read -r -p "公钥: " pubkey
        [[ -z "$pubkey" ]] && break
        echo "$pubkey" >> /root/.ssh/authorized_keys
        log_info "已添加公钥: ${pubkey:0:30}..."
        echo -e "${GREEN}公钥已添加${NC}"
    done

    # 修改 SSH 配置
    log_info "修改 SSH 配置..."

    # 函数：修改或添加配置项
    sshd_set() {
        local key="$1" value="$2"
        if grep -qE "^#?\s*${key}\s" "$sshd_config"; then
            sed -i "s/^#*\s*${key}\s.*/${key} ${value}/" "$sshd_config"
        else
            echo "${key} ${value}" >> "$sshd_config"
        fi
    }

    # 禁用密码登录
    sshd_set "PasswordAuthentication" "no"
    sshd_set "ChallengeResponseAuthentication" "no"

    # 启用密钥登录
    sshd_set "PubkeyAuthentication" "yes"

    # 更改 SSH 端口
    sshd_set "Port" "$new_port"

    # 启用 root 用户密钥登录
    sshd_set "PermitRootLogin" "prohibit-password"

    # 配置语法检查
    log_info "检查 SSH 配置语法..."
    if sshd -t 2>&1 | tee -a "$LOG_FILE"; then
        log_success "SSH 配置语法检查通过"
    else
        log_error "SSH 配置语法检查失败，正在还原配置..."
        cp "$sshd_backup" "$sshd_config"
        return 1
    fi

    # 提示用户
    echo ""
    echo -e "${YELLOW}══════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}重要提示:${NC}"
    echo -e "  1. SSH 端口已更改为: ${CYAN}${new_port}${NC}"
    echo -e "  2. 密码登录已禁用，仅支持密钥登录"
    echo -e "  3. 请在重启 SSH 前确保已配置好密钥登录"
    echo -e "  4. 建议新开一个终端测试连接后再继续"
    echo -e "${YELLOW}══════════════════════════════════════════════════════════${NC}"
    echo ""

    if confirm "是否现在重启 SSH 服务？"; then
        # 检测 Ubuntu 版本以确定正确的重启命令
        local ssh_service="sshd"
        if [[ -f /etc/os-release ]]; then
            source /etc/os-release
            # Ubuntu 24.04+ 使用 ssh.service 而非 sshd.service
            if [[ "${VERSION_ID:-}" > "24.03" ]]; then
                ssh_service="ssh"
            fi
        fi

        # Ubuntu 22.04+ 可能启用 ssh.socket（systemd socket 激活），
        # 它会忽略 sshd_config 中的 Port 设置，必须先禁用
        if systemctl is-active --quiet ssh.socket 2>/dev/null; then
            log_info "检测到 ssh.socket 处于活动状态，正在禁用..."
            systemctl stop ssh.socket
            systemctl disable ssh.socket
            systemctl mask ssh.socket
            log_success "ssh.socket 已禁用并屏蔽"
        fi

        systemctl restart "$ssh_service"
        log_success "SSH 服务已重启，新端口: $new_port（服务名: $ssh_service）"
    else
        log_warn "SSH 服务未重启，配置将在下次重启时生效"
    fi
}

# ============================================================================
# 4. 安装 Fail2Ban SSH 防护
# ============================================================================
install_fail2ban() {
    log_info "开始安装 Fail2Ban..."

    # 安装 Fail2Ban
    apt install -y fail2ban 2>&1 | tee -a "$LOG_FILE"

    # 创建 jail.local 配置
    log_info "配置 Fail2Ban SSH 监狱..."

    # 读取当前 SSH 端口
    local ssh_port
    ssh_port=$(grep -E "^Port " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "22")

    cat > /etc/fail2ban/jail.local << FAIL2BAN
[DEFAULT]
# 默认封禁时间（秒）
bantime = 3600
# 检测时间窗口（秒）
findtime = 600
# 最大失败次数
maxretry = 5

[sshd]
enabled = true
port = $ssh_port
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600
findtime = 600
FAIL2BAN

    # 重启并启用 Fail2Ban
    systemctl restart fail2ban
    systemctl enable fail2ban

    log_success "Fail2Ban 安装配置完成"
    echo ""
    echo -e "${CYAN}Fail2Ban 状态:${NC}"
    fail2ban-client status sshd 2>&1 || true
}

# ============================================================================
# 5. 防火墙管理（UFW）
# ============================================================================
ufw_menu() {
    while true; do
        clear
        echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
        echo -e "${WHITE}                  防火墙管理（UFW）${NC}"
        echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "  ${GREEN}当前防火墙状态:${NC}"
        ufw status verbose 2>&1 | head -5
        echo ""
        echo -e "  ${WHITE}1.${NC} 开启防火墙"
        echo -e "  ${WHITE}2.${NC} 关闭防火墙"
        echo -e "  ${WHITE}3.${NC} 开放指定端口"
        echo -e "  ${WHITE}4.${NC} 关闭指定端口"
        echo -e "  ${WHITE}5.${NC} 查看当前规则"
        echo -e "  ${WHITE}0.${NC} 返回主菜单"
        echo ""
        read -e -p "请输入你的选择: " choice
        case "$choice" in
            1)
                local current_ssh_port
                current_ssh_port=$(grep -E "^Port " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "22")
                if confirm "确认开启防火墙？（将自动放行 SSH 端口 ${current_ssh_port}）"; then
                    ufw allow "${current_ssh_port}/tcp"
                    ufw --force enable
                    log_success "防火墙已开启"
                fi
                break_end
                ;;
            2)
                if confirm "⚠️  确认关闭防火墙？这将降低服务器安全性！"; then
                    ufw disable
                    log_warn "防火墙已关闭"
                fi
                break_end
                ;;
            3)
                echo -e "${YELLOW}支持格式: 单个端口(80) 或 端口范围(8000:9000)${NC}"
                read -e -p "请输入要开放的端口: " port
                if [[ -n "$port" ]]; then
                    read -e -p "协议 (tcp/udp/both，默认 tcp): " proto
                    proto=${proto:-tcp}
                    if [[ "$proto" == "both" ]]; then
                        ufw allow "$port"
                    else
                        ufw allow "$port/$proto"
                    fi
                    log_success "端口 $port ($proto) 已开放"
                fi
                break_end
                ;;
            4)
                read -e -p "请输入要关闭的端口: " port
                if [[ -n "$port" ]]; then
                    read -e -p "协议 (tcp/udp/both，默认 tcp): " proto
                    proto=${proto:-tcp}
                    if [[ "$proto" == "both" ]]; then
                        ufw delete allow "$port"
                    else
                        ufw delete allow "$port/$proto"
                    fi
                    log_success "端口 $port ($proto) 已关闭"
                fi
                break_end
                ;;
            5)
                echo ""
                ufw status numbered
                break_end
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                break_end
                ;;
        esac
    done
}

manage_firewall() {
    log_info "进入防火墙管理..."
    # 确保 UFW 已安装
    if ! command -v ufw &>/dev/null; then
        log_info "安装 UFW..."
        apt install -y ufw 2>&1 | tee -a "$LOG_FILE"
    fi
    ufw_menu
}

# ============================================================================
# 6. Linux 内核参数优化
# ============================================================================
_get_mem_mb() {
    awk '/MemTotal/{printf "%d", $2/1024}' /proc/meminfo
}

_kernel_optimize_core() {
    local mode_name="$1"
    local scene="${2:-high}"
    local CONF="/etc/sysctl.d/99-server-init-optimize.conf"
    local MEM_MB
    MEM_MB=$(_get_mem_mb)

    echo -e "${GREEN}切换到 ${mode_name}...${NC}"

    # ── 根据场景设定参数 ──
    local SWAPPINESS DIRTY_RATIO DIRTY_BG_RATIO OVERCOMMIT MIN_FREE_KB VFS_PRESSURE
    local RMEM_MAX WMEM_MAX TCP_RMEM TCP_WMEM
    local SOMAXCONN BACKLOG SYN_BACKLOG
    local PORT_RANGE SCHED_AUTOGROUP THP NUMA FIN_TIMEOUT
    local KEEPALIVE_TIME KEEPALIVE_INTVL KEEPALIVE_PROBES

    case "$scene" in
        high|stream|game)
            SWAPPINESS=10
            DIRTY_RATIO=15
            DIRTY_BG_RATIO=5
            OVERCOMMIT=1
            VFS_PRESSURE=50
            RMEM_MAX=67108864
            WMEM_MAX=67108864
            TCP_RMEM="4096 262144 67108864"
            TCP_WMEM="4096 262144 67108864"
            SOMAXCONN=8192
            BACKLOG=250000
            SYN_BACKLOG=8192
            PORT_RANGE="1024 65535"
            SCHED_AUTOGROUP=0
            THP="never"
            NUMA=0
            FIN_TIMEOUT=10
            KEEPALIVE_TIME=300
            KEEPALIVE_INTVL=30
            KEEPALIVE_PROBES=5
            ;;
        web)
            SWAPPINESS=10
            DIRTY_RATIO=20
            DIRTY_BG_RATIO=10
            OVERCOMMIT=1
            VFS_PRESSURE=50
            RMEM_MAX=33554432
            WMEM_MAX=33554432
            TCP_RMEM="4096 131072 33554432"
            TCP_WMEM="4096 131072 33554432"
            SOMAXCONN=16384
            BACKLOG=10000
            SYN_BACKLOG=16384
            PORT_RANGE="1024 65535"
            SCHED_AUTOGROUP=0
            THP="never"
            NUMA=0
            FIN_TIMEOUT=15
            KEEPALIVE_TIME=600
            KEEPALIVE_INTVL=60
            KEEPALIVE_PROBES=5
            ;;
        balanced)
            SWAPPINESS=30
            DIRTY_RATIO=20
            DIRTY_BG_RATIO=10
            OVERCOMMIT=0
            VFS_PRESSURE=75
            RMEM_MAX=16777216
            WMEM_MAX=16777216
            TCP_RMEM="4096 87380 16777216"
            TCP_WMEM="4096 65536 16777216"
            SOMAXCONN=4096
            BACKLOG=5000
            SYN_BACKLOG=4096
            PORT_RANGE="1024 49151"
            SCHED_AUTOGROUP=1
            THP="always"
            NUMA=1
            FIN_TIMEOUT=30
            KEEPALIVE_TIME=600
            KEEPALIVE_INTVL=60
            KEEPALIVE_PROBES=5
            ;;
    esac

    # ── 根据内存大小自适应调整 ──
    if [[ "$MEM_MB" -ge 16384 ]]; then
        MIN_FREE_KB=131072
        [[ "$scene" != "balanced" ]] && SWAPPINESS=5
    elif [[ "$MEM_MB" -ge 4096 ]]; then
        MIN_FREE_KB=65536
    elif [[ "$MEM_MB" -ge 1024 ]]; then
        MIN_FREE_KB=32768
        if [[ "$scene" != "balanced" ]]; then
            RMEM_MAX=16777216
            WMEM_MAX=16777216
            TCP_RMEM="4096 87380 16777216"
            TCP_WMEM="4096 65536 16777216"
        fi
    else
        MIN_FREE_KB=16384
        SWAPPINESS=30
        OVERCOMMIT=0
        RMEM_MAX=4194304
        WMEM_MAX=4194304
        TCP_RMEM="4096 32768 4194304"
        TCP_WMEM="4096 32768 4194304"
        SOMAXCONN=1024
        BACKLOG=1000
    fi

    # ── 直播场景额外：UDP 缓冲区加大 ──
    local STREAM_EXTRA=""
    if [[ "$scene" == "stream" ]]; then
        STREAM_EXTRA="
# 直播推流 UDP 优化
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384
net.ipv4.tcp_notsent_lowat = 16384"
    fi

    # ── 游戏服场景额外：低延迟优先 ──
    local GAME_EXTRA=""
    if [[ "$scene" == "game" ]]; then
        GAME_EXTRA="
# 游戏服低延迟优化
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_slow_start_after_idle = 0"
    fi

    # ── 加载 BBR 模块 ──
    local CC="bbr"
    local QDISC="fq"
    local KVER
    KVER=$(uname -r | grep -oP '^\d+\.\d+')
    if printf '%s\n%s' "4.9" "$KVER" | sort -V -C; then
        if ! lsmod 2>/dev/null | grep -q tcp_bbr; then
            modprobe tcp_bbr 2>/dev/null
        fi
        if ! sysctl net.ipv4.tcp_available_congestion_control 2>/dev/null | grep -q bbr; then
            CC="cubic"
            QDISC="fq_codel"
        fi
    else
        CC="cubic"
        QDISC="fq_codel"
    fi

    # ── 备份已有配置 ──
    [[ -f "$CONF" ]] && cp "$CONF" "${CONF}.bak.$(date +%s)"

    # ── 写入配置文件（持久化） ──
    echo -e "${GREEN}写入优化配置...${NC}"
    cat > "$CONF" << SYSCTL
# server-init 内核调优配置
# 模式: $mode_name | 场景: $scene
# 内存: ${MEM_MB}MB | 生成时间: $(date '+%Y-%m-%d %H:%M:%S')

# ── TCP 拥塞控制 ──
net.core.default_qdisc = $QDISC
net.ipv4.tcp_congestion_control = $CC

# ── TCP 缓冲区 ──
net.core.rmem_max = $RMEM_MAX
net.core.wmem_max = $WMEM_MAX
net.core.rmem_default = $(echo "$TCP_RMEM" | awk '{print $2}')
net.core.wmem_default = $(echo "$TCP_WMEM" | awk '{print $2}')
net.ipv4.tcp_rmem = $TCP_RMEM
net.ipv4.tcp_wmem = $TCP_WMEM

# ── 连接队列 ──
net.core.somaxconn = $SOMAXCONN
net.core.netdev_max_backlog = $BACKLOG
net.ipv4.tcp_max_syn_backlog = $SYN_BACKLOG

# ── TCP 连接优化 ──
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = $FIN_TIMEOUT
net.ipv4.tcp_keepalive_time = $KEEPALIVE_TIME
net.ipv4.tcp_keepalive_intvl = $KEEPALIVE_INTVL
net.ipv4.tcp_keepalive_probes = $KEEPALIVE_PROBES
net.ipv4.tcp_max_tw_buckets = 65536
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 3
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_window_scaling = 1

# ── 端口与内存 ──
net.ipv4.ip_local_port_range = $PORT_RANGE
net.ipv4.tcp_mem = $((MEM_MB * 1024 / 8)) $((MEM_MB * 1024 / 4)) $((MEM_MB * 1024 / 2))
net.ipv4.tcp_max_orphans = 32768

# ── 虚拟内存 ──
vm.swappiness = $SWAPPINESS
vm.dirty_ratio = $DIRTY_RATIO
vm.dirty_background_ratio = $DIRTY_BG_RATIO
vm.overcommit_memory = $OVERCOMMIT
vm.min_free_kbytes = $MIN_FREE_KB
vm.vfs_cache_pressure = $VFS_PRESSURE

# ── CPU/内核调度 ──
kernel.sched_autogroup_enabled = $SCHED_AUTOGROUP
$([ -f /proc/sys/kernel/numa_balancing ] && echo "kernel.numa_balancing = $NUMA" || echo "# numa_balancing 不支持")

# ── 安全防护 ──
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# ── 文件描述符 ──
fs.file-max = 1048576
fs.nr_open = 1048576

# ── 连接跟踪 ──
$(if [[ -f /proc/sys/net/netfilter/nf_conntrack_max ]]; then
echo "net.netfilter.nf_conntrack_max = $((SOMAXCONN * 32))"
echo "net.netfilter.nf_conntrack_tcp_timeout_established = 7200"
echo "net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30"
echo "net.netfilter.nf_conntrack_tcp_timeout_close_wait = 15"
echo "net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 15"
else
echo "# conntrack 未启用"
fi)
$STREAM_EXTRA
$GAME_EXTRA
SYSCTL

    # ── 应用配置（逐行，跳过不支持的参数） ──
    echo -e "${GREEN}应用优化参数...${NC}"
    local applied=0 skipped=0
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// /}" ]] && continue
        if sysctl -w "$line" >/dev/null 2>&1; then
            applied=$((applied + 1))
        else
            skipped=$((skipped + 1))
        fi
    done < "$CONF"
    echo -e "${GREEN}已应用 ${applied} 项参数${skipped:+，跳过 ${skipped} 项不支持的参数}${NC}"

    # ── 透明大页面 ──
    if [[ -f /sys/kernel/mm/transparent_hugepage/enabled ]]; then
        echo "$THP" > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null
    fi

    # ── 文件描述符限制 ──
    if ! grep -q "# server-init-optimize" /etc/security/limits.conf 2>/dev/null; then
        cat >> /etc/security/limits.conf << 'LIMITS'

# server-init-optimize
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
LIMITS
    fi

    # ── BBR 持久化 ──
    if [[ "$CC" == "bbr" ]]; then
        echo "tcp_bbr" > /etc/modules-load.d/bbr.conf 2>/dev/null
        sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf 2>/dev/null
    fi

    echo -e "${GREEN}${mode_name} 优化完成！配置已持久化到 ${CONF}${NC}"
    echo -e "${GREEN}内存: ${MEM_MB}MB | 拥塞算法: ${CC} | 队列: ${QDISC}${NC}"
}

restore_kernel_defaults() {
    echo -e "${GREEN}还原到默认设置...${NC}"

    local CONF="/etc/sysctl.d/99-server-init-optimize.conf"

    rm -f "$CONF"
    rm -f /etc/sysctl.d/99-network-optimize.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf 2>/dev/null
    sysctl --system 2>/dev/null | tail -1

    [[ -f /sys/kernel/mm/transparent_hugepage/enabled ]] && \
        echo always > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null

    if grep -q "# server-init-optimize" /etc/security/limits.conf 2>/dev/null; then
        sed -i '/# server-init-optimize/,+4d' /etc/security/limits.conf
    fi

    rm -f /etc/modules-load.d/bbr.conf 2>/dev/null

    echo -e "${GREEN}系统已还原到默认设置${NC}"
}

optimize_kernel() {
    while true; do
        clear
        echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
        echo -e "${WHITE}              Linux 系统内核参数优化${NC}"
        echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"

        local current_mode
        current_mode=$(grep "^# 模式:" /etc/sysctl.d/99-server-init-optimize.conf 2>/dev/null | sed 's/# 模式: //' | awk -F'|' '{print $1}' | xargs)
        if [[ -n "$current_mode" ]]; then
            echo -e "  当前模式: ${GREEN}${current_mode}${NC}"
        else
            echo -e "  当前模式: ${GRAY}未优化${NC}"
        fi

        echo ""
        echo -e "  提供多种系统参数调优模式，用户可以根据自身使用场景进行选择切换。"
        echo -e "  ${YELLOW}提示: 生产环境请谨慎使用！${NC}"
        echo ""
        echo -e "  ${WHITE}1.${NC} 高性能优化模式：     最大化系统性能，激进的内存和网络参数"
        echo -e "  ${WHITE}2.${NC} 均衡优化模式：       在性能与资源消耗之间取得平衡，适合日常使用"
        echo -e "  ${WHITE}3.${NC} 网站优化模式：       针对网站服务器优化，超高并发连接队列"
        echo -e "  ${WHITE}4.${NC} 直播优化模式：       针对直播推流优化，UDP 缓冲区加大，减少延迟"
        echo -e "  ${WHITE}5.${NC} 游戏服优化模式：     针对游戏服务器优化，低延迟优先"
        echo -e "  ${WHITE}6.${NC} 还原默认设置：       将系统设置还原为默认配置"
        echo -e "  ${WHITE}0.${NC} 返回主菜单"
        echo ""
        read -e -p "请输入你的选择: " sub_choice
        case $sub_choice in
            1)
                _kernel_optimize_core "高性能优化模式" "high"
                break_end
                ;;
            2)
                _kernel_optimize_core "均衡优化模式" "balanced"
                break_end
                ;;
            3)
                _kernel_optimize_core "网站搭建优化模式" "web"
                break_end
                ;;
            4)
                _kernel_optimize_core "直播优化模式" "stream"
                break_end
                ;;
            5)
                _kernel_optimize_core "游戏服优化模式" "game"
                break_end
                ;;
            6)
                restore_kernel_defaults
                break_end
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                break_end
                ;;
        esac
    done
}

# ============================================================================
# 7. BBR + FQ 加速
# ============================================================================
enable_bbr_fq() {
    log_info "开始配置 BBR + FQ 加速..."

    # 检测内核版本
    local kver
    kver=$(uname -r | grep -oP '^\d+\.\d+')

    if ! printf '%s\n%s' "4.9" "$kver" | sort -V -C; then
        log_error "当前内核版本 $kver 过低，BBR 需要 4.9 或更高版本"
        echo -e "${RED}当前内核版本 $kver 不支持 BBR，需要 4.9 或更高版本${NC}"
        return 1
    fi

    echo -e "${CYAN}当前内核版本: ${kver}${NC}"
    echo ""

    # 显示当前状态
    echo -e "${WHITE}当前网络加速状态:${NC}"
    local current_cc current_qdisc
    current_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "未知")
    current_qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null || echo "未知")
    echo -e "  拥塞控制算法: ${GREEN}${current_cc}${NC}"
    echo -e "  队列调度算法: ${GREEN}${current_qdisc}${NC}"
    echo ""

    # 检查 BBR 模块
    if ! lsmod 2>/dev/null | grep -q tcp_bbr; then
        log_info "加载 tcp_bbr 模块..."
        modprobe tcp_bbr 2>/dev/null || true
    fi

    # 检查 BBR 是否可用
    if ! sysctl net.ipv4.tcp_available_congestion_control 2>/dev/null | grep -q bbr; then
        log_error "BBR 不可用"
        echo -e "${RED}BBR 模块不可用，请检查内核是否编译了 BBR 支持${NC}"
        return 1
    fi

    # 备份当前配置
    local conf="/etc/sysctl.d/99-bbr-fq.conf"
    [[ -f "$conf" ]] && cp "$conf" "${conf}.bak.$(date +%s)"

    # 写入配置
    log_info "写入 BBR + FQ 配置..."
    cat > "$conf" << 'BBRCONF'
# BBR + FQ 加速配置
# 由 server-init 生成

# 启用 BBR 拥塞控制算法
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# TCP 快速打开
net.ipv4.tcp_fastopen = 3

# 启用 TCP SACK
net.ipv4.tcp_sack = 1

# 启用 TCP 窗口缩放
net.ipv4.tcp_window_scaling = 1

# 启用 TCP 时间戳
net.ipv4.tcp_timestamps = 1

# 优化 TCP Keepalive
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 5
BBRCONF

    # 应用配置
    log_info "应用优化参数..."
    local applied=0 skipped=0
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// /}" ]] && continue
        if sysctl -w "$line" >/dev/null 2>&1; then
            applied=$((applied + 1))
        else
            skipped=$((skipped + 1))
        fi
    done < "$conf"
    echo -e "${GREEN}已应用 ${applied} 项参数${skipped:+，跳过 ${skipped} 项不支持的参数}${NC}"

    # 持久化 BBR 模块
    echo "tcp_bbr" > /etc/modules-load.d/bbr.conf 2>/dev/null

    # 验证
    echo ""
    echo -e "${CYAN}配置后状态:${NC}"
    local new_cc new_qdisc
    new_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "未知")
    new_qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null || echo "未知")
    echo -e "  拥塞控制算法: ${GREEN}${new_cc}${NC}"
    echo -e "  队列调度算法: ${GREEN}${new_qdisc}${NC}"

    if [[ "$new_cc" == "bbr" && "$new_qdisc" == "fq" ]]; then
        log_success "BBR + FQ 加速配置完成"
        echo -e "${GREEN}BBR + FQ 加速已启用！${NC}"
    else
        log_warn "BBR + FQ 配置可能未完全生效"
        echo -e "${YELLOW}BBR + FQ 配置可能未完全生效，请检查内核配置${NC}"
    fi
}

disable_bbr_fq() {
    log_info "还原 BBR + FQ 配置..."

    local conf="/etc/sysctl.d/99-bbr-fq.conf"
    rm -f "$conf"

    # 还原为默认
    sysctl -w net.core.default_qdisc=fq_codel >/dev/null 2>&1 || true
    sysctl -w net.ipv4.tcp_congestion_control=cubic >/dev/null 2>&1 || true

    rm -f /etc/modules-load.d/bbr.conf 2>/dev/null

    log_success "BBR + FQ 配置已还原"
    echo -e "${GREEN}已还原为默认网络设置${NC}"
}

bbr_fq_menu() {
    while true; do
        clear
        echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
        echo -e "${WHITE}                BBR + FQ 网络加速${NC}"
        echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
        echo ""

        # 显示当前状态
        local current_cc current_qdisc
        current_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "未知")
        current_qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null || echo "未知")
        echo -e "  当前拥塞控制算法: ${GREEN}${current_cc}${NC}"
        echo -e "  当前队列调度算法: ${GREEN}${current_qdisc}${NC}"
        echo ""
        echo -e "${CYAN}──────────────────────────────────────────────────────────${NC}"
        echo -e "  BBR 是 Google 开发的 TCP 拥塞控制算法，配合 FQ 队列调度"
        echo -e "  可以显著提升网络吞吐量和降低延迟，特别适合远距离传输。"
        echo -e "${CYAN}──────────────────────────────────────────────────────────${NC}"
        echo ""
        echo -e "  ${WHITE}1.${NC} 启用 BBR + FQ 加速"
        echo -e "  ${WHITE}2.${NC} 还原默认设置"
        echo -e "${CYAN}──────────────────────────────────────────────────────────${NC}"
        echo -e "  ${WHITE}0.${NC} 返回主菜单"
        echo -e "${CYAN}──────────────────────────────────────────────────────────${NC}"
        read -e -p "请输入你的选择: " choice
        case "$choice" in
            1)
                enable_bbr_fq
                break_end
                ;;
            2)
                disable_bbr_fq
                break_end
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                break_end
                ;;
        esac
    done
}

# ============================================================================
# 8. DNS 优化
# ============================================================================
set_dns() {
    local dns1_ipv4="$1" dns2_ipv4="$2"
    local dns1_ipv6="${3:-}" dns2_ipv6="${4:-}"

    # 备份
    if [[ -f /etc/resolv.conf ]]; then
        cp /etc/resolv.conf "/etc/resolv.conf.bak.$(date +%Y%m%d%H%M%S)"
    fi

    # 解锁文件
    chattr -i /etc/resolv.conf 2>/dev/null || true

    # 清空并写入新配置
    : > /etc/resolv.conf
    echo "nameserver $dns1_ipv4" >> /etc/resolv.conf
    echo "nameserver $dns2_ipv4" >> /etc/resolv.conf
    if [[ -n "$dns1_ipv6" ]]; then
        echo "nameserver $dns1_ipv6" >> /etc/resolv.conf
    fi
    if [[ -n "$dns2_ipv6" ]]; then
        echo "nameserver $dns2_ipv6" >> /etc/resolv.conf
    fi

    # 锁定文件
    chattr +i /etc/resolv.conf 2>/dev/null || true

    log_success "DNS 已更新: $dns1_ipv4, $dns2_ipv4"
}

optimize_dns() {
    while true; do
        clear
        echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
        echo -e "${WHITE}                    DNS 优化${NC}"
        echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "  当前 DNS 地址:"
        cat /etc/resolv.conf 2>/dev/null || echo "  （无法读取）"
        echo ""
        echo -e "${CYAN}──────────────────────────────────────────────────────────${NC}"
        echo -e "  ${WHITE}1.${NC} 国外 DNS 优化"
        echo -e "     v4: 1.1.1.1 8.8.8.8"
        echo -e "     v6: 2606:4700:4700::1111 2001:4860:4860::8888"
        echo -e "  ${WHITE}2.${NC} 国内 DNS 优化"
        echo -e "     v4: 223.5.5.5 183.60.83.19"
        echo -e "     v6: 2400:3200::1 2400:da00::6666"
        echo -e "  ${WHITE}3.${NC} 手动编辑 DNS 配置"
        echo -e "${CYAN}──────────────────────────────────────────────────────────${NC}"
        echo -e "  ${WHITE}0.${NC} 返回主菜单"
        echo -e "${CYAN}──────────────────────────────────────────────────────────${NC}"
        read -e -p "请输入你的选择: " choice
        case "$choice" in
            1)
                set_dns "1.1.1.1" "8.8.8.8" "2606:4700:4700::1111" "2001:4860:4860::8888"
                echo -e "${GREEN}国外 DNS 优化完成${NC}"
                break_end
                ;;
            2)
                set_dns "223.5.5.5" "183.60.83.19" "2400:3200::1" "2400:da00::6666"
                echo -e "${GREEN}国内 DNS 优化完成${NC}"
                break_end
                ;;
            3)
                chattr -i /etc/resolv.conf 2>/dev/null || true
                if command -v nano &>/dev/null; then
                    nano /etc/resolv.conf
                else
                    apt install -y nano && nano /etc/resolv.conf
                fi
                chattr +i /etc/resolv.conf 2>/dev/null || true
                echo -e "${GREEN}DNS 配置已手动更新${NC}"
                break_end
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                break_end
                ;;
        esac
    done
}

# ============================================================================
# 9. 限流自动关机
# ============================================================================
rate_limit_shutdown() {
    while true; do
        clear
        echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
        echo -e "${WHITE}                    限流关机功能${NC}"
        echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "  当前流量使用情况（重启服务器流量计算会清零）："
        echo ""

        # 显示流量信息
        if [[ -d /sys/class/net ]]; then
            for iface in /sys/class/net/*/statistics; do
                local iface_name
                iface_name=$(echo "$iface" | cut -d/ -f5)
                [[ "$iface_name" == "lo" ]] && continue
                local rx_bytes tx_bytes
                rx_bytes=$(cat "$iface/rx_bytes" 2>/dev/null || echo 0)
                tx_bytes=$(cat "$iface/tx_bytes" 2>/dev/null || echo 0)
                local rx_gb tx_gb
                rx_gb=$(awk "BEGIN {printf \"%.2f\", $rx_bytes/1073741824}")
                tx_gb=$(awk "BEGIN {printf \"%.2f\", $tx_bytes/1073741824}")
                echo -e "  ${CYAN}网卡: ${iface_name}${NC}"
                echo -e "  总接收: ${rx_gb}GB"
                echo -e "  总发送: ${tx_gb}GB"
                echo ""
            done
        fi

        # 检查是否存在限流配置
        if [[ -f ~/Limiting_Shut_down.sh ]]; then
            local rx_threshold_gb tx_threshold_gb
            rx_threshold_gb=$(grep -oP 'rx_threshold_gb=\K\d+' ~/Limiting_Shut_down.sh 2>/dev/null || echo "未设置")
            tx_threshold_gb=$(grep -oP 'tx_threshold_gb=\K\d+' ~/Limiting_Shut_down.sh 2>/dev/null || echo "未设置")
            echo -e "  ${GREEN}当前设置的进站限流阈值为: ${YELLOW}${rx_threshold_gb}${GREEN}G${NC}"
            echo -e "  ${GREEN}当前设置的出站限流阈值为: ${YELLOW}${tx_threshold_gb}${GREEN}GB${NC}"
        else
            echo -e "  ${GRAY}当前未启用限流关机功能${NC}"
        fi

        echo ""
        echo -e "${CYAN}──────────────────────────────────────────────────────────${NC}"
        echo -e "  系统每分钟会检测实际流量是否到达阈值，到达后会自动关闭服务器！"
        echo -e "${CYAN}──────────────────────────────────────────────────────────${NC}"
        echo -e "  ${WHITE}1.${NC} 开启限流关机功能"
        echo -e "  ${WHITE}2.${NC} 停用限流关机功能"
        echo -e "${CYAN}──────────────────────────────────────────────────────────${NC}"
        echo -e "  ${WHITE}0.${NC} 返回主菜单"
        echo -e "${CYAN}──────────────────────────────────────────────────────────${NC}"
        read -e -p "请输入你的选择: " choice

        case "$choice" in
            1)
                echo -e "${YELLOW}如果实际服务器就 100G 流量，可设置阈值为 95G，提前关机，以免出现流量误差或溢出。${NC}"
                read -e -p "请输入进站流量阈值（单位为 G，默认 100G）: " rx_threshold_gb
                rx_threshold_gb=${rx_threshold_gb:-100}
                read -e -p "请输入出站流量阈值（单位为 G，默认 100G）: " tx_threshold_gb
                tx_threshold_gb=${tx_threshold_gb:-100}
                read -e -p "请输入流量重置日期（默认每月 1 日重置）: " cz_day
                cz_day=${cz_day:-1}

                # 创建限流脚本
                cat > ~/Limiting_Shut_down.sh << 'LIMITING'
#!/bin/bash
# 限流自动关机脚本

# 从网络接口获取流量（字节）
get_traffic() {
    local rx_total=0
    local tx_total=0
    for iface in /sys/class/net/*/statistics; do
        local iface_name
        iface_name=$(echo "$iface" | cut -d/ -f5)
        [[ "$iface_name" == "lo" ]] && continue
        rx_total=$((rx_total + $(cat "$iface/rx_bytes" 2>/dev/null || echo 0)))
        tx_total=$((tx_total + $(cat "$iface/tx_bytes" 2>/dev/null || echo 0)))
    done
    echo "$rx_total $tx_total"
}

# 阈值（GB 转换为字节）
rx_threshold_gb=100
tx_threshold_gb=100
rx_threshold=$((rx_threshold_gb * 1073741824))
tx_threshold=$((tx_threshold_gb * 1073741824))

# 获取当前流量
read rx_bytes tx_bytes <<< $(get_traffic)

# 检查是否超过阈值
if [[ $rx_bytes -ge $rx_threshold ]] || [[ $tx_bytes -ge $tx_threshold ]]; then
    echo "$(date): 流量超过阈值，执行关机" >> /var/log/rate-limit-shutdown.log
    /sbin/shutdown -h +1 "流量超过阈值，即将关机"
fi
LIMITING

                chmod +x ~/Limiting_Shut_down.sh

                # 替换阈值
                sed -i "s/rx_threshold_gb=100/rx_threshold_gb=$rx_threshold_gb/" ~/Limiting_Shut_down.sh
                sed -i "s/tx_threshold_gb=100/tx_threshold_gb=$tx_threshold_gb/" ~/Limiting_Shut_down.sh

                # 配置 crontab
                crontab -l 2>/dev/null | grep -v '~/Limiting_Shut_down.sh' | grep -v 'reboot' | crontab - 2>/dev/null || true
                (crontab -l 2>/dev/null; echo "* * * * * ~/Limiting_Shut_down.sh"; echo "0 1 $cz_day * * /sbin/reboot") | crontab - > /dev/null 2>&1

                echo -e "${GREEN}限流关机已设置${NC}"
                break_end
                ;;
            2)
                crontab -l 2>/dev/null | grep -v '~/Limiting_Shut_down.sh' | grep -v 'reboot' | crontab - 2>/dev/null || true
                rm -f ~/Limiting_Shut_down.sh
                echo -e "${GREEN}已关闭限流关机功能${NC}"
                break_end
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                break_end
                ;;
        esac
    done
}

# ============================================================================
# 10. 一键安装 x-ui 面板
# ============================================================================
install_xui() {
    echo -e "${YELLOW}══════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}注意: 此脚本来自第三方（yonggekkk/x-ui-yg），请确认您信任该来源${NC}"
    echo -e "${YELLOW}══════════════════════════════════════════════════════════${NC}"
    echo ""

    if confirm "确认安装 x-ui 面板？"; then
        log_info "开始安装 x-ui 面板..."

        # 在子 shell 中执行，防止外部脚本的 exit 导致主脚本退出
        (
            if command -v wget &>/dev/null; then
                bash <(wget -qO- https://gh-proxy.org/https://raw.githubusercontent.com/yonggekkk/x-ui-yg/main/install.sh)
            elif command -v curl &>/dev/null; then
                bash <(curl -sSL https://gh-proxy.org/https://raw.githubusercontent.com/yonggekkk/x-ui-yg/main/install.sh)
            else
                echo -e "${RED}错误: 未找到 wget 或 curl，请先安装${NC}"
                exit 1
            fi
        )

        local exit_code=$?
        if [[ $exit_code -eq 0 ]]; then
            log_success "x-ui 面板安装完成"
        else
            log_error "x-ui 面板安装异常，退出码: $exit_code"
        fi
    fi
}

# ============================================================================
# 11. 一键安装 Docker
# ============================================================================
install_docker() {
    if confirm "确认安装 Docker？"; then
        log_info "开始安装 Docker..."
        bash <(curl -sSL https://xuanyuan.cloud/docker.sh)
        log_success "Docker 安装完成"
    fi
}

# ============================================================================
# 12. Docker 镜像源配置
# ============================================================================
configure_docker_mirror() {
    while true; do
        clear
        echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
        echo -e "${WHITE}                  Docker 镜像源配置${NC}"
        echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "  当前 Docker 配置:"
        if [[ -f /etc/docker/daemon.json ]]; then
            cat /etc/docker/daemon.json
        else
            echo -e "  ${GRAY}（无自定义配置）${NC}"
        fi
        echo ""
        echo -e "${CYAN}──────────────────────────────────────────────────────────${NC}"
        echo -e "  ${WHITE}1.${NC} 更换为 https://docker.1ms.run"
        echo -e "  ${WHITE}2.${NC} 执行 1ms 一键换源脚本"
        echo -e "  ${WHITE}3.${NC} 手动输入自定义加速源地址"
        echo -e "${CYAN}──────────────────────────────────────────────────────────${NC}"
        echo -e "  ${WHITE}0.${NC} 返回主菜单"
        echo -e "${CYAN}──────────────────────────────────────────────────────────${NC}"
        read -e -p "请输入你的选择: " choice

        case "$choice" in
            1)
                if confirm "确认更换 Docker 镜像源为 docker.1ms.run？"; then
                    mkdir -p /etc/docker
                    cat > /etc/docker/daemon.json << 'DOCKER'
{
    "registry-mirrors": ["https://docker.1ms.run"]
}
DOCKER
                    systemctl daemon-reload
                    systemctl restart docker
                    log_success "Docker 镜像源已更换为 docker.1ms.run"
                fi
                break_end
                ;;
            2)
                if confirm "确认执行 1ms 一键换源脚本？"; then
                    sudo bash -c "$(curl -sSL https://n3.ink/helper)"
                    log_success "1ms 一键换源完成"
                fi
                break_end
                ;;
            3)
                echo -e "${YELLOW}提示: 可前往 https://cr.console.aliyun.com/ 查看阿里云 Docker 加速源地址${NC}"
                echo ""
                read -e -p "请输入自定义加速源地址: " custom_mirror
                if [[ -n "$custom_mirror" ]]; then
                    mkdir -p /etc/docker
                    cat > /etc/docker/daemon.json << DOCKER
{
    "registry-mirrors": ["$custom_mirror"]
}
DOCKER
                    systemctl daemon-reload
                    systemctl restart docker
                    log_success "Docker 镜像源已更换为 $custom_mirror"
                fi
                break_end
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                break_end
                ;;
        esac
    done
}

# ============================================================================
# 13. 版本管理与更新
# ============================================================================
show_version() {
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}  当前版本: ${GREEN}v${VERSION}${NC}"
    echo -e "${WHITE}  仓库地址: ${CYAN}${REPO_URL}${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
}

check_update() {
    log_info "检查更新..."
    echo -e "${CYAN}正在从 GitHub 检查更新...${NC}"

    # 获取最新版本
    local latest_version
    latest_version=$(curl -sL "https://raw.githubusercontent.com/JogoLeo/server-init/main/server-init.sh" 2>/dev/null | grep '^VERSION=' | head -1 | cut -d'"' -f2)

    if [[ -z "$latest_version" ]]; then
        log_warn "无法获取最新版本信息，请检查网络连接"
        echo -e "${YELLOW}无法获取最新版本信息${NC}"
        return 1
    fi

    echo -e "  当前版本: ${GREEN}v${VERSION}${NC}"
    echo -e "  最新版本: ${GREEN}v${latest_version}${NC}"

    if [[ "$latest_version" != "$VERSION" ]]; then
        echo ""
        if confirm "发现新版本 v${latest_version}，是否更新？"; then
            log_info "正在下载最新版本..."
            local script_path
            script_path=$(realpath "$0")
            local backup_path="${script_path}.bak.$(date +%Y%m%d%H%M%S)"
            cp "$script_path" "$backup_path"
            log_info "已备份当前版本到: $backup_path"

            curl -sL "https://raw.githubusercontent.com/JogoLeo/server-init/main/server-init.sh" -o "$script_path"
            chmod +x "$script_path"
            log_success "更新完成，请重新运行脚本"
            echo -e "${GREEN}更新完成！请重新运行脚本以使用新版本${NC}"
            exit 0
        fi
    else
        echo -e "${GREEN}当前已是最新版本${NC}"
    fi
}

version_menu() {
    while true; do
        clear
        echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
        echo -e "${WHITE}                  版本管理与更新${NC}"
        echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "  ${WHITE}1.${NC} 检查更新"
        echo -e "  ${WHITE}2.${NC} 查看当前版本"
        echo -e "${CYAN}──────────────────────────────────────────────────────────${NC}"
        echo -e "  ${WHITE}0.${NC} 返回主菜单"
        echo -e "${CYAN}──────────────────────────────────────────────────────────${NC}"
        read -e -p "请输入你的选择: " choice
        case "$choice" in
            1)
                check_update
                break_end
                ;;
            2)
                show_version
                break_end
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                break_end
                ;;
        esac
    done
}

# ============================================================================
# 主菜单
# ============================================================================
main_menu() {
    while true; do
        clear
        show_logo
        show_system_info

        echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
        echo -e "${WHITE}                      主菜单${NC}"
        echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "  ${WHITE} 1.${NC}  Ubuntu 换源（清华源）"
        echo -e "  ${WHITE} 2.${NC}  安装中文语言包和字体包"
        echo -e "  ${WHITE} 3.${NC}  SSH 登录管理"
        echo -e "  ${WHITE} 4.${NC}  安装 Fail2Ban SSH 防护"
        echo -e "  ${WHITE} 5.${NC}  防火墙管理（UFW）"
        echo -e "  ${WHITE} 6.${NC}  Linux 内核参数优化"
        echo -e "  ${WHITE} 7.${NC}  BBR + FQ 加速"
        echo -e "  ${WHITE} 8.${NC}  DNS 优化"
        echo -e "  ${WHITE} 9.${NC}  限流自动关机"
        echo -e "  ${WHITE}10.${NC}  一键安装 x-ui 面板"
        echo -e "  ${WHITE}11.${NC}  一键安装 Docker"
        echo -e "  ${WHITE}12.${NC}  Docker 镜像源配置"
        echo -e "  ${WHITE}13.${NC}  版本管理与更新"
        echo -e "  ${WHITE} 0.${NC}  退出脚本"
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
        echo -e "  ${GRAY}按 R 刷新公网 IP，按 0 退出${NC}"
        echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
        echo ""
        read -e -p "请输入你的选择: " choice

        case "$choice" in
            1)  switch_apt_source;      break_end ;;
            2)  install_chinese_locale; break_end ;;
            3)  harden_ssh;             break_end ;;
            4)  install_fail2ban;       break_end ;;
            5)  manage_firewall;        break_end ;;
            6)  optimize_kernel;        ;;
            7)  bbr_fq_menu;           ;;
            8)  optimize_dns;           ;;
            9)  rate_limit_shutdown;    ;;
            10) install_xui;            break_end ;;
            11) install_docker;         break_end ;;
            12) configure_docker_mirror ;;
            13) version_menu;           ;;
            [rR])
                PUBLIC_IP_V4=""
                PUBLIC_IP_V6=""
                echo -e "${GREEN}公网 IP 已刷新${NC}"
                break_end
                ;;
            0)
                echo -e "${GREEN}感谢使用，再见！${NC}"
                log_info "用户退出脚本"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入${NC}"
                break_end
                ;;
        esac
    done
}

# ============================================================================
# 脚本入口
# ============================================================================
main() {
    # 检查 root 权限
    check_root

    # 初始化日志
    mkdir -p /var/log
    touch "$LOG_FILE"
    log_info "脚本启动，版本: $VERSION"

    # 检测系统版本
    detect_ubuntu_version

    # 检查网络
    check_network || true

    # 显示主菜单
    main_menu
}

# 运行主函数
main "$@"
