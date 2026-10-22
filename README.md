# JO-SI Server Init

Debian/Ubuntu 服务器初始配置脚本，用于在新装 Debian 或 Ubuntu 服务器上快速完成初始配置。

## 功能列表

| 序号 | 功能 | 说明 |
|------|------|------|
| 1 | APT 换源（清华源） | 自动检测系统版本（Ubuntu/Debian），配置清华大学开源软件镜像站 |
| 2 | 安装中文语言包和字体包 | 安装中文支持、字体和输入法（兼容 Debian） |
| 3 | SSH 登录管理 | 自定义端口、密钥管理、自动检测 SSH 服务名 |
| 4 | 安装 Fail2Ban | SSH 暴力破解防护 |
| 5 | 防火墙管理（UFW） | 开启/关闭防火墙、管理端口规则 |
| 6 | Linux 内核参数优化 | 多种优化模式：高性能/均衡/网站/直播/游戏 |
| 7 | BBR + FQ 加速 | 内嵌 NetSpeed（BBR/BBRplus/LotServer + 内核管理），另有内置快速开启 |
| 8 | DNS 优化 | 国内外 DNS 快速切换 |
| 9 | 限流自动关机 | 流量超限自动关机，适合流量计费服务器 |
| 10 | 一键安装 x-ui 面板 | 第三方 x-ui 面板安装 |
| 11 | 一键安装 Docker | Docker 引擎安装 |
| 12 | Docker 镜像源配置 | 配置 Docker 镜像加速 |
| 13 | 版本管理与更新 | 检查更新、查看版本 |
| 14 | Reality 目标域名检测 | 检测域名是否适合作为 Reality 目标（TLS1.3/X25519/CDN/被墙） |
| 15 | IP 质量体检 | IP 类型、欺诈评分、流媒体解锁、回程路由（IP.Check.Place） |

## 系统要求

- **操作系统**: Debian 11+ / Ubuntu 20.04 / 22.04 / 24.04 / 26.04
- **权限**: root 用户
- **网络**: 需要互联网连接

## 使用方法

### 1. 下载并运行

```bash
# 克隆仓库
git clone https://gh-proxy.org/https://github.com/JogoLeo/server-init.git
cd server-init

# 添加执行权限
chmod +x server-init.sh

# 以 root 权限运行
sudo bash server-init.sh
```

### 2. 或者直接下载运行

```bash
# 下载脚本
wget https://gh-proxy.org/https://raw.githubusercontent.com/JogoLeo/server-init/main/server-init.sh

# 添加执行权限
chmod +x server-init.sh

# 运行
sudo bash server-init.sh
```

### 3.curl运行

```bash
bash <(curl -sL https://gh-proxy.org/https://raw.githubusercontent.com/JogoLeo/server-init/main/server-init.sh)
```

### 4.wget运行

```bash
bash <(wget -qO- https://gh-proxy.org/https://raw.githubusercontent.com/JogoLeo/server-init/main/server-init.sh)
```
## 功能详细说明

### 1. APT 换源（清华源）

- 自动检测系统类型（Ubuntu/Debian）和版本代号
- **Debian**: 使用传统 One-Line-Style 格式（`/etc/apt/sources.list`），清华 Debian 镜像源
- **Ubuntu < 24.04**: 使用传统 One-Line-Style 格式（`/etc/apt/sources.list`）
- **Ubuntu 24.04+**: 使用 DEB822 格式（`/etc/apt/sources.list.d/ubuntu.sources`）
- 换源前自动备份原文件（带时间戳）
- 换源后自动执行 `apt update`

### 2. 安装中文语言包和字体包

- **Ubuntu**: 安装 `language-pack-zh-hans` 中文语言包
- **Debian**: 安装 `locales` 包
- 安装 `fonts-wqy-microhei`、`fonts-wqy-zenhei` 中文字体
- 安装输入法支持包（fcitx/ibus）
- 更新 locale 设置为 `zh_CN.UTF-8`
- 配置 vim 中文支持
- 完成后提示用户重新登录生效

### 3. SSH 登录管理

