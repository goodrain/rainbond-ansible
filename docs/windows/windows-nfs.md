## Windows 挂载NFS存储

#### 安装nfs

```
Get-WindowsFeature -Name NFS*
Install-WindowsFeature -Name NFS-Client
```

#### 修改windows注册表

```
regedit
HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\ClientForNFS\CurrentVersion\Default
# 新增DWORDkey,值为0
AnonymousGID
AnonymousUID
# 保存完重启机器
restart-computer -Force
```

#### nfs挂载/卸载

```
# 关闭防火墙
netsh firewall set opmode DISABLE 
net use z: \\192.168.1.200\grdata
```

