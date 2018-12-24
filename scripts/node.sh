#!/bin/bash

set -e

node_role=$1
node_hostname=$2
node_ip=$3
login_type=$4
login_key=$5
node_uuid=$6

if [ "$login_type" == "pass" ];then
    echo "configure ssh for secure login"
    echo yes | ssh-copy-id -i /root/.ssh/id_rsa.pub root@$node_ip -f 
fi

check_exist(){
    local check_status=0
    cat /opt/rainbond/rainbond-ansible/inventory/hosts | grep ansible | awk '{print $1}' | sort -ru | grep "$1" > /dev/null
    [ "$?" -eq 0 ] && check_status=1
    cat /opt/rainbond/rainbond-ansible/inventory/hosts | grep ansible | awk -F'[ =]' '{print $3}' | sort -ru | grep "$2" > /dev/null
    [ "$?" -eq 0 ] && check_status=2
    echo $check_status
}


[ "$(check_exist $node_hostname $node_ip)" -eq 0 ] || (echo "New compute node hostname or ip existing" && exit 1)

cd /opt/rainbond/rainbond-ansible

sed -i "/\[all\]/a$node_hostname ansible_host=$node_ip ip=$node_ip" inventory/hosts

cat >> /opt/rainbond/.init/node.uuid <<EOF
$node_ip:$node_ip
EOF

if [ "$node_role" == "master" ];then
    sed -i "/\[new-master\]/a$node_hostname" inventory/hosts
    ansible-playbook -i inventory/hosts addmaster.yml
else
    sed -i "/\[new-worker\]/a$node_hostname" inventory/hosts
    ansible-playbook -i inventory/hosts addnode.yml
fi
