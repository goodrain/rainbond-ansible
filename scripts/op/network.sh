#!/bin/bash

set -e

old_nk_type=$1
new_nk_type=$2

SCRIPTSPATH="/opt/rainbond/rainbond-ansible"
CURRENT_NETWORK=$(cat $SCRIPTSPATH/roles/rainvar/defaults/main.yml | grep CLUSTER_NETWORK  | awk '{print $2}')

if [ -f "${SCRIPTSPATH}/scripts/installer/functions.sh" ]; then
	source "${SCRIPTSPATH}/scripts/installer/functions.sh" || notice "not found functions.sh"
fi

if [ "$old_nk_type" != "calico" -a "$old_nk_type" != "flannel" ];then
    notice "修改前网络类型不允许为空或仅支持calico/flannel"
fi

if [ "$new_nk_type" != "calico" -a "$new_nk_type" != "flannel" ];then
    notice "修改后网络类型不允许为空或仅支持calico/flannel"
fi

if [ "$new_nk_type" == "$CURRENT_NETWORK" ]; then
    notice "不允许新修改网络类型和当前网络类型一致"
fi

if [ "$old_nk_type" == "$new_nk_type" ]; then
    notice "不允许修改前网络类型和修改后网络类型一致"
fi


reset_old_nk(){
    progress "start reset network"
    run ansible-playbook -i ${SCRIPTSPATH}/inventory/hosts ${SCRIPTSPATH}/scripts/yaml/reset_network.yaml
}

clear_iptables(){
    read -n1 -p "Are you sure you want to clear iptables rules [Y/N]?" answer
    case $answer in
    Y | y)
        progress "clean iptables rules"
        run ansible -i ${SCRIPTSPATH}/inventory/hosts all -m shell -a 'iptables -F && iptables -X && iptables -F '
        ;;
    *)
        :
        ;;
    esac
}

init_new_nk(){
    info "change network type" "$old_nk_type --> $new_nk_type"
    sed -i -r "s/(^CLUSTER_NETWORK: ).*/\1$new_nk_type/" ${SCRIPTSPATH}/roles/rainvar/defaults/main.yml
    progress "start init network"
    run ansible-playbook -i ${SCRIPTSPATH}/inventory/hosts ${SCRIPTSPATH}/scripts/yaml/init_network.yaml
    run ansible -i ${SCRIPTSPATH}/inventory/hosts all -m shell -a 'node service update'
}

reset_old_nk
clear_iptables
init_new_nk