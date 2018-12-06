#!/bin/bash 

DOMAIN_API="http://domain.grapps.cn"
# 内网ip
IIP=""
# 公网ip
EIP=""
# VIP
VIP=""
# 域名
DOMAIN=""
# 安装类型 online/offline
INSTALL_TYPE="online"
# 安装节点类型 onenode/multinode 
DEPLOY_TYPE=onenode
# 网络类型 calico/flannel/midonet
NETWORK_TYPE="calico"
# 存储类型 nfs/gfs
storage=""
# 存储类型参数 args
storage_args=""