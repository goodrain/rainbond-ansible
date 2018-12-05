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

[[ $DEBUG ]] && set -ex || set -e

IIP=$1
DEPLOY_TYPE=${2:-onenode}
INSTALL_TYPE=${3:-online}
NETWORK_TYPE=${4:-calico}
REINIT=${5}
DOMAIN_API="http://domain.grapps.cn"

installer_dir="$(dirname "${0}")"

[ -z "$1" ] && exit 1
[ ! -d "/opt/rainbond/.init" ] && mkdir -p /opt/rainbond/.init

if [ -f "${installer_dir}/scripts/installer/functions.sh" ]; then
	source "${installer_dir}/scripts/installer/functions.sh" || exit 1
fi

get_default_config(){
    progress "Generate the default configuration"
    [ ! -f "/opt/rainbond/.init/uuid" ] && (
        uuid=$(uuidgen)
        [ ! -z "$uuid" ] && echo "$uuid" > /opt/rainbond/.init/uuid
    )
    [ ! -f "/opt/rainbond/.init/secretkey" ] && (
        secretkey=$(pwgen 32 1)
        [ ! -z "$secretkey" ] &&  (
            echo "$secretkey" > /opt/rainbond/.init/secretkey
            sed -i -r  "s/(^secretkey: ).*/\1$secretkey/" roles/rainvar/defaults/main.yml
        )
    )
    [ ! -f "/opt/rainbond/.init/db" ] && (
        db=$(pwgen 8 1)
        [ ! -z "$db" ] &&  (
            echo "$db" > /opt/rainbond/.init/db
            sed -i -r  "s/(^db_pass: ).*/\1$db/" roles/rainvar/defaults/main.yml
        )
    )
    [ ! -f "/root/.ssh/id_rsa.pub" ] && (
        ssh-keygen -t rsa -f /root/.ssh/id_rsa -P "" 1>/dev/null
    )
    cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
    touch /opt/rainbond/.init/.init_done
}

get_default_dns() {
    dns=$(cat /etc/resolv.conf | grep "^nameserver" | head -1 | awk '{print $2}')
    [ -z "$dns" ] && dns="114.114.114.114"
    progress "default_dns_local: $dns"
    sed -i -r  "s/(^default_dns_local: ).*/\1$dns/" roles/rainvar/defaults/main.yml
}

get_default_netwrok_type() {
    if [ "$NETWORK_TYPE" == "flannel" ];then
        network="flannel"
    else
        network="calico"
    fi
    progress "Defalut Network Type: ${network}"
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
        progress "wild-domain: $wilddomain"
        sed -i -r  "s/(^app_domain: ).*/\1$wilddomain/" roles/rainvar/defaults/main.yml
    else
        progress "not generate rainbond domain, will use example: pass.example.com"
        sed -i -r  "s/(^app_domain: ).*/\1paas.example.com/" roles/rainvar/defaults/main.yml
    fi
}

copy_from_centos(){
    progress "Update default $1 to CentOS"
    cp -a ./hack/chinaos/centos-release /etc/os-release
    mkdir -p /etc/yum.repos.d/backup >/dev/null 2>&1
    mv -f /etc/yum.repos.d/*.repo /etc/yum.repos.d/backup >/dev/null 2>&1
    cp -a ./hack/chinaos/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo
}

other_type_linux(){
    lsb_dist=$( get_distribution )
    lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"
    case "$lsb_dist" in
        neokylin)
            copy_from_centos $lsb_dist
        ;;
    esac
}

online_init(){
    lsb_dist=$( get_distribution )
    lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"
    case "$lsb_dist" in
		ubuntu|debian)
            apt-get update 1>/dev/null
            apt-get install sshpass python-pip uuid-runtime pwgen -y 1>/dev/null
            pip install ansible -i https://pypi.tuna.tsinghua.edu.cn/simple -q
		;;
		centos)
            yum install -y -q epel-release 1>/dev/null
            yum makecache fast 1>/dev/null
            yum install -y -q sshpass python-pip uuidgen pwgen 1>/dev/null
            pip install ansible -i https://pypi.tuna.tsinghua.edu.cn/simple -q
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
    lsb_dist=$( get_distribution )
    lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"
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
    progress "Install Type: $INSTALL_TYPE"
    sed -i -r  "s/(^install_type: ).*/\1$INSTALL_TYPE/" roles/rainvar/defaults/main.yml
    if [ "$INSTALL_TYPE" == "online" ];then
        online_init
    else
        offline_init
    fi
}

onenode(){
    progress "Install Rainbond On Single Node"
    other_type_linux 
    get_default_dns
    get_default_netwrok_type
    get_default_install_type
    [ ! -f "/opt/rainbond/.init/.init_done" ] && get_default_config
    [ ! -f "/opt/rainbond/.init/domain" ] && Generate_domain $IIP
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
