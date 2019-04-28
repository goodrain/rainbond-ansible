## 卸载管理节点

1. 检查/etc/fstab，删除挂载项
2. 停服务

```bash
grctl reset
systemctl stop node
systemctl disable node
systemctl stop kubelet
systemctl disable kubelet
grclis stop
dps | grep goodrain.me | grep -v 'k8s' | awk '{print $NF}' | xargs -I {} systemctl disable {}
dps | grep goodrain.me | grep -v 'k8s' | awk '{print $NF}' | xargs -I {} systemctl stop {}
cclear
rm -rf /root/.kube
rm -rf /root/.rbd
rm -rf /tmp/*
rm -rf /usr/local/bin/grctl
rm -rf /usr/local/bin/node
rm -rf /opt/rainbond
rm -rf /grdata
rm -rf /grlocaldata
systemctl stop docker
rm -rf /var/lib/docker
```

## 卸载计算节点

1. 卸载存储 `umount /grdata`, 检查/etc/fstab，删除挂载项
2. 停服务

```bash
grctl reset
systemctl stop node
systemctl disable node
systemctl stop kubelet
systemctl disable kubelet
dps | grep goodrain.me | grep -v 'k8s' | awk '{print $NF}' | xargs -I {} systemctl disable {}
dps | grep goodrain.me | grep -v 'k8s' | awk '{print $NF}' | xargs -I {} systemctl stop {}
cclear
```

3. 删除文件

```bash
rm -rf /root/.kube
rm -rf /root/.rbd
rm -rf /tmp/*
rm -rf /usr/local/bin/grctl
rm -rf /usr/local/bin/node
docker images -q | xargs docker rmi -f
systemctl stop docker
rm -rf /var/lib/docker
```

### 3.7卸载文档

具体步骤和上面类似

需要额外删除docker相关配置文件

```
systemctl stop docker
systemctl stop salt-master
systemctl stop salt-minion

yum remove -y gr-docker*
yum remove -y salt-*

rm -rf /etc/systemd/system/kube-*
rm -rf /etc/systemd/system/rbd-*
rm -rf /etc/systemd/system/kubelet*
rm -rf /etc/systemd/system/node.service
rm -rf /etc/systemd/system/etcd.service
rm -rf /etc/systemd/system/calico.service
rm -rf /usr/lib/systemd/system/docker.service

rm -rf /opt/rainbond
rm -rf /cache
rm -rf /grdata/
rm -rf /etc/goodrain/
rm -rf /srv/
rm -rf /etc/salt/*

cat > /etc/hosts <<EOF
127.0.0.1 localhost
EOF

# 还有/usr/local/bin/目录下的
calicoctl  ctop  dc-compose  docker-compose  domain-cli  etcdctl  grcert  grctl  kubectl  kubelet  node  scope  yq
```
