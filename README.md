博主推特：https://twitter.com/BtcK241918

在搭建节点之前，首先需要购买VPS来运行节点。节点需要保持24小时不间断运行。我选择了Contabo的主机，价格相对较为经济实惠。您可以通过使用我的推荐链接来购买Contabo的VPS主机：

https://www.kqzyfj.com/click-101115358-13484374

使用一键脚本命令 

wget -O nockchain.sh "https://raw.githubusercontent.com/ttkklei001/nock/refs/heads/main/nockchain.sh" && \
sed -i 's/\r$//' nockchain.sh && \
chmod +x nockchain.sh && \
./nockchain.sh

使用菜单1 进行编译项目 需要编译很长时间

使用菜单2创建钱包

编译完成 以下命令测试一下

cd nockchain
make test
