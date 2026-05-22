# AGENTS.md

## 项目概述

这是一个用于管理 SoftEther VPN Server 的中文交互式 Bash 工具。

项目目标是提供类似 pvetools 的命令行菜单体验，用于在 Ubuntu / Debian VPS 上管理 SoftEther VPN Server，重点支持 L2TP/IPsec PSK 使用场景。

核心脚本：

- `softether-tools.sh`

该脚本通过 SoftEther 官方命令行工具 `vpncmd` 执行管理操作。

## 目标用户

目标用户是中文用户，常见运行环境为：

- Oracle Cloud / 普通 Ubuntu VPS
- 已安装 SoftEther VPN Server
- SoftEther 安装目录为 `/usr/local/vpnserver`
- 使用默认虚拟 Hub：`DEFAULT`
- 使用 L2TP/IPsec PSK 方式连接
- 客户端使用系统内置 VPN 配置，不依赖 WireGuard、Tailscale 或 OpenVPN 客户端

## 主要功能

脚本应支持：

1. 查看用户列表
2. 新增用户
3. 删除用户
4. 修改用户密码
5. 查看在线会话
6. 查看 L2TP/IPsec 配置
7. 修改预共享密钥 PSK
8. 查看 SoftEther 服务状态
9. 重启 SoftEther 服务
10. 打印客户端配置模板
11. 查看 SoftEther 监听端口

## 技术约束

必须遵守以下约束：

- 使用 Bash 编写。
- 不引入 Web 面板。
- 不引入 Node.js、Python Web 框架或数据库。
- 不使用 expect，除非用户明确要求。
- 不保存 SoftEther 管理员密码到文件。
- 管理员密码应在脚本启动时通过隐藏输入读取。
- 不将管理员密码打印到终端。
- 不将管理员密码写入日志。
- `vpncmd` 路径默认为 `/usr/local/vpnserver/vpncmd`。
- 默认 SoftEther 服务器连接地址为 `localhost`。
- 默认 Hub 为 `DEFAULT`。
- 默认客户端类型为 `L2TP/IPsec PSK`。
- 不要使用 `set -e`，因为菜单工具不应因单个命令失败直接退出。
- 可以使用 `set -u`。
- 子命令失败时，应提示错误并返回菜单。

## vpncmd 使用规则

SoftEther `vpncmd` 的模式很重要，必须遵守以下规则。

### 不要这样做

不要使用以下方式配合 Server 管理员密码管理 Hub：

```bash
vpncmd localhost /SERVER /PASSWORD:xxx /HUB:DEFAULT /CMD UserList
```

原因：

- `/HUB:DEFAULT` 会进入 Virtual Hub Admin Mode。
- 该模式需要的是 Hub 管理密码，不是 Server 管理员密码。
- 这会导致 `Access has been denied` 或进入交互式 `Password:` 提示。

### 正确方式

应先以 Server 管理模式连接，再在命令文件中执行：

```text
Hub DEFAULT
UserList
exit
```

所有涉及 Hub 的操作都应使用这种形式：

```text
Hub DEFAULT
具体命令
exit
```

例如新增用户：

```text
Hub DEFAULT
UserCreate username /GROUP:none /REALNAME:none /NOTE:none
exit
```

例如修改用户密码：

```text
Hub DEFAULT
UserPasswordSet username /PASSWORD:password
exit
```

例如删除用户：

```text
Hub DEFAULT
UserDelete username
exit
```

例如查看在线会话：

```text
Hub DEFAULT
SessionList
exit
```

## 不要破坏的行为

请不要改坏以下行为：

- 脚本启动后先隐藏输入 SoftEther Server 管理员密码。
- 选择 `1) 查看用户列表` 时，不应再出现 `vpncmd` 自己的 `Password:` 提示。
- 管理员密码不应明文显示。
- 管理员密码不应写入文件。
- 菜单返回时可以清屏，但功能输出必须在用户按回车前可见。
- 新增用户成功后，必须打印如下格式：

```text
类型：L2TP/IPsec PSK
服务器：<PUBLIC_IP>
用户名：<username>
密码：<password>
预共享密钥：<DEFAULT_PSK>
```

## 安全要求

- 不要把真实服务器 IP、真实 PSK、真实管理员密码硬编码到示例文档中。
- README 中应使用占位符，例如：

```bash
PUBLIC_IP="your_server_ip"
DEFAULT_PSK="change_me"
```

- 如果脚本内存在默认值，应在 README 中提醒用户修改。
- 不要建议把 SoftEther 管理端口 `5555` 暴露到公网。
- 推荐通过 SSH、Tailscale 或内网管理服务器。
- 每个 VPN 用户应使用独立用户名和独立密码。
- PSK 是全局共享密钥，修改 PSK 后所有客户端都需要同步修改。
- 不要把管理员密码、VPN 用户密码、真实 PSK 写入仓库。

## 代码风格

- 保持 Bash 脚本简单、可读。
- 保持中文菜单和中文提示。
- `vpncmd` 原始输出可以保留英文，不要强行翻译。
- 每个功能使用独立函数。
- 尽量避免复杂依赖。
- 不新增后台服务。
- 不新增 Web 管理端口。
- 不引入数据库。
- 不自动修改系统防火墙，除非用户明确要求。
- 不自动修改云厂商安全组，脚本只负责 SoftEther 管理。

## README 要求

README 应包含：

- 项目简介
- 功能列表
- 环境要求
- 安装方式
- 使用方式
- 变量配置说明
- L2TP/IPsec 客户端配置说明
- 云服务器端口放行说明
- 安全建议
- 常见问题
- 卸载说明

## 推荐仓库结构

建议保持如下结构：

```text
softether-tools/
├── README.md
├── softether-tools.sh
├── install.sh
├── LICENSE
├── AGENTS.md
└── .gitignore
```

## 测试要求

修改脚本后，请至少运行：

```bash
bash -n softether-tools.sh
```

并人工检查以下流程：

1. 启动脚本
2. 输入管理员密码时不明文显示
3. 选择 `1` 查看用户列表
4. 选择 `2` 新增用户
5. 选择 `4` 修改用户密码
6. 选择 `6` 查看 L2TP/IPsec 配置
7. 选择 `11` 查看监听端口
8. 选择 `0` 退出

不要实际修改生产环境 PSK，除非用户明确要求。

## 给 Codex 的任务建议

如果需要整理项目，请优先做以下事情：

1. 检查 `softether-tools.sh` 的 Bash 语法。
2. 保持中文交互菜单。
3. 不保存 SoftEther 管理员密码。
4. 不使用 expect。
5. 不新增 Web 面板或后台服务。
6. 不改变核心逻辑：通过 `/usr/local/vpnserver/vpncmd` 管理 SoftEther。
7. 将 README.md 整理得更像正式开源项目文档。
8. 将 README 中的真实 IP 和真实 PSK 替换为占位符。
9. 在 README 中说明用户需要修改 `softether-tools.sh` 里的 `PUBLIC_IP` 和 `DEFAULT_PSK`。
10. 如果有必要，可以增加 `LICENSE`，建议使用 MIT。
11. 增加更清晰的安装说明和卸载说明。
12. 最后运行 `bash -n softether-tools.sh` 检查语法。
13. 不要把管理员密码、VPN 用户密码、真实 PSK 写入仓库。
