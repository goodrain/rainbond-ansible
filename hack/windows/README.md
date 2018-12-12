## Windows 节点

## 1. 安装存储

```
Install-WindowsFeature NFS-Client
```

#### 1.1 nfs 存储

```
net use z: \\<管理节点ip>\grdata
```

修改windows挂载nfs权限问题，可参考docs部分，需要修改注册表

#### 1.2 smb 存储

挂载方式同nfs

## 2. 安装docker

可参考官方安装，配置docker,daemon.json文件

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

拉取镜像

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
rainbond-node.exe
rainbond-chaos.exe
rainbond-windowsutil.exe
flanneld.exe
etcdctl.exe
etcd.exe
kubelet.exe
kubectl.exe
```

## 4. 修改hostID

根据c:\rainbond\node_host_uuid.conf来修改c:\rainbond\conf\win.yaml的关于kubelet uuid的信息