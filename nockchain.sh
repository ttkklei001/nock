#!/bin/bash

# ========= 色彩定义 / Color Constants =========
RESET='\033[0m'
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'

# ========= 项目路径 / Project Directory =========
NCK_DIR="$HOME/nockchain"

# ========= 横幅与署名 / Banner & Signature =========
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

# ========= 提示输入 CPU 核心数 / Prompt for core count =========
function prompt_core_count() {
  read -p "[?] 请输入用于编译的 CPU 核心数量 / Enter number of CPU cores for compilation: " CORE_COUNT
  if ! [[ "$CORE_COUNT" =~ ^[0-9]+$ ]] || [[ "$CORE_COUNT" -lt 1 ]]; then
    echo -e "${RED}[-] 输入无效，默认使用 1 核心 / Invalid input. Using 1 core.${RESET}"
    CORE_COUNT=1
  fi
}

# ========= 安装和构建 / Setup & Build =========
function setup_all() {
  echo -e "[*] 安装系统依赖 / Installing system dependencies..."
  sudo apt update && sudo apt install -y sudo
  sudo apt install -y clang llvm-dev libclang-dev curl git make

  echo -e "[*] 安装 Rust / Installing Rust..."
  if ! command -v cargo &>/dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
  fi

  RC_FILE="$HOME/.bashrc"
  [[ "$SHELL" == *"zsh"* ]] && RC_FILE="$HOME/.zshrc"
  if ! grep -q 'export PATH="$HOME/.cargo/bin:$PATH"' "$RC_FILE"; then
    echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$RC_FILE"
  fi

  echo -e "[*] 获取最新仓库 / Cloning or updating nockchain repository..."
  if [ -d "$NCK_DIR" ]; then
    cd "$NCK_DIR" && git pull
  else
    git clone --depth=1 https://github.com/zorp-corp/nockchain "$NCK_DIR"
  fi

  cd "$NCK_DIR" || exit 1

  echo -e "[*] 拷贝 .env 文件..."
  cp -n .env_example .env

  # 加载 .env 文件中的环境变量
  if [ -f ".env" ]; then
    echo -e "[*] 加载 .env 文件中的环境变量..."
    set -a
    source .env
    set +a
  fi

  prompt_core_count

  echo -e "[*] 编译并安装 / Building & installing..."
  make install-hoonc
  make -j$CORE_COUNT build-hoon-all
  make -j$CORE_COUNT build
  make install-nockchain-wallet
  make install-nockchain

  echo -e "${GREEN}[+] 安装完成 / Setup complete.${RESET}"
  pause_and_return
}

# ========= 钱包生成 / Wallet Generation =========
function generate_wallet() {
  echo -e "[*] 生成钱包 / Generating wallet..."
  if [ ! -f "$NCK_DIR/target/release/nockchain-wallet" ]; then
    echo -e "${RED}[-] 错误：找不到 wallet 可执行文件，请确保编译成功。${RESET}"
    pause_and_return
    return
  fi

  tmpfile=$(mktemp)
  "$NCK_DIR/target/release/nockchain-wallet" keygen 2>&1 | tee "$tmpfile"

  mnemonic=$(grep "wallet: memo:" "$tmpfile" | sed -E 's/^.*wallet: memo: (.*)$/\1/')
  private_key=$(grep 'private key: base58' "$tmpfile" | sed -E 's/^.*base58 "(.*)".*$/\1/')
  public_key=$(grep 'public key: base58' "$tmpfile" | sed -E 's/^.*base58 "(.*)".*$/\1/')

  echo -e "\n${YELLOW}=== 请务必保存以下信息！/ PLEASE SAVE THESE INFO! ===${RESET}"
  echo -e "${BOLD}助记词 (Mnemonic):${RESET}\n$mnemonic\n"
  echo -e "${BOLD}私钥 (Private Key):${RESET}\n$private_key\n"
  echo -e "${BOLD}公钥 (Public Key):${RESET}\n$public_key\n"
  echo -e "${YELLOW}========================================${RESET}\n"

  # 写入 .env 文件
  sed -i "s/^MINING_PUBKEY=.*/MINING_PUBKEY=$public_key/" "$NCK_DIR/.env"
  echo -e "${GREEN}[✔] 挖矿公钥已写入 .env 文件${RESET}"

  rm -f "$tmpfile"
  pause_and_return
}

# ========= 设置挖矿公钥 / Set Mining Public Key =========
function configure_mining_key() {
  if [ ! -f "$NCK_DIR/.env" ]; then
    echo -e "${RED}[-] .env 文件不存在，请先运行安装 / .env file not found, please run install first.${RESET}"
    pause_and_return
    return
  fi

  read -p "[?] 输入你的挖矿公钥 / Enter your mining public key: " key
  if grep -q "^MINING_PUBKEY=" "$NCK_DIR/.env"; then
    sed -i "s|^MINING_PUBKEY=.*$|MINING_PUBKEY=$key|" "$NCK_DIR/.env"
  else
    echo "MINING_PUBKEY=$key" >> "$NCK_DIR/.env"
  fi
  echo -e "${GREEN}[+] 挖矿公钥已更新 / Mining key updated.${RESET}"

  pause_and_return
}

# ========= 启动节点 / Run Node in screen =========
function start_node() {
  echo -e "[*] 启动 Nockchain 节点 (screen 会话名: nockchain) / Starting Nockchain node in screen session..."
  cd "$NCK_DIR" || exit 1
  # 关闭已有会话
  if screen -list | grep -q "nockchain"; then
    screen -S nockchain -X quit
    sleep 1
  fi
  screen -dmS nockchain bash -c "make run-nockchain"
  sleep 2
  if screen -list | grep -q "nockchain"; then
    echo -e "${GREEN}[+] 节点启动成功，screen 会话名: nockchain${RESET}"
  else
    echo -e "${RED}[-] 节点启动失败${RESET}"
  fi
  pause_and_return
}

# ========= 查看节点日志 / View Node Logs =========
function view_logs() {
  if screen -list | grep -q "nockchain"; then
    echo -e "${YELLOW}[!] 进入 screen 会话，按 Ctrl+A+D 退出日志界面 / Press Ctrl+A+D to detach.${RESET}"
    screen -r nockchain
  else
    echo -e "${RED}[-] 节点未运行，无法查看日志${RESET}"
    pause_and_return
  fi
}

# ========= 等待按键继续 / Pause & Return =========
function pause_and_return() {
  echo ""
  read -n1 -r -p "按任意键返回主菜单 / Press any key to return to menu..." key
  main_menu
}

# ========= 主菜单 / Main Menu =========
function main_menu() {
  show_banner
  echo "请选择操作 / Please choose an option:"
  echo "  1) 一键安装并构建 / Install & Build"
  echo "  2) 生成钱包 / Generate Wallet"
  echo "  3) 设置挖矿公钥 / Set Mining Public Key"
  echo "  4) 启动节点 (screen 后台) / Start Node (screen background)"
  echo "  5) 查看节点日志 / View Node Logs"
  echo "  0) 退出 / Exit"
  echo ""
  read -p "请输入编号 / Enter your choice: " choice

  case "$choice" in
    1) setup_all ;;
    2) generate_wallet ;;
    3) configure_mining_key ;;
    4) start_node ;;
    5) view_logs ;;
    0) echo "已退出 / Exiting."; exit 0 ;;
    *) echo -e "${RED}[-] 无效选项 / Invalid option.${RESET}"; pause_and_return ;;
  esac
}

# ========= 启动主程序 / Entry =========
main_menu