- 自定义 SSH 端口（默认 22，用户可自行输入）
- 密钥管理：自动生成新密钥对 / 手动输入公钥 / 跳过（自动检测重复公钥）
- 禁用密码登录：`PasswordAuthentication no`
- 启用密钥登录：`PubkeyAuthentication yes`
- 启用 root 密钥登录：`PermitRootLogin prohibit-password`
- 自动检测 SSH 服务名（`ssh.service` 或 `sshd.service`），兼容 Debian/Ubuntu
- **自动识别 systemd socket 激活**（Ubuntu 24.04+/26.04、Debian 13+ 默认启用）：
  - socket 模式下通过 `ssh.socket.d` drop-in 覆盖 `ListenStream` 切换端口
  - 执行 `daemon-reload` 后重启 `ssh.socket`，不再采用 mask 掉 socket 的旧做法（26.04 上会失败并可能导致重启失联）
  - 经典服务模式下直接重启 `ssh.service` / `sshd.service`
- 重启后自动校验新端口监听状态（`ss -tlnp`），失败时打印 `systemctl status` 诊断
- 使用 `KbdInteractiveAuthentication no`（OpenSSH 10 已废弃 `ChallengeResponseAuthentication`）
- 自动创建 SSH 特权分离目录 `/run/sshd`，避免容器 / 重启后出现 `Missing privilege separation directory` 错误
- 配置修改前自动备份
- 重启前进行配置语法检查（`sshd -t`）
- 提示用户保持当前连接并测试新连接

### 4. 安装 Fail2Ban

- 自动安装 Fail2Ban
- 自动读取当前 SSH 端口配置
- 配置 SSH 监狱：
  - 端口：自动适配 SSH 端口
  - 最大失败次数：5 次
  - 封禁时间：1 小时
  - 检测时间窗口：10 分钟
- 启动并设置开机自启

### 5. 防火墙管理（UFW）

子菜单功能：
1. 开启防火墙（自动放行当前 SSH 端口）
2. 关闭防火墙（需二次确认）
3. 开放指定端口（支持单个端口和端口范围）
4. 关闭指定端口
5. 查看当前规则
0. 返回主菜单

### 6. Linux 内核参数优化

提供 6 种优化模式：
- **高性能优化模式**: 最大化系统性能，激进的内存和网络参数
- **均衡优化模式**: 在性能与资源消耗之间取得平衡，适合日常使用
- **网站优化模式**: 针对网站服务器优化，超高并发连接队列
- **直播优化模式**: 针对直播推流优化，UDP 缓冲区加大，减少延迟
- **游戏服优化模式**: 针对游戏服务器优化，低延迟优先
- **还原默认设置**: 将系统设置还原为默认配置

主要优化内容：
- TCP 拥塞控制（BBR）
- TCP 缓冲区优化
- 连接队列优化
- 虚拟内存优化
- 文件描述符限制
- 安全防护参数

### 7. BBR + FQ 加速

