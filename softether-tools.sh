#!/usr/bin/env bash
set -u

VPNCMD="/usr/local/vpnserver/vpncmd"
SERVER="localhost"
HUB="DEFAULT"

# 修改为你的服务器公网 IP 或域名
PUBLIC_IP="your_server_ip"

# 修改为你的 L2TP/IPsec 预共享密钥
DEFAULT_PSK="change_me"

if [ ! -x "$VPNCMD" ]; then
  echo "错误：找不到 vpncmd：$VPNCMD"
  exit 1
fi

read -rsp "请输入 SoftEther 服务器管理员密码: " ADMIN_PASS
echo

pause() {
  echo
  read -rp "按回车键返回菜单..."
}

run_file() {
  local file="$1"
  "$VPNCMD" "$SERVER" /SERVER "/PASSWORD:${ADMIN_PASS}" /IN:"$file"
}

run_cmd() {
  "$VPNCMD" "$SERVER" /SERVER "/PASSWORD:${ADMIN_PASS}" /CMD "$@"
}

tmp_run() {
  local tmp code
  tmp="$(mktemp)" || {
    echo "错误：无法创建临时命令文件。"
    return 1
  }
  chmod 600 "$tmp" 2>/dev/null || true
  cat > "$tmp"
  run_file "$tmp"
  code=$?
  rm -f "$tmp"
  return "$code"
}

valid_username() {
  local value="$1"
  [[ "$value" =~ ^[A-Za-z0-9._-]+$ ]]
}

read_username() {
  local prompt="$1"
  local __result_var="$2"
  local value

  read -rp "$prompt" value

  if ! valid_username "$value"; then
    echo "错误：用户名只能包含字母、数字、点、下划线、短横线。"
    return 1
  fi

  printf -v "$__result_var" '%s' "$value"
}

valid_secret() {
  local value="$1"
  [ -n "$value" ] || return 1
  [[ "$value" != *$'\n'* ]] || return 1
  [[ "$value" != *$'\r'* ]] || return 1
}

read_secret_twice() {
  local prompt1="$1"
  local prompt2="$2"
  local label="$3"
  local __result_var="$4"
  local value1 value2

  read -rsp "$prompt1" value1
  echo
  read -rsp "$prompt2" value2
  echo

  if [ "$value1" != "$value2" ]; then
    echo "错误：两次输入的${label}不一致。"
    return 1
  fi

  if ! valid_secret "$value1"; then
    echo "错误：${label}不能为空，也不能包含换行符。"
    return 1
  fi

  printf -v "$__result_var" '%s' "$value1"
}

print_config() {
  local user="$1"
  local pass="$2"

  echo
  echo "========================================"
  echo "VPN 配置信息"
  echo "========================================"
  echo "类型：L2TP/IPsec PSK"
  echo "服务器：$PUBLIC_IP"
  echo "用户名：$user"
  echo "密码：$pass"
  echo "预共享密钥：$DEFAULT_PSK"
  echo "========================================"
  echo
  echo "如果用户名连接失败，可以尝试：${user}@${HUB}"
}

list_users() {
  echo
  echo "正在读取用户列表..."

  tmp_run <<EOF
Hub $HUB
UserList
exit
EOF

  if [ $? -ne 0 ]; then
    echo
    echo "读取用户列表失败。请检查管理员密码或 SoftEther 服务状态。"
  fi
}

add_user() {
  local user pass exists userlist yn

  echo
  read_username "请输入新用户名: " user || return
  read_secret_twice "请输入用户密码: " "请再次输入用户密码: " "密码" pass || return

  echo
  echo "正在检查用户是否已存在..."
  userlist="$(mktemp)" || {
    echo "错误：无法创建临时文件。"
    return 1
  }
  chmod 600 "$userlist" 2>/dev/null || true

  tmp_run > "$userlist" <<EOF
Hub $HUB
UserList
exit
EOF

  if [ $? -ne 0 ]; then
    echo "读取用户列表失败。"
    cat "$userlist"
    rm -f "$userlist"
    return
  fi

  exists="no"
  if awk -F'|' -v name="$user" '
    $1 ~ /User Name/ {
      value = $2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      if (value == name) {
        found = 1
      }
    }
    END { exit found ? 0 : 1 }
  ' "$userlist"; then
    exists="yes"
  fi
  rm -f "$userlist"

  if [ "$exists" = "yes" ]; then
    echo "用户 '$user' 已存在。"
    read -rp "是否更新该用户密码？[y/N]: " yn
    case "$yn" in
      y|Y|yes|YES) ;;
      *) echo "已取消。"; return ;;
    esac
  else
    echo "正在创建用户 '$user'..."

    tmp_run <<EOF
Hub $HUB
UserCreate $user /GROUP:none /REALNAME:none /NOTE:none
exit
EOF

    if [ $? -ne 0 ]; then
      echo "创建用户失败。"
      return
    fi
  fi

  echo "正在设置用户密码..."

  tmp_run <<EOF
