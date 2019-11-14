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

INSTALLER_DIR="$(dirname "${0}")"

[ ! -d "/opt/rainbond/.init" ] && mkdir -p /opt/rainbond/.init
[ ! -d "/tmp/install" ] && mkdir -p /tmp/install || rm -rf /tmp/install/*

if [ -f "${INSTALLER_DIR}/scripts/installer/functions.sh" ]; then
	source "${INSTALLER_DIR}/scripts/installer/functions.sh" || notice "not found functions.sh"
fi

if [ -f "${INSTALLER_DIR}/scripts/installer/default.sh" ]; then
	source "${INSTALLER_DIR}/scripts/installer/default.sh" || notice "not found default.sh"
fi

if [ -f "${INSTALLER_DIR}/scripts/installer/global.sh" ]; then
	source "${INSTALLER_DIR}/scripts/installer/global.sh" || notice "not found global.sh"
fi

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

get_docker0_ip() {
    local bip=$(ip r | grep docker0 | awk '{print $9}')
    echo $bip | grep "\." > /dev/null 2>&1
    [ "$?" -eq 0 ] && echo $bip || echo "172.30.42.1" 
}

kylin_ubuntu(){
    info "Update default to Ubuntu" "$1"
    cp -a ./hack/chinaos/ubuntu-release /etc/os-release
    cp -a ./hack/chinaos/ubuntu-lsb-release /etc/lsb-release
    cp -a /etc/apt/sources.list /etc/apt/sources.list.old
    cp -a ./hack/chinaos/sources.list /etc/apt/sources.list
}

neokylin_centos(){
    info "Update default to CentOS" "$1"
    cp -a ./hack/chinaos/centos-release /etc/os-release
    mkdir -p /etc/yum.repos.d/backup >/dev/null 2>&1
    check_repo=$(ls /etc/yum.repos.d/*.repo 2>/dev/null | wc -l)
    if [ "$check_repo" != 0 ]; then
        mv -f /etc/yum.repos.d/*.repo /etc/yum.repos.d/backup >/dev/null 2>&1
    else
        # Todo
        echo ""
    fi
    cp -a ./hack/chinaos/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo
}

# Detect the Linux distribution
detect_linux_distribution(){
    lsb_dist=$( get_distribution )
    lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"
    case "$lsb_dist" in
        neokylin)
            neokylin_centos $lsb_dist
        ;;
        kylin)
            kylin_ubuntu $lsb_dist
        ;;    
    esac
}

init::online(){
    lsb_dist=$( get_distribution )
    lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"
    progress "Detect $lsb_dist required packages..."
    case "$lsb_dist" in
		ubuntu|debian)
            run apt-get update -q
            run apt-get install -y -q sshpass python-pip uuid-runtime pwgen expect curl net-tools git
		;;
		centos)
            run yum install -y -q epel-release 
            run yum makecache fast -q
            run yum install -y -q sshpass python-pip uuidgen pwgen expect curl net-tools git
            run pip install -U setuptools -i https://pypi.tuna.tsinghua.edu.cn/simple
		;;
		*)
           notice "Not Support $lsb_dist"
		;;
    esac
    export LC_ALL=C
    run pip install ansible -i https://pypi.tuna.tsinghua.edu.cn/simple
}

# Support for CentOS offline deployment
offline::centos(){
    info "Remove default CentOS source"
    [ ! -d "/etc/yum.repos.d/backup" ] && mkdir -p /etc/yum.repos.d/backup
    check_repo=$(ls /etc/yum.repos.d/*.repo 2>/dev/null | wc -l)
    if [ "$check_repo" != 0 ]; then
        mv -f /etc/yum.repos.d/*.repo /etc/yum.repos.d/backup >/dev/null 2>&1
    else
        # Todo
        echo ""
    fi
}

init::offline(){
    lsb_dist=$( get_distribution )
    lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"
    case "$lsb_dist" in
		ubuntu|debian)
            [ -f /etc/apt/sources.list ] && mv /etc/apt/sources.list /etc/apt/sources.list.bak > /dev/null 2>&1
            cat > /etc/apt/sources.list.d/local_rainbond.list <<EOF
deb file:///opt/rainbond/offline/pkgs/debian/ 9/
EOF
            touch /opt/rainbond/.init/.offline
            run apt-get update -q
            run apt-get install -y -q --allow-unauthenticated ansible sshpass python-pip uuid-runtime pwgen expect curl net-tools git python-apt
		;;
		centos|neokylin)
            offline::centos
            cat > /etc/yum.repos.d/rainbond.repo << EOF
[rainbond]
name=rainbond_offline_install_repo
baseurl=file:///opt/rainbond/offline/pkgs/rpm/centos/7
gpgcheck=0
enabled=1
EOF
            touch /opt/rainbond/.init/.offline
            run yum makecache -q
            run yum install -y -q sshpass python-pip uuidgen pwgen ansible net-tools git
		;;
		*)
            notice "Not Support $lsb_dist"
		;;
    esac
}

# Port detection
precheck::check_port(){
    local portlist=(53 80 443 3306 6060 7070 8443 8888 9999)
    local check_fail_num=0
    for port in ${portlist[@]}; do
        netstat -pantu | awk '{print $4}' | awk -F: '{print $2}' | sort -ru | grep "\b$port\b" >> /tmp/install/check_port_log && ((check_fail_num+=1)) || sleep 1
        if [ "$check_fail_num" != 0 ]; then
            notice "port ${port} is already used"
        fi
    done
    if [ "$check_fail_num" == 0 ]; then
	    touch /opt/rainbond/.init/.port_check
    else
        notice "port is already used, please check port in: ${portlist[@]}"
    fi
}

# Detection of the disk
precheck::check_disk(){
    local disk=$(df -h -B 1g | grep "/$" | awk '{print $2}')
    DISK_LIMIT=30
    DISK_STATUS=$(awk -v num1=$disk -v num2=$DISK_LIMIT 'BEGIN{print(num1>=num2)?"0":"1"}')
    if [ "$DISK_STATUS" == '0' ]; then
        info "prepare check disk" "passed"
    else
        if [ "$ENABLE_CHECK" == "enable" ]; then
            notice "The disk is recommended to be at least 40GB"
        else
            info "!!! Skip disk check.The disk is recommended to be at least 40GB(now ${disk}GB)"
        fi
    fi
}

# Detect network
precheck::check_network(){
    local RAINBOND_HOMEPAGE="https://www.rainbond.com"
    if [ "$INSTALL_TYPE" == "online" ]; then
        curl -s --connect-timeout 15 $RAINBOND_HOMEPAGE -o /dev/null 2>/dev/null
        if [ "$?" -eq 0 ]; then
            info "prepare check network" "passed"
        else
            notice "Unable to connect to internet"
        fi
    else
        info "prepare check network" "passed"
    fi
}

# Detection of architecture
precheck::check_system(){
    if [ "$(uname -m)" != "x86_64" ]; then
	    notice "Static binary versions of Rainbond are available only for 64bit Intel/AMD CPUs (x86_64), but yours is: $(uname -m)."
    fi
    if [ "$(uname -s)" != "Linux" ]; then
        notice "Static binary versions of Rainbond are available only for Linux, but this system is $(uname -s)"
    fi
    info "prepare check system" "passed"
}

# Avoid internal network IP segment conflicts
precheck::check_ip(){
    INET_IP=${IIP%%.*}
    ip r | grep $IIP > /dev/null  && info "prepare check iip" "passed" || notice "Current Node does not exist $IIP"
    if [ "$INET_IP" == "172" ]; then
        echo "$IIP" | grep -E '^172.30' && notice "内网ip所在内网IP段与docker0的内网段(172.30.0.0/16)冲突."
    fi
    info "prepare check ip cidr" "passed"
}

# check user uid
precheck::check_uid(){
    if [ "$ENABLE_CHECK" == "enable" ]; then
        if [ "${UID}" != 0 ]; then
            notice "The root user must be used by default."
        fi
    else
        if [ "${UID}" != 0 ]; then
            info "Root(uid 0) is recommended"
        fi
    fi
    info "prepare check uid" "passed"
}

# prepare check: ip,uid,port,disk,network,system
precheck(){
    progress "Prepare check"
    precheck::check_uid
    precheck::check_system
    precheck::check_ip
    precheck::check_network
    if [ ! -f "/opt/rainbond/.init/.port_check" ]; then
        precheck::check_port
    fi
    info "prepare check port" "passed"
    precheck::check_disk
}

# support config db
config::db(){
    [ ! -f "/opt/rainbond/.init/.db_info" ] && (
            db_pass=$(pwgen 8 1)
            [ ! -z "$db_pass" ] &&  (
                echo "db_pass:$db_pass" > /opt/rainbond/.init/.db_info
            )
            db_user=$(pwgen 6 1)
            [ ! -z "$db_user" ] &&  (
                echo "db_user:$db_user" >> /opt/rainbond/.init/.db_info
                echo "db_port:3306" >> /opt/rainbond/.init/.db_info
                echo "db_host:$1" >> /opt/rainbond/.init/.db_info
            )
    )
    # 使用外部数据库
    if [ ! -z "$ENABLE_EXDB" ]; then
        # region & console
        if [ ! -z "$EXDB_PASSWD" ] && [ ! -z "$EXDB_PORT" ] && [ ! -z "$EXDB_HOST" ] && [ ! -z "$EXDB_USER" ] && [ -z "$EXCSDB_ONLY_ENABLE" ]; then
            cat > /opt/rainbond/.init/db <<EOF
db_user:$EXDB_USER
db_pass:$EXDB_PASSWD
db_port:$EXDB_PORT
db_host:$EXDB_HOST
dbcs_user:$EXDB_USER
dbcs_pass:$EXDB_PASSWD
dbcs_port:$EXDB_PORT
dbcs_host:$EXDB_HOST
db_type:${EXDB_TYPE:-mysql}
net_type:external
enable_console:false
EOF
        else
            # only console
            if [ ! -z "$EXCSDB_ONLY_ENABLE" ]; then

                if [ ! -z "$EXDB_PASSWD" ] && [ ! -z "$EXDB_PORT" ] && [ ! -z "$EXDB_HOST" ] && [ ! -z "$EXDB_USER" ]; then
cat > /opt/rainbond/.init/.db_info <<EOF
db_user:$EXDB_USER
db_pass:$EXDB_PASSWD
db_port:$EXDB_PORT
db_host:$EXDB_HOST
EOF
                fi

                if [ ! -z "$EXCSDB_PASSWD" ] && [ ! -z "$EXCSDB_PORT" ] && [ ! -z "$EXCSDB_HOST" ] && [ ! -z "$EXCSDB_USER" ]; then
                    cat > /opt/rainbond/.init/db <<EOF
db_user:$(cat /opt/rainbond/.init/.db_info | grep db_user | awk -F: '{print $2}')
db_pass:$(cat /opt/rainbond/.init/.db_info | grep db_pass | awk -F: '{print $2}')
db_port:$(cat /opt/rainbond/.init/.db_info | grep db_port | awk -F: '{print $2}')
db_host:$(cat /opt/rainbond/.init/.db_info | grep db_host | awk -F: '{print $2}')
dbcs_user:$EXCSDB_USER
dbcs_pass:$EXCSDB_PASSWD
dbcs_port:$EXCSDB_PORT
dbcs_host:$EXCSDB_HOST
db_type:mysql
net_type:external
enable_console:true
EOF
                else
                    notice "使用外部数据库console库参数不全"
                fi
            
            else
                notice "使用外部数据库,参数不全"
            fi
          
        fi
    else
            cat > /opt/rainbond/.init/db <<EOF
db_user:$(cat /opt/rainbond/.init/.db_info | grep db_user | awk -F: '{print $2}')
db_pass:$(cat /opt/rainbond/.init/.db_info | grep db_pass | awk -F: '{print $2}')
db_port:3306
db_host:$1
dbcs_user:$(cat /opt/rainbond/.init/.db_info | grep db_user | awk -F: '{print $2}')
dbcs_pass:$(cat /opt/rainbond/.init/.db_info | grep db_pass | awk -F: '{print $2}')
dbcs_port:3306
dbcs_host:$1
db_type:mysql
net_type:internal
enable_console:false
EOF
    fi
}

# Generate default configuration
config::default(){
    [ ! -f "/opt/rainbond/.init/uuid" ] && (
        if [ -f "/sys/class/dmi/id/product_uuid" ]; then
            uuid=$(cat /sys/class/dmi/id/product_uuid | tr 'A-Z' 'a-z')
        else
            uuid=$(uuidgen)
        fi
        [ ! -z "$uuid" ] && echo "$uuid" > /opt/rainbond/.init/uuid || notice "uuid is null"
    )
    [ ! -f "/opt/rainbond/.init/secretkey" ] && (
        secretkey=$(pwgen 32 1)
        [ ! -z "$secretkey" ] &&  (
            echo "$secretkey" > /opt/rainbond/.init/secretkey
        )
    )
    config::db $1
    [ ! -f "/root/.ssh/id_rsa.pub" ] && (
        ssh-keygen -t rsa -f /root/.ssh/id_rsa -P ""
    )
    db_user=$(cat /opt/rainbond/.init/db | grep db_user | awk -F: '{print $2}')
    db_pass=$(cat /opt/rainbond/.init/db | grep db_pass | awk -F: '{print $2}')
    db_host=$(cat /opt/rainbond/.init/db | grep db_host | awk -F: '{print $2}')
    db_port=$(cat /opt/rainbond/.init/db | grep db_port | awk -F: '{print $2}')
    dbcs_user=$(cat /opt/rainbond/.init/db | grep dbcs_user | awk -F: '{print $2}')
    dbcs_pass=$(cat /opt/rainbond/.init/db | grep dbcs_pass | awk -F: '{print $2}')
    dbcs_host=$(cat /opt/rainbond/.init/db | grep dbcs_host | awk -F: '{print $2}')
    dbcs_port=$(cat /opt/rainbond/.init/db | grep dbcs_port | awk -F: '{print $2}')
    db_type=$(cat /opt/rainbond/.init/db | grep db_type | awk -F: '{print $2}')
    net_type=$(cat /opt/rainbond/.init/db | grep net_type | awk -F: '{print $2}')
    secretkey=$(cat /opt/rainbond/.init/secretkey)
    sed -i -r  "s/(^db_user: ).*/\1$db_user/" roles/rainvar/defaults/main.yml
    sed -i -r  "s/(^db_pass: ).*/\1$db_pass/" roles/rainvar/defaults/main.yml
    sed -i -r  "s/(^db_host: ).*/\1$db_host/" roles/rainvar/defaults/main.yml
    sed -i -r  "s/(^db_port: ).*/\1$db_port/" roles/rainvar/defaults/main.yml
    sed -i -r  "s/(^dbcs_user: ).*/\1$dbcs_user/" roles/rainvar/defaults/main.yml
    sed -i -r  "s/(^dbcs_pass: ).*/\1$dbcs_pass/" roles/rainvar/defaults/main.yml
    sed -i -r  "s/(^dbcs_host: ).*/\1$dbcs_host/" roles/rainvar/defaults/main.yml
    sed -i -r  "s/(^dbcs_port: ).*/\1$dbcs_port/" roles/rainvar/defaults/main.yml
    sed -i -r  "s/(^db_type: ).*/\1${db_type:-mysql}/" roles/rainvar/defaults/main.yml
    sed -i -r  "s/(^net_type: ).*/\1$net_type/" roles/rainvar/defaults/main.yml
    sed -i -r  "s/(^secretkey: ).*/\1$secretkey/" roles/rainvar/defaults/main.yml
    info "Use database type" "${net_type}/${db_type:-mysql}"
    if [ ! -z "$EXCSDB_ONLY_ENABLE" ]; then
        sed -i -r  "s/(^enable_console: ).*/\1true}/" roles/rainvar/defaults/main.yml
        info "database region info" "user:${db_user}/${db_pass} host:${db_host}:${db_port}"
        info "database console info" "user:${dbcs_user}/${dbcs_pass} host:${dbcs_host}:${dbcs_port}"
    else
        info "database region/console info" "user:${db_user}/${db_pass} host:${db_host}:${db_port}"
    fi
    cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
    touch /opt/rainbond/.init/.init_done
    info "Generate the default configuration" "$(cat /opt/rainbond/.init/uuid)/$(cat /opt/rainbond/.init/secretkey)"
    echo "" > /opt/rainbond/.init/node.uuid
}

