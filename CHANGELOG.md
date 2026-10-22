# Changelog

All notable changes to this project will be documented in this file.

## [1.3.1] - 2026-10-22

### Fixed

- **Reality 目标域名检测**：修复缺少 `unzip` 时执行 `apt-get install` 卡住（无任何输出）的问题。原因为未关闭 needrestart/debconf 交互且输出被重定向。现在改为：
  - 优先使用系统已有的 `unzip` / `python3` / `bsdtar` / `busybox` 解压，绝大多数机器无需安装任何包
  - 仅当全部不可用时提示手动安装命令，并询问是否自动安装
  - 自动安装改为非交互模式（`DEBIAN_FRONTEND=noninteractive` + `NEEDRESTART_MODE=a`）并加 `timeout 180` 兜底
- **仓库**：`.gitignore` 补充 `.workbuddy/`，避免本地记忆与内网信息被误提交

## [1.3.0] - 2026-10-22

### Added

- **BBR + FQ 加速**：内嵌 [ylx2016/Linux-NetSpeed](https://github.com/ylx2016/Linux-NetSpeed) 的 `tcpx.sh`（3057 行，md5 `48ce47a1dfdf0aba5299dd7685a31367`），运行时释放到 `/tmp` 执行。支持 BBR / BBRplus / LotServer / 内核更换，解决国内拉取 `raw.githubusercontent.com` 失败导致 BBR 开启不稳定的问题；原「内置快速开启」保留为子菜单第 2 项
- **Reality 目标域名检测**（菜单 14）：集成 [V2RaySSR/RealityChecker](https://github.com/V2RaySSR/RealityChecker)，自动识别架构、下载 release（gh-proxy 优先，失败回退直连），支持单域名 / 批量 / CSV 三种模式
- **IP 质量体检**（菜单 15）：调用 [xykt/IPQuality](https://github.com/xykt/IPQuality)（`IP.Check.Place`），检测 IP 原生性、欺诈评分、流媒体解锁、回程路由等

### Fixed

- **SSH 登录管理（Ubuntu 26.04）**：26.04 默认启用 `ssh.socket` socket 激活，端口由 socket 的 `ListenStream` 决定，原「mask ssh.socket + 重启 ssh.service」做法会报错，且 mask 后重启有失联风险。现改为写入 `/etc/systemd/system/ssh.socket.d/10-server-init-port.conf` 覆盖监听端口，`daemon-reload` 后重启 `ssh.socket`；经典服务模式仍直接重启 `ssh.service`/`sshd.service`
- **SSH 登录管理**：重启后自动用 `ss -tlnp` 校验新端口监听状态，失败时输出 `systemctl status` 诊断信息
- **SSH 登录管理**：改用 `KbdInteractiveAuthentication no`，并清理旧配置中的 `ChallengeResponseAuthentication`（OpenSSH 10 已废弃）

## [1.2.1] - 2026-07-20

### Fixed

- **SSH 登录管理**：修复 Ubuntu 22.04（容器 / 重启后 /run 为 tmpfs 被清空）重启 SSH 时报 `Missing privilege separation directory: /run/sshd` 的问题。新增 `_ensure_sshd_privsep_dir` 函数，在语法检查与重启前自动创建 `/run/sshd`，并在系统无 openssh 自带 tmpfiles 配置时写入 `/etc/tmpfiles.d` 持久化配置，避免重启后复发

## [1.2.0] - 2026-05-08

### Changed

- **全功能**：新增 Debian 系统支持（Debian 11+），原仅支持 Ubuntu
- **APT 换源**：适配 Debian 清华镜像源，自动按系统类型生成对应源配置
- **SSH 登录管理**：SSH 服务名检测改为自动识别（`systemctl list-unit-files`），兼容 Debian
- **中文语言包**：Debian 使用 `locales` 包替代 Ubuntu 专属的 `language-pack-zh-hans`
- **系统检测**：函数重命名为 `detect_os`，`UBUNTU_VERSION`/`UBUNTU_CODENAME` 改为 `OS_VERSION`/`OS_CODENAME`

### Fixed

- 修复所有 `grep -oP` 为 `grep -oE` 或 `grep + sed` 组合，兼容 Debian 环境
- 修复更新检查和脚本下载未使用 `gh-proxy.org` 代理的问题

## [1.1.0] - 2026-05-07

### Fixed

- **脚本框架**：移除 `set -e`，避免命令失败时直接退出脚本
- **版本显示**：修复 `source /etc/os-release` 覆盖脚本 `VERSION` 变量导致版本显示为系统版本的问题（变量重命名为 `SCRIPT_VERSION`）
- **版本检查**：修复更新检查和脚本下载未使用 `gh-proxy.org` 代理导致国内无法访问的问题
- **BBR + FQ 加速**：优化 BBR 检测逻辑，优先检查内置模块支持，兼容 `grep -oP` 不可用的环境
- **SSH 登录管理**：添加公钥前检查是否已存在，避免重复公钥导致 xshell 无法登录
- **SSH 登录管理**：修复 `>=` 运算符在 bash `[[ ]]` 条件表达式中不合法导致的语法错误
- **SSH 登录管理**：修复 Ubuntu 22.04+ 下修改端口后不生效的问题（禁用 `ssh.socket`）


## [1.0.1] - 2026-05-02

### Changed

- **SSH 登录管理**（原"SSH 安全加固"）：
  - 支持自定义 SSH 端口（默认 22，用户可自行输入）
  - 密钥对支持用户手动输入公钥或自动生成
  - 修复 Ubuntu 24.04 下 SSH 重启命令（使用 `ssh` 替代 `sshd`）
- **x-ui 面板安装**：所有安装逻辑已内置到脚本中，不再依赖外部脚本链接

### Added

- **BBR+FQ 加速**：新增独立菜单项，一键启用 BBR 拥塞控制 + FQ 队列调度

## [1.0.0] - 2026-04-30

### Added

- 初始版本发布
- Ubuntu APT 换源（清华源）
- 中文语言包和字体包安装
- SSH 安全加固
- Fail2Ban 安装配置
- UFW 防火墙管理
- Linux 内核参数优化（高性能/均衡/网站/直播/游戏）
- DNS 优化
- 限流自动关机
- x-ui 面板一键安装
- Docker 安装与镜像源配置
- 版本管理与更新
