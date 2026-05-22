# SoftEther Tools

一个用于管理 SoftEther VPN Server 的中文交互式 Bash 工具，适合在 Ubuntu / Debian VPS 上管理 L2TP/IPsec PSK 用户。

项目定位类似轻量版命令行管理面板：不提供 Web 面板，不开放额外管理端口，只通过 SoftEther 官方 `vpncmd` 在本机执行管理操作。

## 功能列表

- 查看用户列表
- 新增用户
- 删除用户
- 修改用户密码
- 查看在线会话
- 查看 L2TP/IPsec 配置
- 修改 L2TP/IPsec 预共享密钥 PSK
- 查看 SoftEther 服务状态
- 重启 SoftEther 服务
- 打印客户端配置模板
- 查看 SoftEther 监听端口

## 环境要求

- Ubuntu / Debian VPS
- 已安装 SoftEther VPN Server
- SoftEther 安装目录默认为：

```bash
/usr/local/vpnserver
```

- `vpncmd` 默认路径为：

```bash
/usr/local/vpnserver/vpncmd
```

- 默认虚拟 Hub 为：

```text
DEFAULT
```

- 默认使用 L2TP/IPsec PSK 方式连接

## 安装方式

### 方式一：从 GitHub 下载

```bash
wget -O softether-tools.sh https://raw.githubusercontent.com/ljy3135134162/softether-tools/main/softether-tools.sh
chmod +x softether-tools.sh
sudo ./softether-tools.sh
```

### 方式二：克隆仓库

```bash
git clone https://github.com/ljy3135134162/softether-tools.git
cd softether-tools
chmod +x softether-tools.sh install.sh
sudo ./install.sh
```

安装后运行：

```bash
sudo softether-tools
```

`install.sh` 会把脚本安装到：

```bash
/usr/local/bin/softether-tools
```

## 使用方式

首次使用前，编辑脚本顶部变量：

```bash
VPNCMD="/usr/local/vpnserver/vpncmd"
SERVER="localhost"
HUB="DEFAULT"
PUBLIC_IP="your_server_ip"
DEFAULT_PSK="change_me"
```

变量说明：

| 变量 | 说明 |
|---|---|
| `VPNCMD` | SoftEther 官方命令行工具路径 |
| `SERVER` | SoftEther Server 管理地址，默认 `localhost` |
| `HUB` | 虚拟 Hub 名称，默认 `DEFAULT` |
| `PUBLIC_IP` | 客户端连接使用的服务器公网 IP 或域名 |
| `DEFAULT_PSK` | L2TP/IPsec 预共享密钥 |

运行脚本：

```bash
sudo ./softether-tools.sh
```

脚本启动后会隐藏输入 SoftEther Server 管理员密码。管理员密码只保存在当前进程内存中，不会写入文件，也不会打印到终端。

## L2TP/IPsec 客户端配置

新增用户成功后，脚本会打印类似以下配置：

```text
类型：L2TP/IPsec PSK
服务器：your_server_ip
用户名：example_user
密码：example_password
预共享密钥：change_me
```

如果客户端直接使用用户名连接失败，可以尝试：

```text
example_user@DEFAULT
```

客户端类型请选择系统内置的 L2TP/IPsec PSK。无需安装 WireGuard、Tailscale 或 OpenVPN 客户端。

## 云服务器端口放行

L2TP/IPsec 通常需要在云厂商安全组、安全列表和服务器本机防火墙中放行以下 UDP 端口：

| 协议 | 端口 | 用途 |
|---|---:|---|
| UDP | 500 | IKE |
| UDP | 4500 | IPsec NAT-T |
| UDP | 1701 | L2TP |

本工具不会自动修改系统防火墙，也不会自动修改 Oracle Cloud、AWS、Azure 等云厂商安全组。请根据你的环境手动配置。

不建议把 SoftEther 管理端口 `5555` 暴露到公网。建议通过 SSH、Tailscale 或内网方式管理服务器。

## 安全建议

- 请把 `PUBLIC_IP="your_server_ip"` 改成你的公网 IP 或域名。
- 请把 `DEFAULT_PSK="change_me"` 改成足够强的预共享密钥。
- 不要把 SoftEther Server 管理员密码写入脚本或仓库。
- 不要把 VPN 用户密码、真实 PSK、真实服务器 IP 写入仓库。
- 每个 VPN 用户应使用独立用户名和独立密码。
- PSK 是全局共享密钥，修改 PSK 后所有客户端都需要同步修改。
- 不要把 SoftEther 管理端口 `5555` 暴露到公网。

## 常见问题

### 为什么脚本需要 SoftEther 管理员密码？

脚本通过 `vpncmd` 管理 SoftEther，包括创建用户、删除用户、修改密码、读取配置等。这些操作需要 SoftEther Server 管理员权限。

### 管理员密码会保存吗？

不会。脚本启动时隐藏读取一次管理员密码，只保存在当前进程内存中，不写入文件。

### 为什么不用 `/HUB:DEFAULT`？

使用 Server 管理员密码时，不能直接配合 `/HUB:DEFAULT` 管理 Hub。`/HUB:DEFAULT` 会进入 Virtual Hub Admin Mode，此时需要 Hub 管理密码，不是 Server 管理员密码。

本脚本会先以 Server 管理模式连接，再在命令文件中执行：

```text
Hub DEFAULT
UserList
exit
```

这样可以避免 `Access has been denied` 或 `vpncmd` 再次出现交互式 `Password:` 提示。

### 为什么 `vpncmd` 输出仍然是英文？

SoftEther 官方 `vpncmd` 输出字段本身是英文，例如 `User Name`、`Session Name`、`IPsec Pre-Shared Key String`。脚本保留中文菜单和中文提示，不强行翻译原始输出，方便排错。

### 查看用户列表时仍然失败怎么办？

请检查：

- SoftEther VPN Server 是否正在运行。
- `/usr/local/vpnserver/vpncmd` 是否存在且可执行。
- 输入的是 SoftEther Server 管理员密码，不是 Hub 管理密码。
- `HUB="DEFAULT"` 是否与你服务器上的虚拟 Hub 名称一致。

## 卸载说明

如果使用 `install.sh` 安装：

```bash
sudo rm -f /usr/local/bin/softether-tools
```

如果只是下载脚本运行，删除脚本文件即可：

```bash
rm -f softether-tools.sh
```

卸载本工具不会删除 SoftEther VPN Server，也不会删除 SoftEther 用户、Hub 或配置。

## 测试

修改脚本后，至少运行：

```bash
bash -n softether-tools.sh
```

人工检查建议：

1. 启动脚本。
2. 输入管理员密码时不明文显示。
3. 选择 `1` 查看用户列表。
4. 选择 `2` 新增用户。
5. 选择 `4` 修改用户密码。
6. 选择 `6` 查看 L2TP/IPsec 配置。
7. 选择 `11` 查看监听端口。
8. 选择 `0` 退出。

不要在生产环境中随意修改 PSK。修改 PSK 后，所有客户端都需要同步修改。

## License

MIT
