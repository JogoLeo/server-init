# Changelog

All notable changes to this project will be documented in this file.

## [1.0.2] - 2026-05-07

### Fixed

- **SSH 登录管理**：修复 `>=` 运算符在 bash `[[ ]]` 条件表达式中不合法导致的语法错误（Ubuntu 版本判断）

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
