#!/bin/bash

# ========= 色彩定义 / Color Constants =========
RESET='\033[0m'
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'

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

# ========= 获取核心数量 / Get Core Count =========
function get_core_count() {
  # 获取系统中的可用核心数量
  local max_cores=$(nproc)
  read -p "请输入你希望使用的核心数量（最大可用核心数为 $max_cores）: " CORE_COUNT
  if [[ $CORE_COUNT -gt $max_cores || $CORE_COUNT -lt 1 ]]; then
    echo -e "${RED}[-] 错误：请输入一个有效的核心数量（1 到 $max_cores 之间）。${RESET}"
    exit 1
  fi
}

# ========= 一键安装函数 / Full Installation =========
function setup_all() {
  # 获取用户输入的核心数量
  get_core_count

  echo -e "[*] 安装系统依赖 / Installing system dependencies..."
  apt-get update && apt install -y sudo
  sudo apt install -y screen curl git wget make gcc build-essential jq \
    pkg-config libssl-dev libleveldb-dev clang unzip nano autoconf \
    automake htop ncdu bsdmainutils tmux lz4 iptables nvme-cli libgbm1

  echo -e "[*] 安装 Rust / Installing Rust..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source "$HOME/.cargo/env"
  rustup default stable

  echo -e "[*] 克隆最新 nockchain 仓库 / Cloning latest nockchain repository..."
  rm -rf nockchain
  git clone --depth=1 https://github.com/zorp-corp/nockchain

  echo -e "[*] 编译源码 / Building source with $CORE_COUNT 核心..."
  cd nockchain
  make -j$CORE_COUNT install-hoonc
  make -j$CORE_COUNT build
  make -j$CORE_COUNT install-nockchain-wallet
  make -j$CORE_COUNT install-nockchain

  echo -e "[*] 配置环境变量 / Setting environment variables..."
  RC_FILE="$HOME/.bashrc"
  [[ "$SHELL" == *"zsh"* ]] && RC_FILE="$HOME/.zshrc"

  echo 'export PATH="$PATH:$HOME/nockchain/target/release"' >> "$RC_FILE"
  echo 'export RUST_LOG=info' >> "$RC_FILE"
  echo 'export MINIMAL_LOG_FORMAT=true' >> "$RC_FILE"
  source "$RC_FILE"

  echo -e "${GREEN}[+] 安装完成 / Setup complete.${RESET}"
}

# ========= 生成钱包 / Wallet Generation =========
function generate_wallet() {
  echo -e "[*] 生成钱包 / Generating wallet..."
  cd nockchain

  if [ ! -f "./target/release/nockchain-wallet" ]; then
    echo -e "${RED}[-] 错误：找不到 wallet 可执行文件，请确保编译成功。${RESET}"
    exit 1
  fi

  ./target/release/nockchain-wallet keygen

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}[+] 钱包生成成功！/ Wallet generated successfully.${RESET}"
  else
    echo -e "${RED}[-] 钱包生成失败！/ Wallet generation failed!${RESET}"
    exit 1
  fi
}

# ========= 设置挖矿公钥 / Set Mining Public Key =========
function configure_mining_key() {
  cd nockchain
  read -p "[?] 输入你的挖矿公钥 / Enter your mining public key: " key
  sed -i "s|^export MINING_PUBKEY :=.*$|export MINING_PUBKEY := $key|" Makefile
  echo -e "${GREEN}[+] 挖矿公钥已设置 / Mining key updated.${RESET}"
}

# ========= 启动 Leader 节点 / Run Leader Node =========
function start_leader_node() {
  echo -e "[*] 启动 Leader 节点 / Starting leader node..."
  cd nockchain
  screen -S leader -dm make run-nockchain-leader
  echo -e "${GREEN}[+] Leader 节点运行中 / Leader node running (screen: leader).${RESET}"
}

# ========= 启动 Follower 节点 / Run Follower Node =========
function start_follower_node() {
  echo -e "[*] 启动 Follower 节点 / Starting follower node..."
  cd nockchain
  screen -S follower -dm make run-nockchain-follower
  echo -e "${GREEN}[+] Follower 节点运行中 / Follower node running (screen: follower).${RESET}"
}

# ========= 查看 Leader 节点实时日志 =========
function view_leader_logs() {
  echo -e "[*] Leader 节点日志 / Viewing leader logs..."
  screen -r leader
  echo -e "${YELLOW}[!] 按 Ctrl+A+D 可退出 screen / Ctrl+A+D to detach.${RESET}"
}

# ========= 查看 Follower 节点实时日志 =========
function view_follower_logs() {
  echo -e "[*] Follower 节点日志 / Viewing follower logs..."
  screen -r follower
  echo -e "${YELLOW}[!] 按 Ctrl+A+D 可退出 screen / Ctrl+A+D to detach.${RESET}"
}

# ========= 主菜单 / Main Menu =========
function main_menu() {
  show_banner
  echo "请选择操作 / Please choose an option:"
  echo "  1) 一键安装并构建 / Install & Build"
  echo "  2) 生成钱包 / Generate Wallet"
  echo "  3) 设置挖矿公钥 / Set Mining Public Key"
  echo "  4) 启动 Leader 节点 / Start Leader Node"
  echo "  5) 启动 Follower 节点 / Start Follower Node"
  echo "  6) 查看 Leader 日志 / View Leader Logs"
  echo "  7) 查看 Follower 日志 / View Follower Logs"
  echo "  0) 退出 / Exit"
  echo ""
  read -p "请输入编号 / Enter your choice: " choice

  case "$choice" in
    1) setup_all ;;
    2) generate_wallet ;;
    3) configure_mining_key ;;
    4) start_leader_node ;;
    5) start_follower_node ;;
    6) view_leader_logs ;;
    7) view_follower_logs ;;
    0) echo "已退出 / Exiting."; exit 0 ;;
    *) echo -e "${RED}[-] 无效选项 / Invalid option.${RESET}" ;;
  esac

  echo ""
  read -p "按任意键返回菜单 / Press any key to return to menu..." -n1
  main_menu
}

# ========= 启动主程序 / Entry =========
main_menu
