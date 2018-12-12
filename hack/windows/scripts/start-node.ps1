Param(
    [parameter(Mandatory = $true)] $ManagementIP,
    [parameter(Mandatory = $true)] $ETCDIP

)

$BaseDir = "c:\rainbond"
$LogDir = "$BaseDir\log"

function SetupDirectories()
{
    md $BaseDir -ErrorAction Ignore
    md $LogDir -ErrorAction Ignore
    md $BaseDir\conf -ErrorAction Ignore
    md $BaseDir\cni\conf -ErrorAction Ignore
}

$infraPodImage=docker images rainbond/win-pause -q
if (!$infraPodImage)
{
    docker pull rainbond/win-pause
}

SetupDirectories

c:\rainbond\rainbond-node.exe --register-service --log-level=info --log-file=c:\rainbond\log\node.log --kube-conf=c:\rainbond\config --etcd=http://$ETCDIP:2379 --hostIP=$ManagementIP --noderule=compute --run-mode=worker --nodeid-file=c:\rainbond\node_host_uuid.conf --service-list-file=c:\rainbond\conf