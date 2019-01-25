#!/bin/bash
#======================================================================================================================
#
#          FILE: setup.sh
#
#   DESCRIPTION: Deploy Rainbond Cluster
#
#          BUGS: https://github.com/goodrain/rainbond-ansible/issues
#
#     COPYRIGHT: (c) 2018 by the Goodrain Delivery Team.
#
#       LICENSE: Apache 2.0
#       CREATED: 08/03/2018 11:38:02 AM
#======================================================================================================================

[[ $DEBUG ]] && set -ex || set -e

installer_dir="$(dirname "${0}")"

[ ! -d "/opt/rainbond/.init" ] && mkdir -p /opt/rainbond/.init

if [ -f "${installer_dir}/scripts/installer/functions.sh" ]; then
	source "${installer_dir}/scripts/installer/functions.sh" || exit 1
fi

if [ -f "${installer_dir}/scripts/installer/default.sh" ]; then
	source "${installer_dir}/scripts/installer/default.sh" || exit 1
fi

if [ -f "${installer_dir}/scripts/installer/global.sh" ]; then
	source "${installer_dir}/scripts/installer/global.sh" || exit 1
fi

[ -z "$IIP" ] && IIP=$1
[ -z "$IIP" ] && IIP=$( get_default_ip )
[ -z "$IIP" ] && notice "not found IIP"

get_default_config(){
    [ ! -f "/opt/rainbond/.init/uuid" ] && (
        uuid=$(uuidgen)
        [ ! -z "$uuid" ] && echo "$uuid" > /opt/rainbond/.init/uuid
    )
    [ ! -f "/opt/rainbond/.init/secretkey" ] && (
        secretkey=$(pwgen 32 1)
        [ ! -z "$secretkey" ] &&  (
            echo "$secretkey" > /opt/rainbond/.init/secretkey
        )
    )
    [ ! -f "/opt/rainbond/.init/db" ] && (
        db=$(pwgen 8 1)
        [ ! -z "$db" ] &&  (
            echo "$db" > /opt/rainbond/.init/db
            
        )
    )
    [ ! -f "/root/.ssh/id_rsa.pub" ] && (
        ssh-keygen -t rsa -f /root/.ssh/id_rsa -P "" 1>/dev/null
    )
    db=$(cat /opt/rainbond/.init/db)
    secretkey=$(cat /opt/rainbond/.init/secretkey)
    sed -i -r  "s/(^db_pass: ).*/\1$db/" roles/rainvar/defaults/main.yml
    sed -i -r  "s/(^secretkey: ).*/\1$secretkey/" roles/rainvar/defaults/main.yml
    cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
    touch /opt/rainbond/.init/.init_done
    info "Generate the default configuration" "$(cat /opt/rainbond/.init/uuid)/$(cat /opt/rainbond/.init/secretkey)"
    echo "" > /opt/rainbond/.init/node.uuid
}

get_default_dns() {
    dns=$(cat /etc/resolv.conf | grep "^nameserver" | head -1 | awk '{print $2}')
    [ -z "$dns" ] && dns="114.114.114.114"
    info "nameserver" "$dns"
    sed -i -r  "s/(^default_dns_local: ).*/\1$dns/" roles/rainvar/defaults/main.yml
}