# Config domain
config::domain(){
    DOMAIN_IP=$1
    DOMAIN_VIP=$2
    DOMAIN_UUID=$(cat /opt/rainbond/.init/uuid)
    DOMAIN_TYPE=False
    DOMAIN_LOG="/opt/rainbond/.domain.log"
    AUTH=$(cat /opt/rainbond/.init/secretkey)
    echo "" > $DOMAIN_LOG
    if [ -z "$DOMAIN" ]; then
        if [ "$INSTALL_TYPE" == "online" ]; then
            curl -s --connect-timeout 20  -d 'ip='"$DOMAIN_IP"'&uuid='"$DOMAIN_UUID"'&type='"$DOMAIN_TYPE"'&auth='"$AUTH"'' -X POST  $DOMAIN_API/domain/new > $DOMAIN_LOG
        fi
        [ -f $DOMAIN_LOG ] && wilddomain=$(cat $DOMAIN_LOG )
        if [[ "$wilddomain" == *grapps.cn ]]; then
            info "wild-domain:" "$wilddomain"
            sed -i -r  "s/(^app_domain: ).*/\1$wilddomain/" roles/rainvar/defaults/main.yml
            [ ! -d "/opt/rainbond/bin" ] && mkdir -p /opt/rainbond/bin
            cp -a hack/tools/update-domain.sh /opt/rainbond/bin/.domain.sh
            chmod +x /opt/rainbond/bin/.domain.sh
        else
            info "not generate rainbond domain, will use example" "pass.grapps.cn"
            sed -i -r  "s/(^app_domain: ).*/\1pass.grapps.cn/" roles/rainvar/defaults/main.yml
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

# Config nameserver
config::dns() {
    dns=$(cat /etc/resolv.conf | grep "^nameserver" | grep -v "$IIP" | head -1 | awk '{print $2}')
    [ -z "$dns" ] && dns="114.114.114.114"
    sed -i -r  "s/(^default_dns_local: ).*/\1$dns/" roles/rainvar/defaults/main.yml
    info "nameserver" "$dns"
}

# Config::docker version
config::docker(){
    if command_exists docker && [ -e /var/run/docker.sock ]; then
        DOCKER_BRIDGE_IP=$(get_docker0_ip)
        sed -i -r "s/(^docker_bridge_ip: ).*/\1$DOCKER_BRIDGE_IP/" roles/rainvar/defaults/main.yml
        info "Existing docker bip:" "${DOCKER_BRIDGE_IP}"
    else
        if [ ! -z "$DOCKER_VERSION" ]; then
            sed -i -r  "s/(^docker_version: ).*/\1$DOCKER_VERSION/" roles/rainvar/defaults/main.yml
        fi
        info "docker version" "${DOCKER_VERSION:-18.06}"
    fi
}

# Config storage
config::storage(){
    if [ "$STORAGE" == "gfs" ];then
        sed -i -r  "s/(^storage_type: ).*/\1$STORAGE/" roles/rainvar/defaults/main.yml
        sed -i -r  "s#(^storage_cmd: ).*#\1\"$STORAGE_ARGS\"#" roles/rainvar/defaults/main.yml
    elif [ "$STORAGE" == "nas" ];then
        sed -i -r  "s/(^storage_type: ).*/\1$STORAGE/" roles/rainvar/defaults/main.yml
        sed -i -r  "s#(^storage_cmd: ).*#\1\"$STORAGE_ARGS\"#" roles/rainvar/defaults/main.yml
    else
        # Todo
        #sed -i -r  "s/(^storage_type: ).*/\1nfs/" roles/rainvar/defaults/main.yml
        echo ""
    fi
    info "storage type" "$STORAGE"
    info "storage args" "$STORAGE_ARGS"
}

# Config install_type & deploy_type
config::install_deploy(){
    sed -i -r  "s/(^install_type: ).*/\1$INSTALL_TYPE/" roles/rainvar/defaults/main.yml
    sed -i -r  "s/(^deploy_type: ).*/\1$DEPLOY_TYPE/" roles/rainvar/defaults/main.yml
}

# Config Region info
config::region_url(){
    region_url="https:\/\/$1:8443"
    sed -i -r  "s/(^region_url: ).*/\1${region_url}/" roles/rainvar/defaults/main.yml
}

config::region_id(){
    region_id=$(uuidgen)
    sed -i -r  "s/(^region_id: ).*/\1${region_id}/" roles/rainvar/defaults/main.yml
}

# Config UI install
config::rbd-app-ui(){
    if [ ! -z "$INSTALL_UI" ];then
        sed -i -r  "s/(^install_ui: ).*/\1${INSTALL_UI}/" roles/rainvar/defaults/main.yml
    fi
}


# Dev Mode
detect_dev_mode(){
    if [ ! -z "$INSTALL_DEBUG" ]; then
        sed -i -r  "s/(^dev_mode: ).*/\1goodrain/" roles/rainvar/defaults/main.yml
    fi
    if [ -e /opt/rainbond/offline/base.images.tgz ] && [ -e /opt/rainbond/offline/rainbond.images.tgz ]; then
        info "Notice" "检测到本地已存储离线镜像文件，将优先使用本地离线文件"
    else
        info "Notice" "将从互联网下载离线镜像文件(约2GB)，下载速度取决于当前机器网络带宽"
    fi
}

# 检查Role角色状态
check_var(){
    local role type
    role=$1
    role_type=$2
    echo ${role} | grep ${role_type} >/dev/null 2>&1
    echo $?
}

config::hosts(){
    if [ -f "inventory/hosts" ]; then
      rm -f inventory/hosts
    fi
    if [ ! -d "inventory" ];then
      mkdir inventory
    fi
    touch inventory/hosts
    INSTALL_SSH_PORT=${INSTALL_SSH_PORT:-22}
    hname=$(cat /opt/rainbond/.init/uuid)
    cat >> inventory/hosts << EOF
[all]
$hname ansible_host=$IIP  ansible_port=$INSTALL_SSH_PORT ip=$IIP port=$INSTALL_SSH_PORT

[etcd]
$hname

[manage]
$hname
[compute]

[gateway]

[new-manage]

EOF
    role_choice="gateway compute"
    for s_role in $role_choice; do
    if [ "$(check_var $ROLE $s_role)" -eq 0 ]; then
        cat >> inventory/hosts << EOF
[new-$s_role]
$hname

EOF
    else
        cat >> inventory/hosts << EOF
[new-$s_role]

EOF
    fi
    done
}

# General preparation before installation
prepare::general(){
    progress "Preparation before installation..."
    detect_dev_mode
    detect_linux_distribution
    r6d_version=$( cat /opt/rainbond/rainbond-ansible/version)
    info "Installation type" "$INSTALL_TYPE"
    info "Deployment type" "$DEPLOY_TYPE"
    info "Rainbond Version" "$VERSION($r6d_version)"
    if [ "$INSTALL_TYPE" == "online" ]; then
        init::online
    else
        init::offline
    fi
    [ -z "$IIP" ] && IIP=$1
    [ -z "$IIP" ] && IIP=$( get_default_ip )
    [ -z "$IIP" ] && notice "not found IIP"
    info "internal ip" $IIP && echo "$IIP" > /opt/rainbond/.init/.ip
    [ ! -z "$EIP" ] && info "external ip" $EIP && echo "$EIP" > /opt/rainbond/.init/.ip
    [ ! -z "$VIP" ] && info "virtual ip" $VIP
    
    precheck
    config::default $IIP
    config::dns
    config::docker
    config::install_deploy
    config::storage
    config::rbd-app-ui
    config::hosts

    [ ! -z "$EIP" ] && config::domain $EIP $VIP || config::domain $IIP $VIP
    INSTALL_SSH_PORT=${INSTALL_SSH_PORT:-22}
    info "install ssh port" $INSTALL_SSH_PORT
    sed -i -r  "s/(^install_ssh_port: ).*/\1${INSTALL_SSH_PORT}/" roles/rainvar/defaults/main.yml
    [ ! -z "$EIP" ] && sed -i -r  "s/(^master_external_ip: ).*/\1${EIP}/" roles/rainvar/defaults/main.yml
    [ ! -z "$VIP" ] && sed -i -r  "s/(^master_external_ip: ).*/\1${VIP}/" roles/rainvar/defaults/main.yml
    sed -i -r  "s/(^r6d_version: ).*/\1${r6d_version}/" roles/rainvar/defaults/main.yml
    [ ! -z "$ENABLE_CHECK" ] && sed -i -r  "s/(^enable_check: ).*/\1$ENABLE_CHECK/" roles/rainvar/defaults/main.yml || echo ""
    [ ! -z "$EIP" ] && config::region_url $EIP
    [ ! -z "$VIP" ] && config::region_url $VIP
    config::region_id
}

# 域名解析生效
up_domain_dns(){
    [ -f "/opt/rainbond/.init/domain.yaml" ] && (
        uid=$(cat /opt/rainbond/.init/domain.yaml | grep uuid | awk '{print $2}')
        iip=$(cat /opt/rainbond/.init/domain.yaml | grep iip | awk '{print $2}')
        domain=$(cat /opt/rainbond/.init/domain.yaml | grep domain | awk '{print $2}')
        DOMAIN_API=$(cat /opt/rainbond/.init/domain.yaml | grep api | awk '{print $2}')
        if [[ "$domain" =~ "grapps" ]]; then
            curl -s --connect-timeout 20 ${DOMAIN_API}/status\?uuid=$uid\&ip=$iip\&type=True\&domain=$domain >/dev/null 
        fi
    ) || (
        # todo
        echo ""
    )
}

# Rainbond K8s preparation before installation
prepare::r6d(){
    if [ "$NETWORK_TYPE" == "flannel" ]; then
        network="flannel"
    else
        network="calico"
    fi
    info "Pod Network Provider" "${network}"
    if [ -z "$POD_NETWORK_CIDR" ]; then
	INET_IP=${IIP%%.*}
        if [ "$NETWORK_TYPE" == "flannel" ]; then
            pod_network_cidr="${flannel_pod_network_cidr}"
        else
            if [ "$INET_IP" != "192" ]; then
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

# 3rd K8s preparation before installation
prepare::3rd(){
    progress "Preparation thirdparty Init..."
    info "update default etcd port" "$etcd_port_c1/23800/$etcd_port_c2"
    sed -i -r  "s/(^etcd_port_c1: ).*/\1$etcd_port_c1/" roles/rainvar/defaults/main.yml
    sed -i -r  "s/(^etcd_port_c2: ).*/\1$etcd_port_c2/" roles/rainvar/defaults/main.yml
    sed -i -r  "s/(^etcd_port_s1: ).*/\1$etcd_port_s1/" roles/rainvar/defaults/main.yml
}

do_install::ok(){
    [ "$INSTALL_TYPE" == "online" ] && up_domain_dns
    [ ! -z "$EIP" ] && info "控制台访问地址" "http://$EIP:7070" || info "控制台访问地址" "http://$IIP:7070"
    info "扩容节点" "https://www.rainbond.com/docs/user-operations/management/add-node/"
    info "操作文档" "https://www.rainbond.com/docs/user-manual/"
    info "社区" "https://t.goodrain.com"
    info "查询当前数据中心信息" "grctl show"
    run grctl show
    info "查询集群状态" "grctl cluster"
    run grctl cluster
    
}

# Install the rainbond cluster
do_install::r6d(){
    progress "Initialize the data center"
    if [ -z "$DRY_RUN" ]; then
        run ansible-playbook -i inventory/hosts -e noderule=$ROLE setup.yml
        if [ "$?" -eq 0 ]; then
            curl -Is 127.0.0.1:7070 | head -1 | grep 200 > /dev/null && progress "Congratulations on your successful installation" || sleep 1
            do_install::ok
        else
            notice "The installation did not succeed, please redo it or ask for help"
        fi
    else
        run echo "dry run: setup.sh"
    fi
}

# Install the rainbond cluster on the existing k8s cluster
do_install::3rd(){
    progress "Only Install Rainbond On Thirdparty Node"
    if [ -z "$DRY_RUN" ]; then
        run ansible-playbook -i inventory/hosts hack/thirdparty/setup.yaml
        if [ "$?" -eq 0 ]; then
            do_install::ok
        else
            notice "The installation did not succeed, please redo it or ask for help"
        fi
    else
        run echo "dry run: setup.sh"
    fi
}

case $DEPLOY_TYPE in
    onenode)
        prepare::general
        prepare::r6d
        do_install::r6d
    ;;
    thirdparty)
        prepare::general
        prepare::3rd
        do_install::3rd
    ;;
    *)
        notice "Illegal parameter DEPLOY_TYPE($DEPLOY_TYPE)"
    ;;
esac
