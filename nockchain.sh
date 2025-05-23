#!/bin/bash

# ========= 色彩定义 =========
RESET='\033[0m'
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'

# ========= 项目路径 =========
NCK_DIR="$HOME/nockchain"
ENV_FILE="$NCK_DIR/.env"

# ========= 横幅 =========
function show_banner() {
  clear
  echo -e "${BOLD}${BLUE}"
  echo "==============================================="
  echo "         Nockchain 安装助手 / Setup Tool"
  echo "==============================================="
  echo -e "${RESET}"
  echo "📌 作者: K2 节点教程分享"
  echo "🔗 Telegram: https://t.me/+EaCiFDOghoM3Yzll"
  echo "🐦 Twitter:  https://x.com/BtcK241918"
  echo "-----------------------------------------------"
  echo ""
}

function cd_nck_dir() {
  if [ -d "$NCK_DIR" ]; then
    cd "$NCK_DIR" || exit 1
  else
    echo -e "${RED}[-] 项目目录不存在: $NCK_DIR${RESET}"
    exit 1
  fi
}

function setup_all() {
  echo -e "[*] 安装系统依赖..."
  sudo apt update
  sudo apt install -y clang llvm-dev libclang-dev pkg-config libssl-dev build-essential cmake curl git make screen

  echo -e "[*] 安装 Rust..."
  if ! command -v cargo &>/dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
  fi

  RC_FILE="$HOME/.bashrc"
  [[ "$SHELL" == *"zsh"* ]] && RC_FILE="$HOME/.zshrc"
  if ! grep -q 'export PATH="$HOME/.cargo/bin:$PATH"' "$RC_FILE"; then
    echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$RC_FILE"
  fi
  export PATH="$HOME/.cargo/bin:$PATH"

  echo -e "[*] 获取仓库..."
  if [ -d "$NCK_DIR" ]; then
    cd "$NCK_DIR" && git pull
  else
    git clone https://github.com/zorp-corp/nockchain "$NCK_DIR"
  fi

  cd_nck_dir

  echo -e "[*] 设置 .env 文件..."
  cp -n .env_example "$ENV_FILE"

  echo -e "[*] 安装 hoonc..."
  make install-hoonc || { echo -e "${RED}[-] install-hoonc 失败${RESET}"; exit 1; }

  echo -e "[*] 编译 Nockchain..."
  make build || { echo -e "${RED}[-] build 失败${RESET}"; exit 1; }

  echo -e "[*] 安装钱包..."
  make install-nockchain-wallet || { echo -e "${RED}[-] install-nockchain-wallet 失败${RESET}"; exit 1; }

  echo -e "[*] 安装节点..."
  make install-nockchain || { echo -e "${RED}[-] install-nockchain 失败${RESET}"; exit 1; }

  echo -e "${GREEN}[+] 安装完成${RESET}"
  pause_and_return
}

function generate_wallet() {
  echo -e "[*] 生成钱包..."
  cd_nck_dir

  ./target/release/nockchain-wallet keygen

  echo -e "${YELLOW}[!] 钱包生成完成，请手动将公钥写入 .env 文件中的 MINING_PUBKEY=${RESET}"
  pause_and_return
}

function set_pubkey_env() {
  echo -e "[*] 设置 MINING_PUBKEY 到 .env..."
  cd_nck_dir

  read -p "请输入公钥 (MINING_PUBKEY): " pubkey
  if [ -z "$pubkey" ]; then
    echo -e "${RED}[-] 公钥不能为空${RESET}"
    pause_and_return
    return
  fi

  sed -i '/^MINING_PUBKEY=/d' "$ENV_FILE"
  echo "MINING_PUBKEY=$pubkey" >> "$ENV_FILE"

  echo -e "${GREEN}[+] 已写入 MINING_PUBKEY 到 .env${RESET}"
  pause_and_return
}

function export_keys() {
  echo -e "[*] 导出钱包密钥..."
  cd_nck_dir
  ./target/release/nockchain-wallet export-keys
  echo -e "${GREEN}[+] 密钥已导出到 keys.export${RESET}"
  pause_and_return
}

function import_keys() {
  echo -e "[*] 导入钱包密钥..."
  cd_nck_dir
  read -p "[?] 请输入密钥文件路径 (默认: ./keys.export): " keyfile
  keyfile=${keyfile:-"./keys.export"}
  ./target/release/nockchain-wallet import-keys --input "$keyfile"
  echo -e "${GREEN}[+] 密钥已导入${RESET}"
  pause_and_return
}

function start_node() {
  echo -e "[*] 启动节点 (screen)..."
  cd_nck_dir
  source "$ENV_FILE"

  # 确保启动脚本有执行权限
  chmod +x ./scripts/run_nockchain_miner.sh

  if screen -list | grep -qw "nockchain"; then
    echo "[*] 关闭旧的 screen 会话..."
    screen -S nockchain -X quit
    sleep 1
  fi

  # 简单方式：新建 screen 会话，切换目录并执行启动脚本
  screen -dmS nockchain bash -c "cd $NCK_DIR && ./scripts/run_nockchain_miner.sh"

  sleep 2
  if screen -list | grep -qw "nockchain"; then
    echo -e "${GREEN}[+] 节点已启动 (screen 会话名: nockchain)${RESET}"
  else
    echo -e "${RED}[-] 节点启动失败${RESET}"
    echo "请检查 $NCK_DIR/scripts/run_nockchain_miner.sh 脚本权限或内容"
  fi
  pause_and_return
}

function view_logs() {
  if screen -list | grep -qw "nockchain"; then
    echo -e "${YELLOW}[!] 查看日志中 (Ctrl+A+D 可退出)...${RESET}"
    screen -r nockchain
  else
    echo -e "${RED}[-] 节点未运行${RESET}"
  fi
  pause_and_return
}

function pause_and_return() {
  echo ""
  read -n1 -r -p "按任意键返回主菜单..." key
  main_menu
}

function main_menu() {
  show_banner
  echo "请选择操作:"
  echo "  1) 一键安装并构建"
  echo "  2) 生成钱包 (查看输出日志)"
  echo "  3) 设置 MINING_PUBKEY 到 .env (手动输入)"
  echo "  4) 导出钱包密钥"
  echo "  5) 导入钱包密钥"
  echo "  6) 启动节点 (screen 后台)"
  echo "  7) 查看节点日志"
  echo "  0) 退出"
  echo ""
  read -p "请输入编号: " choice

  case "$choice" in
    1) setup_all ;;
    2) generate_wallet ;;
    3) set_pubkey_env ;;
    4) export_keys ;;
    5) import_keys ;;
    6) start_node ;;
    7) view_logs ;;
    0) echo "退出脚本."; exit 0 ;;
    *) echo -e "${RED}[-] 无效选项${RESET}"; pause_and_return ;;
  esac
}

main_menu