get_default_netwrok_type() {
    if [ "$NETWORK_TYPE" == "flannel" ];then
        network="flannel"
    else
        network="calico"
    fi
    info "Pod Network Provider" "${network}"
    if [ -z "$POD_NETWORK_CIDR" ];then
        IP_INFO=$(ip ad | grep 'inet ' | egrep ' 10.|172.|192.168' | awk '{print $2}' | cut -d '/' -f 1 | grep -v '172.30.42.1')
        IP_ITEMS=($IP_INFO)
        INET_IP=${IP_ITEMS%%.*}
        if [ "$NETWORK_TYPE" == "flannel" ];then
            pod_network_cidr="${flannel_pod_network_cidr}"
        else
            if [ "$INET_IP" != "192" ];then
                pod_network_cidr="${calico_pod_network_cidr}"
            else
                pod_network_cidr="${pod_network_cidr_10}"
            fi
        fi
    else
        pod_network_cidr="${POD_NETWORK_CIDR}"
    fi
    info "Pod Network Cidr" "${pod_network_cidr}"
    sed -i -r "s/(^CLUSTER_NETWORK: ).*/\1$network/" roles/rainvar/defaults/main.yml
    sed -i -r "s#(^pod_cidr: ).*#\1$pod_network_cidr#" roles/rainvar/defaults/main.yml

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

Generate_domain(){
    DOMAIN_IP=$1
    DOMAIN_VIP=$2
    DOMAIN_UUID=$(cat /opt/rainbond/.init/uuid)
    DOMAIN_TYPE=False
    DOMAIN_LOG="/opt/rainbond/.domain.log"
    AUTH=$(cat /opt/rainbond/.init/secretkey)
    echo "" > $DOMAIN_LOG
    if [ -z "$DOMAIN" ];then
    if [ "$INSTALL_TYPE" == "online" ];then
        curl -s --connect-timeout 20  -d 'ip='"$DOMAIN_IP"'&uuid='"$DOMAIN_UUID"'&type='"$DOMAIN_TYPE"'&auth='"$AUTH"'' -X POST  $DOMAIN_API/domain/new > $DOMAIN_LOG
        cat > /tmp/.lock.domain <<EOF
curl -s --connect-timeout 20  -d 'ip='"$DOMAIN_IP"'&uuid='"$DOMAIN_UUID"'&type='"$DOMAIN_TYPE"'&auth='"$AUTH"'' -X POST  $DOMAIN_API/new > $DOMAIN_LOG
EOF
    fi
    [ -f $DOMAIN_LOG ] && wilddomain=$(cat $DOMAIN_LOG )
    if [[ "$wilddomain" == *grapps.cn ]];then
        info "wild-domain:" "$wilddomain"
        sed -i -r  "s/(^app_domain: ).*/\1$wilddomain/" roles/rainvar/defaults/main.yml
        [ ! -d "/opt/rainbond/bin" ] && mkdir -p /opt/rainbond/bin
        cp -a hack/tools/update-domain.sh /opt/rainbond/bin/.domain.sh
        chmod +x /opt/rainbond/bin/.domain.sh
    else
        info "not generate rainbond domain, will use example" "pass.example.com"
        sed -i -r  "s/(^app_domain: ).*/\1paas.example.com/" roles/rainvar/defaults/main.yml
    fi
    else
        info "custom domain:" "$DOMAIN"
        sed -i -r  "s/(^app_domain: ).*/\1$DOMAIN/" roles/rainvar/defaults/main.yml
    fi
    cat > /opt/rainbond/.init/domain.yaml <<EOF
iip: $DOMAIN_IP
vip: $DOMAIN_VIP
domain: $wilddomain
uuid: $DOMAIN_UUID
secretkey: $AUTH
api: $DOMAIN_API
EOF

}

up_domain_dns(){
    [ -f "/opt/rainbond/.init/domain.yaml" ] && (
        uid=$(cat /opt/rainbond/.init/domain.yaml | grep uuid | awk '{print $2}')
        iip=$(cat /opt/rainbond/.init/domain.yaml | grep iip | awk '{print $2}')
        domain=$(cat /opt/rainbond/.init/domain.yaml | grep domain | awk '{print $2}')
        DOMAIN_API=$(cat /opt/rainbond/.init/domain.yaml | grep api | awk '{print $2}')
        if [[ "$domain" =~ "grapps" ]];then
            curl -s --connect-timeout 20 ${DOMAIN_API}/status\?uuid=$uid\&ip=$iip\&type=True\&domain=$domain >/dev/null 
        fi
    ) || (
        # todo
        echo ""
    )
}

copy_from_centos(){
    info "Update default to CentOS" "$1"
    cp -a ./hack/chinaos/centos-release /etc/os-release
    mkdir -p /etc/yum.repos.d/backup >/dev/null 2>&1
    mv -f /etc/yum.repos.d/*.repo /etc/yum.repos.d/backup >/dev/null 2>&1
    cp -a ./hack/chinaos/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo
}

copy_from_ubuntu(){
    info "Update default to Ubuntu" "$1"
    cp -a ./hack/chinaos/ubuntu-release /etc/os-release
    cp -a ./hack/chinaos/ubuntu-lsb-release /etc/lsb-release
    cp -a /etc/apt/sources.list /etc/apt/sources.list.old
    cp -a ./hack/chinaos/sources.list /etc/apt/sources.list
}

centos_offline(){
    info "Remove default CentOS source"
    [ ! -d "/etc/yum.repos.d/backup" ] && mkdir -p /etc/yum.repos.d/backup
    mv -f /etc/yum.repos.d/*.repo /etc/yum.repos.d/backup
}

other_type_linux(){
    lsb_dist=$( get_distribution )
    lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"
    case "$lsb_dist" in
        neokylin)
            copy_from_centos $lsb_dist
        ;;
        kylin)
            copy_from_ubuntu $lsb_dist
        ;;    
    esac
}

online_init_docker_version(){

    [ ! -z "$DOCKER_VERSION" ] && (
        info "docker version" "$DOCKER_VERSION"
        sed -i -r  "s/(^docker_version: ).*/\1$DOCKER_VERSION/" roles/rainvar/defaults/main.yml
    ) || info "docker version" "17.06.2.ce"
}

