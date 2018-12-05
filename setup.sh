#!/bin/bash
#======================================================================================================================
#
#          FILE: setup.sh
#
#   DESCRIPTION: Install Rainbond Cluster
#
#          BUGS: https://github.com/goodrain/rainbond-install/issues
#
#     COPYRIGHT: (c) 2018 by the Goodrain Delivery Team.
#
#       LICENSE: Apache 2.0
#       CREATED: 08/03/2018 11:38:02 AM
#======================================================================================================================

[[ $DEBUG ]] && set -x

IIP=$1
DEPLOY_TYPE=${2:-onenode}
INSTALL_TYPE=${3:-online}
NETWORK_TYPE=${4:-calico}

DOMAIN_API="http://domain.grapps.cn"

[ -z "$1" ] && exit 1
[ ! -d "/opt/rainbond/.init" ] && mkdir -p /opt/rainbond/.init

init(){
    [ ! -f "/opt/rainbond/.init/uuid" ] && (
        uuid=$(uuidgen)
        [ ! -z "$uuid" ] && echo "$uuid" > /opt/rainbond/.init/uuid
    )
    [ ! -f "/opt/rainbond/.init/secretkey" ] && (
        secretkey=$(pwgen 32 1)
        [ ! -z "secretkey" ] &&  (
            echo "$secretkey" > /opt/rainbond/.init/secretkey
            sed -i -r  "s/(^secretkey: ).*/\1$secretkey/" roles/rainvar/defaults/main.yml
        )
    )
    [ ! -f "/opt/rainbond/.init/db" ] && (
        db=$(pwgen 8 1)
        [ ! -z "db" ] &&  (
            echo "$db" > /opt/rainbond/.init/db
            sed -i -r  "s/(^db_pass: ).*/\1$db/" roles/rainvar/defaults/main.yml
        )
    )
    [ ! -f "/root/.ssh/id_rsa.pub" ] && (
        ssh-keygen -t rsa -f /root/.ssh/id_rsa -P ""
    )
    cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
}

get_default_dns() {
    dns=$(cat /etc/resolv.conf | grep "^nameserver" | head -1 | awk '{print $2}')
    [ -z "$dns" ] && dns="114.114.114.114"
    echo "default_dns_local: $dns"
    sed -i -r  "s/(^default_dns_local: ).*/\1$dns/" roles/rainvar/defaults/main.yml
}

get_default_netwrok_type() {
    if [ "$NETWORK_TYPE" == "flannel" ];then
        network="flannel"
    else
        network="calico"
    fi
    echo "Defalut Network Type: ${network}"
    sed -i -r  "s/(^CLUSTER_NETWORK: ).*/\1$network/" roles/rainvar/defaults/main.yml

}

get_distribution() {
	lsb_dist=""
	# Every system that we officially support has /etc/os-release
	if [ -r /etc/os-release ]; then
		lsb_dist="$(. /etc/os-release && echo "$ID")"
	fi
	# Returning an empty string here should be alright since the
	# case statements don't act unless you provide an actual value
	echo "$lsb_dist"
}

lsb_dist=$( get_distribution )
lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"

command_exists() {
	command -v "$@" > /dev/null 2>&1
}

ee_notice() {
	echo
	echo
	echo "  WARNING: $1 is now only supported by Rainbond"
	echo "           Check https://www.rainbond.com for information on Rainbond"
	echo
	echo
}

Generate_domain(){
    echo "" > /opt/rainbond/.domain.log
    DOMAIN_IP=$1
    DOMAIN_UUID=$(cat /opt/rainbond/.init/uuid)
    DOMAIN_TYPE=False
    DOMAIN_LOG="/opt/rainbond/.domain.log"
    AUTH=$(cat /opt/rainbond/.init/secretkey)
    curl -s --connect-timeout 20  -d 'ip='"$DOMAIN_IP"'&uuid='"$DOMAIN_UUID"'&type='"$DOMAIN_TYPE"'&auth='"$AUTH"'' -X POST  $DOMAIN_API/domain/new > $DOMAIN_LOG
    cat > /tmp/.lock.domain <<EOF
curl -s --connect-timeout 20  -d 'ip='"$DOMAIN_IP"'&uuid='"$DOMAIN_UUID"'&type='"$DOMAIN_TYPE"'&auth='"$AUTH"'' -X POST  $DOMAIN_API/new > $DOMAIN_LOG
EOF

    [ -f $DOMAIN_LOG ] && wilddomain=$(cat $DOMAIN_LOG )

    if [[ "$wilddomain" == *grapps.cn ]];then
        echo "wild-domain: $wilddomain"
        sed -i -r  "s/(^app_domain: ).*/\1$wilddomain/" roles/rainvar/defaults/main.yml
    else
        echo "not generate, will use example"
        sed -i -r  "s/(^app_domain: ).*/\1paas.example.com/" roles/rainvar/defaults/main.yml
    fi
}

online_init(){
    [ ! -f "/opt/rainbond/.init/domain" ] && Generate_domain $1
    case "$lsb_dist" in
		ubuntu|debian)
            apt-get update
            apt-get install sshpass python-pip uuid-runtime pwgen -y
            pip install ansible -i https://pypi.tuna.tsinghua.edu.cn/simple
		;;
		centos|neokylin)
            yum install -y epel-release
            yum makecache fast
            yum install -y sshpass python-pip uuidgen pwgen
            pip install ansible -i https://pypi.tuna.tsinghua.edu.cn/simple
		;;
		rhel|ol|sles)
			ee_notice "$lsb_dist"
			exit 1
			;;
		*)
            exit 1
		;;

    esac
}

offline_init(){
    case "$lsb_dist" in
		ubuntu|debian)
            # local todo
            # apt-get update
            # apt-get install sshpass python-pip uuid-runtime pwgen -y
            # pip install ansible -i https://pypi.tuna.tsinghua.edu.cn/simple
            echo "todo"
		;;
		centos|neokylin)
            #yum install -y epel-release
            #yum makecache fast
            #yum install -y sshpass python-pip uuidgen pwgen
            #pip install ansible -i https://pypi.tuna.tsinghua.edu.cn/simple
            cat > /etc/yum.repos.d/rainbond.repo << EOF
[rainbond]
name=rainbond_offline_install_repo
baseurl=file:///opt/rainbond/rainbond-ansible/offline/pkgs/centos/7/
gpgcheck=0
enabled=1
EOF
            yum makecache
            yum install -y sshpass python-pip uuidgen pwgen

		;;
		*)
            ee_notice "$lsb_dist"
            exit 1
		;;

    esac
}

get_default_install_type(){
    echo "Install Type: $INSTALL_TYPE"
    sed -i -r  "s/(^install_type: ).*/\1$INSTALL_TYPE/" roles/rainvar/defaults/main.yml
    if [ "$INSTALL_TYPE" == "online" ];then
        online_init
    else
        offline_init
    fi
}

onenode(){
    init
    get_default_dns
    get_default_netwrok_type
    get_default_install_type
    sed -i "s#10.10.10.13#$IIP#g" inventory/hosts
    ansible-playbook -i inventory/hosts setup.yml
}

case $DEPLOY_TYPE in
    onenode)
        onenode
    ;;
    *)
        exit 0
    ;;
esac