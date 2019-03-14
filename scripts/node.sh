#!/usr/bin/env bash

# Copyright 2019 The Goodrain Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

[[ $DEBUG ]] && set -ex

node_role=$1
node_hostname=$2
node_ip=$3
login_type=$4
login_key=$5
node_uuid=$6

get_port=$(cat /opt/rainbond/rainbond-ansible/roles/rainvar/defaults/main.yml | grep install_ssh_port | awk '{print $2}')
node_port=${get_port:-22}

[ -z "$node_uuid" ] && echo "node uuid is null" && exit 1

ssh_key_copy()
{
    # delete history
    # sed "/$1/d" -i ~/.ssh/known_hosts

    # start copy 
    expect -c "
    set timeout 100
    spawn ssh-copy-id root@$1 -p $3
    expect {
    \"yes/no\"   { send \"yes\n\"; exp_continue; }
    \"password\" { send \"$2\n\"; }
    \"already exist on the remote system\" { exit 1; }
    }
    expect eof
    "
}

check_ip_reachable(){
    ping -c2 $1 >/dev/null 2>&1 
    echo $?
}
echo "check ip if reachable"
[ "$(check_ip_reachable $node_ip)" -ne 0 ] && echo "Destination Host ${node_ip} Unreachable..." && exit 1

if [ "$login_type" == "pass" ]; then
    echo "configure ssh for secure login"
    ssh_key_copy $node_ip $login_key $node_port
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
    echo "add new node: ${node_ip}:${node_port} ---> ${node_uuid}"
    sed -i "/\[all\]/a$node_uuid ansible_host=$node_ip ansible_port=$node_port ip=$node_ip port=$node_port" inventory/hosts
    if [ "$node_role" == "compute" ]; then
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

check_ssh(){
    ansible -i /opt/rainbond/rainbond-ansible/inventory/hosts $1  -a 'uptime' | grep rc=0 >/dev/null
    echo $?
}

cd /opt/rainbond/rainbond-ansible

deploy_type=$(cat /opt/rainbond/rainbond-ansible/roles/rainvar/defaults/main.yml | grep "deploy" | awk '{print $2}')

[ "$(check_exist $node_uuid $node_ip)" -eq 0 ] && new_node || exist_node

echo "check ip if ssh"
[ "$(check_ssh $node_uuid)" -ne 0 ] && echo "Make sure you can SSH in ${node_ip}" && exit 1

if [ "$node_role" == "compute" ]; then
    if [ "$deploy_type" == "thirdparty" ]; then
        ansible-playbook -i inventory/hosts hack/thirdparty/addnode.yml --limit $node_uuid
    else
        ansible-playbook -i inventory/hosts addnode.yml --limit $node_uuid
    fi
else
    if [ "$deploy_type" == "thirdparty" ]; then
        ansible-playbook -i inventory/hosts hack/thirdparty/addmaster.yml --limit $node_uuid
    else
        ansible-playbook -i inventory/hosts addmaster.yml --limit $node_uuid
    fi
fi