online_init(){
    lsb_dist=$( get_distribution )
    lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"
    progress "Detect $lsb_dist required packages..."
    case "$lsb_dist" in
		ubuntu|debian)
            apt-get update
            apt-get install -y sshpass python-pip uuid-runtime pwgen expect
		;;
		centos)
            yum install -y epel-release 
            yum makecache fast 
            yum install -y sshpass python-pip uuidgen pwgen expect
            # fix centos 7.5 pip install ImportError
            pip install -U setuptools -i https://pypi.tuna.tsinghua.edu.cn/simple
		;;
		*)
           notice "Not Support $lsb_dist"
		;;
    esac
    export LC_ALL=C
    # pip install setuptools pip -U -i https://pypi.tuna.tsinghua.edu.cn/simple
    pip install ansible -i https://pypi.tuna.tsinghua.edu.cn/simple

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
            cat > /etc/apt/sources.list.d/local_rainbond.list <<EOF
deb file:/grdata/services/offline/pkgs/debian/9/ rainbond 5.0
EOF
            touch /opt/rainbond/.init/.offline
		;;
		centos|neokylin)
            #yum install -y epel-release
            #yum makecache fast
            #yum install -y sshpass python-pip uuidgen pwgen
            #pip install ansible -i https://pypi.tuna.tsinghua.edu.cn/simple
            centos_offline
            cat > /etc/yum.repos.d/rainbond.repo << EOF
[rainbond]
name=rainbond_offline_install_repo
baseurl=file:///grdata/services/offline/pkgs/rpm/centos/7
gpgcheck=0
enabled=1
EOF
            touch /opt/rainbond/.init/.offline
            yum makecache
            yum install -y sshpass python-pip uuidgen pwgen ansible
		;;
		*)
            notice "Not Support $lsb_dist"
		;;

    esac
}

get_default_install_type(){
    info "Install Type" "$INSTALL_TYPE"
    sed -i -r  "s/(^install_type: ).*/\1$INSTALL_TYPE/" roles/rainvar/defaults/main.yml
    sed -i -r  "s/(^deploy_type: ).*/\1$DEPLOY_TYPE/" roles/rainvar/defaults/main.yml
    if [ "$INSTALL_TYPE" == "online" ];then
        online_init_docker_version
        online_init
    else
        offline_init
    fi
}

check_port(){
    local portlist=(53 80 443 3306)
    local check_fail_num=0
    for port in ${portlist[@]}
    do
        netstat -pantu | awk '{print $4}' | awk -F: '{print $2}' | sort -ru | grep "\b$port\b" >> /tmp/check_port_log && ((check_fail_num+=1)) || sleep 1
    done
    if [ "$check_fail_num" == 0 ];then
	    touch /opt/rainbond/.init/.port_check
    else
        notice "port is already used, please check port in: ${portlist[@]}"
    fi
}