Hub $HUB
UserPasswordSet $user /PASSWORD:$pass
exit
EOF

  if [ $? -ne 0 ]; then
    echo "设置用户密码失败。"
    return
  fi

  echo "正在确认 SecureNAT 已启用..."

  tmp_run >/dev/null 2>&1 <<EOF
Hub $HUB
SecureNatEnable
exit
EOF

  echo "正在确认 L2TP/IPsec 已启用..."

  run_cmd IPsecEnable /L2TP:yes /L2TPRAW:no /ETHERIP:no "/PSK:${DEFAULT_PSK}" "/DEFAULTHUB:${HUB}" >/dev/null

  if [ $? -ne 0 ]; then
    echo "配置 L2TP/IPsec 失败。"
    return
  fi

  echo
  echo "用户创建/更新完成。"
  print_config "$user" "$pass"
}

delete_user() {
  local user yn

  echo
  read_username "请输入要删除的用户名: " user || return

  read -rp "确认删除用户 '$user'？[y/N]: " yn
  case "$yn" in
    y|Y|yes|YES) ;;
    *) echo "已取消。"; return ;;
  esac

  tmp_run <<EOF
Hub $HUB
UserDelete $user
exit
EOF

  if [ $? -eq 0 ]; then
    echo "用户 '$user' 已删除。"
  else
    echo "删除用户失败。"
  fi
}

change_password() {
  local user pass

  echo
  read_username "请输入要修改密码的用户名: " user || return
  read_secret_twice "请输入新密码: " "请再次输入新密码: " "密码" pass || return

  tmp_run <<EOF
Hub $HUB
UserPasswordSet $user /PASSWORD:$pass
exit
EOF

  if [ $? -eq 0 ]; then
    echo "用户 '$user' 的密码已更新。"
  else
    echo "修改密码失败。"
  fi
}

show_sessions() {
  echo
  echo "正在读取在线会话..."

  tmp_run <<EOF
Hub $HUB
SessionList
exit
EOF

  if [ $? -ne 0 ]; then
    echo "读取在线会话失败。"
  fi
}

show_ipsec() {
  echo
  echo "正在读取 L2TP/IPsec 配置..."
  run_cmd IPsecGet

  if [ $? -ne 0 ]; then
    echo "读取 L2TP/IPsec 配置失败。"
  fi
}

change_psk() {
  local psk

  echo
  read_secret_twice "请输入新的 L2TP/IPsec 预共享密钥 PSK: " "请再次输入新的 PSK: " "PSK" psk || return

  run_cmd IPsecEnable /L2TP:yes /L2TPRAW:no /ETHERIP:no "/PSK:${psk}" "/DEFAULTHUB:${HUB}"

  if [ $? -eq 0 ]; then
    echo
    echo "PSK 已修改。注意：所有客户端都需要同步修改预共享密钥。"
  else
    echo "修改 PSK 失败。"
  fi
}

service_status() {
  echo
  echo "正在查看 SoftEther 服务状态..."
  sudo systemctl status vpnserver --no-pager

  if [ $? -ne 0 ]; then
    echo "查看 SoftEther 服务状态失败。"
  fi
}

restart_service() {
  echo "正在重启 SoftEther VPN Server..."
  sudo systemctl restart vpnserver

  if [ $? -ne 0 ]; then
    echo "重启 SoftEther 服务失败。"
    return
  fi

  sudo systemctl status vpnserver --no-pager
}

print_template() {
  local user pass

  echo
  read_username "请输入用户名: " user || return
  read_secret_twice "请输入密码: " "请再次输入密码: " "密码" pass || return

  print_config "$user" "$pass"
}

show_ports() {
  echo
  echo "正在查看 SoftEther 相关监听端口..."
  sudo ss -tulpn | grep -E 'vpnserver|:500|:4500|:1701|:443|:5555' || true
}

show_menu() {
  clear
  echo
  echo "========================================"
  echo "SoftEther 管理工具"
  echo "服务器：$PUBLIC_IP"
  echo "虚拟 Hub：$HUB"
  echo "默认客户端类型：L2TP/IPsec PSK"
  echo "========================================"
  echo "1) 查看用户列表"
  echo "2) 新增用户"
  echo "3) 删除用户"
  echo "4) 修改用户密码"
  echo "5) 查看在线会话"
  echo "6) 查看 L2TP/IPsec 配置"
  echo "7) 修改预共享密钥 PSK"
  echo "8) 查看 SoftEther 服务状态"
  echo "9) 重启 SoftEther 服务"
  echo "10) 打印客户端配置模板"
  echo "11) 查看 SoftEther 监听端口"
  echo "0) 退出"
  echo "========================================"
}

while true; do
  show_menu
  read -rp "请选择操作: " choice

  case "$choice" in
    1) list_users; pause ;;
    2) add_user; pause ;;
    3) delete_user; pause ;;
    4) change_password; pause ;;
    5) show_sessions; pause ;;
    6) show_ipsec; pause ;;
    7) change_psk; pause ;;
    8) service_status; pause ;;
    9) restart_service; pause ;;
    10) print_template; pause ;;
    11) show_ports; pause ;;
    0) exit 0 ;;
    *) echo "无效选择"; sleep 1 ;;
  esac
done
