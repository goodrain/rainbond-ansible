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

[[ $DEBUG ]] && set -ex || set -e

node_role=""
node_ip=""
login_type=""
login_key=""
node_uuid=""

while getopts ":r:i:t:k:u:" opt
do
    case $opt in
        r)
        node_role=$OPTARG
        [ -z "$node_role" ] && notice "node role is null" 
        ;;
        i)
        node_ip=$OPTARG
        [ -z "$node_ip" ] && notice "node ip is null" 
        ;;
        t)
        login_type=$OPTARG
        [ -z "$login_type" ] && notice "node ssh login type is null" 
        ;;
        k)
        login_key=$OPTARG
        [ -z "$login_key" ] && notice "node ssh login key is null" 
        ;;
        u)
        node_uuid=$OPTARG
        [ -z "$node_uuid" ] && notice "node uuid is null" 
        ;;
        ?)
        echo "Unknown parameter:-$opt [-r node_role] [-i node_ip] [-t login_type] [-k login_key] [-u node_uuid]"
        exit 1;;
    esac
done

declare -A yml_dict
role_choice="manage gateway compute"
yml_dict=(['manage']="addmaster.yml" ['gateway']="gateway.yml" ['compute']="addnode.yml")
get_port=$(cat /opt/rainbond/rainbond-ansible/roles/rainvar/defaults/main.yml | grep install_ssh_port | awk '{print $2}')
node_port=${get_port:-22}


SCRIPTSPATH="/opt/rainbond/rainbond-ansible"

if [ -f "${SCRIPTSPATH}/scripts/installer/functions.sh" ]; then
	source "${SCRIPTSPATH}/scripts/installer/functions.sh" || notice "not found functions.sh"
fi

[ -z "$node_uuid" ] && notice "node uuid is null" 

ssh_key_copy()
{
    # delete history
    # sed "/$1/d" -i ~/.ssh/known_hosts

    # start copy 
    expect -c "
    set timeout 100
    spawn ssh-copy-id root@$1 -p $3 -f
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
info "check ip if reachable"
[ "$(check_ip_reachable $node_ip)" -ne 0 ] && notice "Destination Host ${node_ip} Unreachable..." 

if [ "$login_type" == "pass" ]; then
    info "configure ssh for secure login"
    run ssh_key_copy $node_ip $login_key $node_port
fi

check_ssh(){
    ansible -i /opt/rainbond/rainbond-ansible/inventory/hosts $1  -a 'uptime' | grep rc=0 >/dev/null
    echo $?
}

cd /opt/rainbond/rainbond-ansible

deploy_type=$(cat /opt/rainbond/rainbond-ansible/roles/rainvar/defaults/main.yml | grep "deploy" | awk '{print $2}')

info "check ip if ssh"
[ "$(check_ssh $node_uuid)" -ne 0 ] && notice "Make sure you can SSH in ${node_ip}"

# 检查Role角色状态
check_var(){
    local role type
    role=$1
    role_type=$2
    echo ${role} | grep ${role_type} >/dev/null 2>&1
    echo $?
}

# 根据Role执行Ansible剧本
for role in $role_choice; do
    if [ "$(check_var $node_role $role)" -eq 0 ]; then
        if [ "$deploy_type" == "thirdparty" ]; then
            run ansible-playbook -i inventory/hosts hack/thirdparty/${yml_dict[$role]} -e noderule=$node_role --limit $node_uuid
        else
            run ansible-playbook -i inventory/hosts ${yml_dict[$role]} -e noderule=$node_role --limit $node_uuid
        fi
    fi
done