子菜单功能：
1. **NetSpeed 增强菜单（内嵌）**：把 [ylx2016/Linux-NetSpeed](https://github.com/ylx2016/Linux-NetSpeed) 的 `tcpx.sh` 原样内嵌进本脚本，运行时释放到 `/tmp` 执行。支持 BBR / BBRplus / LotServer、更换内核、开启原始 BBR 等，解决国内直连 `raw.githubusercontent.com` 失败导致 BBR 开不起来的问题
2. **快速启用 BBR + FQ（内置）**：纯 `sysctl` 实现，秒级生效，适合内核已内置 BBR 的机器
3. **还原默认设置**：恢复 `fq_codel` + `cubic`

内置快速开启包含：
- 自动检测内核版本（需要 4.9+）
- 启用 BBR 拥塞控制算法 + FQ 队列调度
- 配置 TCP 快速打开、SACK、窗口缩放、Keepalive
- 配置持久化，重启后生效

> 内嵌快照：2026-10-22，3057 行，md5 `48ce47a1dfdf0aba5299dd7685a31367`。更换内核类操作会修改 GRUB 启动项，OpenVZ/LXC 等共享内核环境不支持。

### 8. DNS 优化

- 国外 DNS 优化: 1.1.1.1, 8.8.8.8
- 国内 DNS 优化: 223.5.5.5, 183.60.83.19
- 手动编辑 DNS 配置
- 使用 `chattr +i` 锁定 `/etc/resolv.conf` 防止被覆盖

### 9. 限流自动关机

- 设置进站/出站流量阈值（单位 GB）
- 设置流量重置日期（每月自动重启）
- 通过 crontab 每分钟检测流量
- 超过阈值自动关机

### 10. 一键安装 x-ui 面板

执行命令：
```bash
bash <(wget -qO- https://gh-proxy.org/https://raw.githubusercontent.com/yonggekkk/x-ui-yg/main/install.sh)
```

### 11. 一键安装 Docker

执行命令：
```bash
bash <(curl -sSL https://xuanyuan.cloud/docker.sh)
```

### 12. Docker 镜像源配置

子菜单功能：
1. 更换为 `https://docker.1ms.run`
2. 执行 1ms 一键换源脚本
3. 手动输入自定义加速源地址

配置文件位置：`/etc/docker/daemon.json`

### 13. 版本管理与更新

- 检查更新：从 GitHub 拉取最新版本
- 查看当前版本
- 仓库地址：https://github.com/JogoLeo/server-init

### 14. Reality 目标域名检测

基于 [V2RaySSR/RealityChecker](https://github.com/V2RaySSR/RealityChecker)，用于挑选适合做 REALITY `dest` 的域名。

- 自动识别架构（x86_64 / arm64），下载对应 release 到 `/opt/reality-checker`
- 解压优先使用系统已有工具（`unzip` / `python3` / `bsdtar` / `busybox`），**绝大多数机器无需额外安装**
- 全部工具都缺失时，给出手动安装命令并可选自动安装（非交互模式，带超时保护）
- 优先走 `gh-proxy.org`，失败自动回退直连 GitHub
- 支持三种模式：
  - 单域名：`reality-checker check example.com`
  - 批量：输入多个域名，空格分隔
  - CSV：输入文件路径（配合 RealiTLScanner 扫描结果）
- 检测项：TLS 1.3 / X25519 / HTTP2、证书与 SNI 匹配、CDN 特征、地理位置、是否被墙、是否热门站点
- 输入 `u` 更新程序

### 15. IP 质量体检

调用 [xykt/IPQuality](https://github.com/xykt/IPQuality)（`IP.Check.Place`）做 IP 质量体检。

- 检测内容：IP 类型与原生性、欺诈评分、流媒体/DNS/邮件端口、三网回程路由与延迟、TikTok / ChatGPT / Netflix 可用性
- 脚本下载到 `/tmp` 执行，执行完自动清理
- 等价于手动执行：`bash <(curl -sL IP.Check.Place)`

## 日志

所有操作记录保存在 `/var/log/server-init.log`

## 注意事项

1. **首次使用前请仔细阅读每个功能的说明**
2. **SSH 加固前请确保已配置好密钥登录**
3. **修改 SSH 端口后请新开终端测试连接**
4. **生产环境请谨慎使用内核参数优化**
5. **限流关机功能会自动重启服务器，请确保设置正确**
6. **部分功能需要从第三方下载脚本，请确认来源可信**

## 卸载

如需卸载本脚本配置的某些功能：

### 还原 APT 源
```bash
# 恢复备份的 sources.list
sudo cp /etc/apt/sources.list.bak.* /etc/apt/sources.list
sudo apt update
```

### 还原 SSH 配置
```bash
# 恢复备份的 sshd_config
sudo cp /etc/ssh/sshd_config.bak.* /etc/ssh/sshd_config
sudo systemctl restart sshd
```

### 还原内核参数
在脚本菜单中选择 "6. Linux 内核参数优化" → "6. 还原默认设置"

### 停用 BBR + FQ
在脚本菜单中选择 "7. BBR + FQ 加速" → "2. 还原默认设置"

### 停用限流关机
在脚本菜单中选择 "9. 限流自动关机" → "2. 停用限流关机功能"

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request！

## 作者

JogoLeo - https://github.com/JogoLeo
