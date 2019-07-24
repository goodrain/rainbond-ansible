# 安装说明

1. 通过grctl的方式安装
2. 通过源码的方式进行安装

## grctl方式

```
wget https://pkg.rainbond.com/releases/common/v5.0/grctl
chmod +x ./grctl
./grctl init
```

## 源码方式

```
mkdir -pv /opt/rainbond
cd /opt/rainbond
git clone --depth 1 -b 5.0 https://github.com/goodrain/rainbond-ansible.git 
cd rainbond-ansible
# 编辑自定义选项 scripts/installer/global.sh

VIP=""
INSTALL_TYPE="online"
POD_NETWORK_CIDR=""
EIP=""
DEPLOY_TYPE="onenode"
NETWORK_TYPE="calico"
IIP="192.168.56.5"
storage="nfs"
storage_args="/grdata nfs rw 0 0"
role="master,worker"
DOMAIN=""

# 执行安装
./setup.sh
```

## 两者区别

grctl可以通过指定参数生成`scripts/installer/global.sh`文件,上述选项即通过grctl生成的

#### grctl init 目前可用参数说明

```
iip: 当前节点的内网ip，默认服务都是监听绑定此ip，如果未指定安装脚本会读取非lo/docker0的ip作为服务绑定ip，多网卡情况下需要指定此值。
rainbond-version: 指定安装使用的源码分支。默认是5.0，可选开发测试分支devel
install-type: 默认是在线安装online，可选参数为offline，离线需要提前准备好相关依赖包和镜像文件
deploy-type: 部署类型，默认是单节点，主要使用场景是HA模式，目前仅支持单节点
domain: 自定义域名，需要自行将自定义域名解析到iip上或者gateway所在节点的ip上
pod-cidr: 自定义应用分配的cidr，不指定会使用默认值 calico 192.168.0.0/16 flannel 10.244.0.0/16
network: 开源版支持 calico/flannel两种类型网络
```

#### 源码安装需要指定参数 

```
# /opt/rainbond/rainbond-ansible/scripts/installer/global.sh

INSTALL_TYPE="online"
POD_NETWORK_CIDR=""
DEPLOY_TYPE="onenode"
NETWORK_TYPE="calico"
IIP="192.168.56.5"
DOMAIN=""
```
