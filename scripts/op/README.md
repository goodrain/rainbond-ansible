# Usage

## lb

```
cd /opt/rainbond/rainbond-ansible
# 法1
scripts/op/lb.sh lb <hostname> <节点ip> ssh /root/.ssh/id_rsa.pub <节点uid>
# 法2
scripts/op/lb.sh lb <hostname> <节点ip> pass <密码> <节点uid>
```

## network

```
# 重置网络, 将calico改为flannel
cd /opt/rainbond/rainbond-ansible
scripts/op/network.sh calico flannel
```