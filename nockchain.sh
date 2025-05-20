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

# ========= 一键安装函数 / Full Installation =========
function setup_all() {
  echo -e "[*] 安装系统依赖 / Installing system dependencies..."
  apt-get update && apt install -y sudo
  sudo apt install -y screen curl git wget make gcc build-essential jq \
    pkg-config libssl-dev libleveldb-dev clang unzip nano autoconf \
    automake htop ncdu bsdmainutils tmux lz4 iptables nvme-cli libgbm1

  echo -e "[*] 安装 Rust / Installing Rust..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

  # 加载 rustup 环境变量，使 cargo 命令可用
  source "$HOME/.cargo/env"

  # 将 cargo 路径添加到 shell 配置文件，确保以后都可用
  RC_FILE="$HOME/.bashrc"
  [[ "$SHELL" == *"zsh"* ]] && RC_FILE="$HOME/.zshrc"

  # 避免重复写入 PATH 变量
  if ! grep -q 'export PATH="$HOME/.cargo/bin:$PATH"' "$RC_FILE"; then
    echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$RC_FILE"
  fi

  rustup default stable

  echo -e "[*] 获取最新仓库 / Cloning or updating latest nockchain repository..."
  if [ -d "$NCK_DIR" ]; then
    cd "$NCK_DIR" && git pull
  else
    git clone --depth=1 https://github.com/zorp-corp/nockchain "$NCK_DIR"
  fi

  cd "$NCK_DIR" || exit 1

  prompt_core_count

  echo -e "[*] 编译源码 / Building source with ${CORE_COUNT} 核心..."
  make install-hoonc
  make -j$CORE_COUNT build-hoon-all
  make -j$CORE_COUNT build
  make -j$CORE_COUNT install-nockchain-wallet
  make -j$CORE_COUNT install-nockchain

  echo -e "${GREEN}[+] 安装完成 / Setup complete.${RESET}"
  pause_and_return
}

# ========= 生成钱包 / Wallet Generation =========
function generate_wallet() {
  echo -e "[*] 生成钱包 / Generating wallet..."
  if [ ! -f "$NCK_DIR/target/release/nockchain-wallet" ]; then
    echo -e "${RED}[-] 错误：找不到 wallet 可执行文件，请确保编译成功。${RESET}"
    pause_and_return
    return
  fi

  tmpfile=$(mktemp)
  "$NCK_DIR/target/release/nockchain-wallet" keygen 2>&1 | tr -d '\0' | tee "$tmpfile"

  if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo -e "${GREEN}[+] 钱包生成成功！/ Wallet generated successfully.${RESET}"

    mnemonic=$(grep "wallet: memo:" "$tmpfile" | head -1 | sed -E 's/^.*wallet: memo: (.*)$/\1/')
    private_key=$(grep 'private key: base58' "$tmpfile" | head -1 | sed -E 's/^.*private key: base58 "(.*)".*$/\1/')
    public_key=$(grep 'public key: base58' "$tmpfile" | head -1 | sed -E 's/^.*public key: base58 "(.*)".*$/\1/')

    echo -e "\n${YELLOW}=== 请务必保存以下信息！/ PLEASE SAVE THESE INFO! ===${RESET}"
    echo -e "${BOLD}助记词 (Mnemonic):${RESET}\n$mnemonic\n"
    echo -e "${BOLD}私钥 (Private Key):${RESET}\n$private_key\n"
    echo -e "${BOLD}公钥 (Public Key):${RESET}\n$public_key\n"
    echo -e "${YELLOW}========================================${RESET}\n"
  else
    echo -e "${RED}[-] 钱包生成失败！/ Wallet generation failed!${RESET}"
  fi

  rm -f "$tmpfile"
  pause_and_return
}

