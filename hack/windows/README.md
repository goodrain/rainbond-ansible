## Windows 节点

## 1. 安装存储

```
Install-WindowsFeature NFS-Client
```

#### 1.1 smb 存储

```
net use z: \\<管理节点ip>\grdata
```

## 2. 安装docker

可参考[安装](http://t.goodrain.com/t/windows-docker/656)，配置docker,daemon.json文件

```
{
    "insecure-registries" : ["goodrain.me"],
    "log-driver": "json-file",
    "log-level": "warn",
    "log-opts": {
      "max-size": "20m",
      "max-file": "2"
      }
}
```

windows上拉取镜像

```
docker pull microsoft/nanoserver:1803
docker pull microsoft/windowsservercore:1803
docker pull rainbond/win-pause:1803
```

## 3. 安装rainbond-node

```
md c:\rainbond\conf
md c:\rainbond\cni
md c:\rainbond\log
md c:\rainbond\scripts
```

目录格式大概如下：

```
# 默认都在 c:\rainbond\目录下
cni
cni/config/cni.conf
cni/flannel.exe
cni/host-local.exe
cni/win-bridge.exe
conf/win.yaml
config # k8s admin.kubeconfig文件
scripts/helper.psm1
scripts/hns.psm1
start-flannel.ps1
start-kubelet.ps1
# 手动编译rainbond项目
rainbond-node.exe
rainbond-chaos.exe
rainbond-windowsutil.exe
# 对象存储下载
flanneld.exe http://rainbond-pkg.oss-cn-shanghai.aliyuncs.com/win/flanneld.exe
# 可下载官方相关二进制
etcdctl.exe
etcd.exe
kubelet.exe
kubectl.exe
```

## 4. 修改hostID

根据c:\rainbond\node_host_uuid.conf来修改c:\rainbond\conf\win.yaml的关于kubelet uuid的信息

> flannel subnet.env 应该在c:\run\flannel\subnet.env

```
FLANNEL_NETWORK=10.20.0.0/16
FLANNEL_SUBNET=10.20.48.1/24
FLANNEL_MTU=1500
FLANNEL_IPMASQ=true
```

