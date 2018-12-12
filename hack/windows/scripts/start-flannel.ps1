Param(
    [parameter(Mandatory = $true)] $ManagementIP
)

$BaseDir = "c:\rainbond"
$helper = "$BaseDir\scripts\helper.psm1"

ipmo $helper

# Prepare Network & Start Infra services
$NetworkMode = "L2Bridge"
# $NetworkName = "cbr0"
# CleanupOldNetwork $NetworkName

# before flannel start, kube-api must have this node
$hns = "$BaseDir\scripts\hns.psm1"
ipmo $hns

# Create a L2Bridge to trigger a vSwitch creation. Do this only once as it causes network blip
if(!(Get-HnsNetwork | ? Name -EQ "External"))
{
    New-HNSNetwork -Type $NetworkMode -AddressPrefix "192.168.255.0/30" -Gateway "192.168.255.1" -Name "External" -Verbose
}
# Start Flanneld
Start-Sleep 5
# CleanupOldNetwork $NetworkName
# Start FlannelD, which would recreate the network.
# Expect disruption in node connectivity for few seconds
# [Environment]::SetEnvironmentVariable("NODE_NAME", (hostname).ToLower())
C:\rainbond\flanneld.exe --etcd-endpoints=http://192.168.1.200:2379 --etcd-prefix=/kubernetes/network --iface="$ManagementIP" --healthz-port=10110 --ip-masq=1 --kube-subnet-mgr=1
