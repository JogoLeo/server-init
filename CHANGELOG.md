# Changelog

All notable changes to this project will be documented in this file.

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