# ========= 设置挖矿公钥 / Set Mining Public Key =========
function configure_mining_key() {
  if [ ! -f "$NCK_DIR/Makefile" ]; then
    echo -e "${RED}[-] 找不到 Makefile，无法设置公钥！${RESET}"
    pause_and_return
    return
  fi

  read -p "[?] 输入你的挖矿公钥 / Enter your mining public key: " key
  sed -i "s|^export MINING_PUBKEY :=.*$|export MINING_PUBKEY := $key|" "$NCK_DIR/Makefile"
  echo -e "${GREEN}[+] 挖矿公钥已设置 / Mining key updated.${RESET}"

  pause_and_return
}

# ========= 启动 Leader 节点 / Run Leader Node =========
function start_leader_node() {
  echo -e "[*] 启动 Leader 节点 / Starting leader node..."
  # 先清理已存在的 leader 会话
  if screen -list | grep -q "[.]leader"; then
    screen -S leader -X quit
    sleep 1
  fi
  screen -dmS leader bash -c "cd \"$NCK_DIR\" && make run-nockchain-leader"
  sleep 2
  if screen -list | grep -q "[.]leader"; then
    echo -e "${GREEN}[+] Leader 节点运行中 / Leader node running.${RESET}"
    echo -e "${YELLOW}[!] 正在进入日志界面，按 Ctrl+A+D 可退出返回主菜单 / Ctrl+A+D to detach.${RESET}"
    screen -r leader
  else
    echo -e "${RED}[-] Leader 节点启动失败 / Leader node failed to start.${RESET}"
  fi
  pause_and_return
}

# ========= 启动 Follower 节点 / Run Follower Node =========
function start_follower_node() {
  echo -e "[*] 启动 Follower 节点 / Starting follower node..."
  # 先清理已存在的 follower 会话
  if screen -list | grep -q "[.]follower"; then
    screen -S follower -X quit
    sleep 1
  fi
  screen -dmS follower bash -c "cd \"$NCK_DIR\" && make run-nockchain-follower"
  sleep 2
  if screen -list | grep -q "[.]follower"; then
    echo -e "${GREEN}[+] Follower 节点运行中 / Follower node running.${RESET}"
    echo -e "${YELLOW}[!] 正在进入日志界面，按 Ctrl+A+D 可退出返回主菜单 / Ctrl+A+D to detach.${RESET}"
    screen -r follower
  else
    echo -e "${RED}[-] Follower 节点启动失败 / Follower node failed to start.${RESET}"
  fi
  pause_and_return
}

# ========= 查看节点日志 / View Logs =========
function view_logs() {
  echo ""
  echo "查看节点日志 / View screen logs:"
  echo "  1) Leader 节点"
  echo "  2) Follower 节点"
  echo "  0) 返回主菜单 / Return to menu"
  echo ""
  read -p "选择查看哪个节点日志 / Choose log to view: " log_choice
  case "$log_choice" in
    1)
      if screen -list | grep -q "[.]leader"; then
        screen -r leader
      else
        echo -e "${RED}[-] Leader 节点未运行 / Leader node not running.${RESET}"
      fi
      ;;
    2)
      if screen -list | grep -q "[.]follower"; then
        screen -r follower
      else
        echo -e "${RED}[-] Follower 节点未运行 / Follower node not running.${RESET}"
      fi
      ;;
    0) return ;;
    *) echo -e "${RED}[-] 无效选项 / Invalid option.${RESET}" ;;
  esac
  pause_and_return
}

# ========= 等待任意键继续 / Pause & Return =========
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
  echo "  4) 启动 Leader 节点 / Start Leader Node (实时日志)"
  echo "  5) 启动 Follower 节点 / Start Follower Node (实时日志)"
  echo "  6) 查看节点日志 / View Node Logs"
  echo "  0) 退出 / Exit"
  echo ""
  read -p "请输入编号 / Enter your choice: " choice

  case "$choice" in
    1) setup_all ;;
    2) generate_wallet ;;
    3) configure_mining_key ;;
    4) start_leader_node ;;
    5) start_follower_node ;;
    6) view_logs ;;
    0) echo "已退出 / Exiting."; exit 0 ;;
    *) echo -e "${RED}[-] 无效选项 / Invalid option.${RESET}"; pause_and_return ;;
  esac
}

# ========= 启动主程序 / Entry =========
main_menu
