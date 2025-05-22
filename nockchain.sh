#!/bin/bash

# ========= 色彩定义 / Color Constants =========
RESET='\033[0m'
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'

# ========= 项目路径 / Project Directory =========
NCK_DIR="/root/nockchain"
ENV_FILE="$NCK_DIR/.env"

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

function cd_nck_dir() {
  if [ -d "$NCK_DIR" ]; then
    cd "$NCK_DIR" || exit 1
  else
    echo -e "${RED}[-] 错误：项目目录不存在：$NCK_DIR${RESET}"
    exit 1
  fi
}

function setup_all() {
  echo -e "[*] 安装系统依赖 / Installing system dependencies..."
  sudo apt update && sudo apt install -y sudo

  sudo apt install -y \
    clang \
    llvm-dev \
    libclang-dev \
    pkg-config \
    libssl-dev \
    build-essential \
    cmake \
    curl \
    git \
    make \
    screen

  echo -e "[*] 安装 Rust / Installing Rust..."
  if ! command -v cargo &>/dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    echo -e "${YELLOW}[!] Rust 安装完成，请重新打开终端或执行：source ~/.bashrc${RESET}"
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

  cd_nck_dir

  echo -e "[*] 拷贝 .env 文件..."
  cp -n .env_example "$ENV_FILE"

  if [ -f "$ENV_FILE" ]; then
    echo -e "[*] 加载 .env 文件中的环境变量..."
    set -a
    source "$ENV_FILE"
    set +a
  fi

  echo -e "[*] 编译并安装 / Building & installing..."
  make install-hoonc || { echo -e "${RED}[-] install-hoonc 失败${RESET}"; exit 1; }

  make build || { echo -e "${RED}[-] build 失败${RESET}"; exit 1; }
  make install-nockchain-wallet || { echo -e "${RED}[-] install-nockchain-wallet 失败${RESET}"; exit 1; }
  make install-nockchain || { echo -e "${RED}[-] install-nockchain 失败${RESET}"; exit 1; }

  echo -e "${GREEN}[+] 安装完成 / Setup complete.${RESET}"
  pause_and_return
}

function generate_wallet() {
  echo -e "[*] 生成钱包 / Generating wallet..."
  cd_nck_dir

  if [ ! -f "./target/release/nockchain-wallet" ]; then
    echo -e "${RED}[-] 错误：找不到 wallet 可执行文件，请确保编译成功。${RESET}"
    pause_and_return
    return
  fi

  ./target/release/nockchain-wallet keygen

  pause_and_return
}

function start_node() {
  echo -e "[*] 启动 Nockchain 节点 (screen 会话名: nockchain) / Starting Nockchain node in screen session..."
  cd_nck_dir

  read -p "[?] 请输入挖矿公钥 (留空则不挖矿) / Enter mining public key (leave empty to run without mining): " MINING_PUBKEY

  mining_flag=""
  if [ -n "$MINING_PUBKEY" ]; then
    mining_flag="--mining_pubkey $MINING_PUBKEY --mine"
  fi

  if screen -list | grep -q "[.]nockchain"; then
    echo "[*] 发现已有 screen 会话 nockchain，正在关闭..."
    screen -S nockchain -X quit
    for i in {1..5}; do
      if ! screen -list | grep -q "[.]nockchain"; then
        break
      fi
      sleep 1
    done
    if screen -list | grep -q "[.]nockchain"; then
      echo -e "${RED}[-] 无法关闭已有的 nockchain 会话，请手动关闭后重试${RESET}"
      pause_and_return
      return
    fi
  fi

  screen -dmS nockchain bash -c "./target/release/nockchain $mining_flag"
  sleep 2

  if screen -list | grep -q "[.]nockchain"; then
    echo -e "${GREEN}[+] 节点启动成功，screen 会话名: nockchain${RESET}"
  else
    echo -e "${RED}[-] 节点启动失败${RESET}"
  fi
  pause_and_return
}

function view_logs() {
  if screen -list | grep -q "[.]nockchain"; then
    echo -e "${YELLOW}[!] 进入 screen 会话，按 Ctrl+A+D 退出日志界面 / Press Ctrl+A+D to detach.${RESET}"
    screen -r nockchain
  else
    echo -e "${RED}[-] 节点未运行，无法查看日志${RESET}"
    pause_and_return
    return
  fi
  pause_and_return
}

function pause_and_return() {
  echo ""
  read -n1 -r -p "按任意键返回主菜单 / Press any key to return to menu..." key
  main_menu
}

function main_menu() {
  show_banner
  echo "请选择操作 / Please choose an option:"
  echo "  1) 一键安装并构建 / Install & Build"
  echo "  2) 生成钱包 / Generate Wallet"
  echo "  3) 启动节点 (screen 后台) / Start Node (screen background)"
  echo "  4) 查看节点日志 / View Node Logs"
  echo "  0) 退出 / Exit"
  echo ""
  read -p "请输入编号 / Enter your choice: " choice

  case "$choice" in
    1) setup_all ;;
    2) generate_wallet ;;
    3) start_node ;;
    4) view_logs ;;
    0) echo "已退出 / Exiting."; exit 0 ;;
    *) echo -e "${RED}[-] 无效选项 / Invalid option.${RESET}"; pause_and_return ;;
  esac
}

main_menu
