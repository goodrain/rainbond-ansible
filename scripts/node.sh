#!/bin/bash

[[ $DEBUG ]] && set -ex

node_role=$1
node_hostname=$2
node_ip=$3
login_type=$4
login_key=$5
node_uuid=$6

[ -z "$node_uuid" ] && echo "node uuid is null" && exit 1

ssh_key_copy()
{
    # delete history
    # sed "/$1/d" -i ~/.ssh/known_hosts

    # start copy 
    expect -c "
    set timeout 100
    spawn ssh-copy-id root@$1
    expect {
    \"yes/no\"   { send \"yes\n\"; exp_continue; }
    \"password\" { send \"$2\n\"; }
    \"already exist on the remote system\" { exit 1; }
    }
    expect eof
    "
}

if [ "$login_type" == "pass" ];then
    echo "configure ssh for secure login"
    ssh_key_copy $node_ip $login_key
fi

check_exist(){
    local check_status=0
    cat /opt/rainbond/rainbond-ansible/inventory/hosts | grep ansible | awk '{print $1}' | sort -ru | grep "$1" > /dev/null
    [ "$?" -eq 0 ] && check_status=1
    cat /opt/rainbond/rainbond-ansible/inventory/hosts | grep ansible | awk -F'[ =]' '{print $3}' | sort -ru | grep "$2" > /dev/null
    [ "$?" -eq 0 ] && check_status=2
    cat /opt/rainbond/.init/node.uuid | grep "$2" > /dev/null
    [ "$?" -eq 0 ] && check_status=3
    echo $check_status 
}

# 新添加节点
new_node(){
    echo "add new node: ${node_ip} ---> ${node_uuid}"
    sed -i "/\[all\]/a$node_uuid ansible_host=$node_ip ip=$node_ip" inventory/hosts
    if [ "$node_role" == "compute" ];then
        sed -i "/\[new-worker\]/a$node_uuid" inventory/hosts
    else
        sed -i "/\[new-master\]/a$node_uuid" inventory/hosts  
    fi
    cat >> /opt/rainbond/.init/node.uuid <<EOF
$node_ip:$node_uuid
EOF
}

# 已存在节点
exist_node(){
    old_node_uuid=$(cat /opt/rainbond/.init/node.uuid | grep "$node_ip" | awk -F: '{print $2}')
    echo "update node: ${node_ip} ${old_node_uuid} ---> ${node_uuid}"
    sed -i "s#${old_node_uuid}#${node_uuid}#g" inventory/hosts
    sed -i "s#${old_node_uuid}#${node_uuid}#g" /opt/rainbond/.init/node.uuid
}

cd /opt/rainbond/rainbond-ansible

deploy_type=$(cat /opt/rainbond/rainbond-ansible/roles/rainvar/defaults/main.yml | grep "deploy" | awk '{print $2}')

[ "$(check_exist $node_uuid $node_ip)" -eq 0 ] && new_node || exist_node

if [ "$node_role" == "compute" ];then
    if [ "$deploy_type" == "thirdparty" ];then
        ansible-playbook -i inventory/hosts hack/thirdparty/addnode.yml --limit $node_uuid
    else
        ansible-playbook -i inventory/hosts addnode.yml --limit $node_uuid
    fi
else
    if [ "$deploy_type" == "thirdparty" ];then
        ansible-playbook -i inventory/hosts hack/thirdparty/addmaster.yml --limit $node_uuid
    else
        ansible-playbook -i inventory/hosts addmaster.yml --limit $node_uuid
    fi
fi