check_disk(){
    local disk=$(df -h | grep "/$" | awk '{print $2}' | tr 'G' ' ')
    DISK_LIMIT=40
    DISK_STATUS=$(awk -v num1=$disk -v num2=$DISK_LIMIT 'BEGIN{print(num1>=num2)?"0":"1"}')
    if [ "$DISK_STATUS" == '0' ];then
        info "prepare check disk" "passed"
    else
        if [ "$ENABLE_CHECK" == "enable" ];then
            notice "The disk is recommended to be at least 40GB"
        else
            info "!!! Skip disk check.The disk is recommended to be at least 40GB(now ${disk}GB)"
        fi
    fi

}

precheck(){
    progress "Prepare check"
    if [ ! -f "/opt/rainbond/.init/.port_check" ];then
        check_port
    fi
    info "prepare check port" "passed"
    check_disk
}

show_succeed(){
    [ "$INSTALL_TYPE" == "online" ] && up_domain_dns
    [ ! -z "$EIP" ] && info "控制台访问地址" "http://$EIP:7070" || info "控制台访问地址" "http://$IIP:7070"
    info "扩容节点" "https://www.rainbond.com/docs/dev/operation-manual/cluster-management/add-node.html"
    info "操作文档" "https://www.rainbond.com/docs/dev/getting-started/rainbond-overview.html"
    info "社区" "https://t.goodrain.com"
    info "查询集群状态" "grctl cluster"
    grctl cluster
}

onenode(){
    progress "Initialize the data center"
    ansible-playbook -i inventory/hosts setup.yml
    if [ "$?" -eq 0 ];then
        curl -Is 127.0.0.1:7070 | head -1 | grep 200 > /dev/null && progress "Congratulations on your successful installation" || sleep 1
        show_succeed
    else
        notice "The installation did not succeed, please redo it or ask for help"
    fi
}

multinode(){
    progress "Install Rainbond On Multinode Node"
    ansible-playbook -i inventory/hosts hack/multinode/setup.yaml
}

thirdparty(){
    progress "Only Install Rainbond On Thirdparty Node"
    ansible-playbook -i inventory/hosts hack/thirdparty/setup.yaml
    if [ "$?" -eq 0 ];then
        show_succeed
    else
        notice "The installation did not succeed, please redo it or ask for help"
    fi
}

prepare(){
    precheck
    progress "Prepare Init..."
    info "internal ip" $IIP
    [ ! -z "$EIP" ] && info "external ip" $EIP
    [ ! -z "$VIP" ] && info "virtual ip" $VIP
    other_type_linux
    get_default_dns
    [ "$DEPLOY_TYPE" != "thirdparty" ] && get_default_netwrok_type
    get_default_install_type
    info "Deploy Type" $DEPLOY_TYPE
    get_default_config
    [ ! -z "$EIP" ] && Generate_domain $EIP $VIP || Generate_domain $IIP $VIP
    hname=$(hostname -s)
    if [ "$ROLE" == "master" ];then 
        cp inventory/hosts.master inventory/hosts
    else
        cp inventory/hosts.all inventory/hosts
    fi
    sed -i "s#node1#$hname#g" inventory/hosts
    sed -i "s#10.10.10.13#$IIP#g" inventory/hosts

    [ ! -z "$ENABLE_CHECK" ] && sed -i -r  "s/(^enable_check: ).*/\1$ENABLE_CHECK/" roles/rainvar/defaults/main.yml || echo ""

}

update_etcd(){
    info "update default etcd port" "$etcd_port_c1/23800/$etcd_port_c2"
    sed -i -r  "s/(^etcd_port_c1: ).*/\1$etcd_port_c1/" roles/rainvar/defaults/main.yml
    sed -i -r  "s/(^etcd_port_c2: ).*/\1$etcd_port_c2/" roles/rainvar/defaults/main.yml
    sed -i -r  "s/(^etcd_port_s1: ).*/\1$etcd_port_s1/" roles/rainvar/defaults/main.yml

}
3rdprepare(){
    progress "Check thirdparty Init..."
    update_etcd
}

case $DEPLOY_TYPE in
    onenode)
        prepare
        onenode
    ;;
    multinode)
        prepare
        multinode
    ;;
    thirdparty)
        prepare
        3rdprepare
        thirdparty
    ;;
    *)
        notice "Illegal parameter DEPLOY_TYPE($DEPLOY_TYPE)"
    ;;
esac
