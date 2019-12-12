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

IMAGE_R6D_LOCAL="/grdata/services/offline/rainbond.images.upgrade.5.1.9.tgz"
IMAGE_BASE="/grdata/services/offline/base.images.upgrade.5.1.9.tgz"
IMAGE_PATH="/grdata/services/offline/upgrade"
INSTALL_SCRIPT="/grdata/services/offline/rainbond-ansible.upgrade.5.1.9.tgz"

# check /grdata disk remaining space
echo -e "\033[35m Check disk space \033[0m"
check_grdata=$(df -h | grep -c "/grdata$")
if [ "$check_grdata" == 0 ]; then
    disk=$(df | grep "/$" | awk '{print $4}' | tr 'G' ' ')
else
    disk=$(df | grep "/grdata$" | awk '{print $4}' | tr 'G' ' ')
fi
DISK_LIMIT=6000000
DISK_STATUS=$(awk -v num1="$disk" -v num2=$DISK_LIMIT 'BEGIN{print(num1>=num2)?"0":"1"}')
if [ "$DISK_STATUS" -ne '0' ]; then
    echo -e "\033[31m !!! 磁盘(/grdata)至少可用空间大于6GB(now ${disk}KB) \033[0m"
    exit 1
fi

# Check the docker directory using half score
TOTAL_DISK=$(df -Th| grep "/var/lib/docker" | awk '{print $3}' | tr 'G' ' '|head -1)
DOCKER_DISK=$(df -Th| grep "/var/lib/docker" | awk '{print $4}' | tr 'G' ' '|head -1)
# Occupancy space
USE=6
PLAN=$(awk -v num1=$DOCKER_DISK -v num2=$USE 'BEGIN{print(num1+num2)}')
PlANNED=$(awk -v num3=$PLAN -v num4=$TOTAL_DISK 'BEGIN{printf("%.0f\n",num3/num4*100)}')
# Spatial threshold
DISK_HALF=80
DOCKER_DISK=$(awk -v num1=$PlANNED -v num2=$DISK_HALF 'BEGIN{print(num1<=num2)?"0":"1"}')
if [ "$DOCKER_DISK" -ne '0' ]; then
    echo -e "\033[31m !!! 预估磁盘(/var/lib/docker)使用率将超过80% \033[0m"
    exit 1
fi
echo  -e "\033[32m Check that the remaining disk space passes \033[0m"

echo -e "\033[35m Check current version \033[0m"
version_check=$(grctl version | grep -c "5.1.")
if [ "$version_check" -eq 0 ]; then
    echo -e "\033[33m 请升级至5.1.0版本后在升级至5.1.x版本 https://t.goodrain.com/t/rainbond-v5-1-1/803 \033[0m"
    exit 1
fi
echo  -e "\033[32m Check current version succeeded \033[0m"
[ -d "${IMAGE_PATH}" ] || mkdir -pv ${IMAGE_PATH}
echo -e "\033[35m tar xf rainbond.images,Please wait a moment \033[0m"
if [ -f "$IMAGE_R6D_LOCAL" ]; then
    tar xf ${IMAGE_R6D_LOCAL} -C ${IMAGE_PATH} && tar xf ${IMAGE_BASE} -C ${IMAGE_PATH}
else
    echo -e "\033[33m $IMAGE_R6D_LOCAL not exist, please redownload and upgrade. \033[0m"
    exit 1
fi

#Mark the update version into db
current_version=$(grctl version | cut -f3 -d " " | awk -F "-*" '{print $1}' | sed 's/^.//')
docker exec rbd-db mysql -e "select \`key\`,\`value\` from console.console_sys_config;" | grep RAINBOND_VERSION  >/dev/null 2>&1
if [ $? -ne 0 ]; then
docker exec rbd-db mysql -D console -e "insert \`console_sys_config\`(\`key\`, \`value\`) values(\"RAINBOND_VERSION\", \"${current_version}\");"
fi

if [ -f "$INSTALL_SCRIPT" ];then
    mv /opt/rainbond/rainbond-ansible /opt/rainbond/rainbond-ansible_$current_version
    mkdir -p /opt/rainbond/rainbond-ansible
    tar xf ${INSTALL_SCRIPT} -C /opt/rainbond/rainbond-ansible
    version=$(cat /opt/rainbond/rainbond-ansible/version)
    cp -a "/opt/rainbond/rainbond-ansible_$current_version/roles/rainvar/defaults/main.yml" /opt/rainbond/rainbond-ansible/roles/rainvar/defaults/main.yml
    sed -i -r "s/(^r6d_version: ).*/\1$version/" /opt/rainbond/rainbond-ansible/roles/rainvar/defaults/main.yml
    master_ip=$(cat /opt/rainbond/rainbond-ansible/roles/rainvar/defaults/main.yml | grep master_ip | awk '{print $2}')
    if [[ -z $master_ip ]];then
    cat >> /opt/rainbond/rainbond-ansible/roles/rainvar/defaults/main.yml <<EOF

master_ip: "{{hostvars[groups['manage'][0]]['ip']}}"
EOF
    fi
    region_name=$(cat /opt/rainbond/rainbond-ansible/roles/rainvar/defaults/main.yml | grep region_name | awk '{print $2}')
    if [[ -z $region_name ]];then
    cat >> /opt/rainbond/rainbond-ansible/roles/rainvar/defaults/main.yml <<EOF

## region
region_id: "1234567890"
region_name: "rainbond"
region_alias: "默认私有数据中心"
region_url: "https://region.goodrain.me:8443"
region_desc: "当前数据中心是默认安装添加的数据中心"
ssl_ca_cert: "{{ region_ca_dir }}/ca.pem"
client_cert_file: "{{ region_ca_dir }}/client.key.pem"
client_key_file: "{{ region_ca_dir }}/client.pem"

EOF
    fi
    install_ui=$(cat /opt/rainbond/rainbond-ansible/roles/rainvar/defaults/main.yml | grep install_ui | awk '{print $2}')
    if [[ -z $install_ui ]];then
    cat >> /opt/rainbond/rainbond-ansible/roles/rainvar/defaults/main.yml <<EOF

install_ui: true
master_external_ip: "{{hostvars[groups['manage'][0]]['ip']}}"

EOF
    fi
else
    echo "$INSTALL_SCRIPT not exist"
    exit 1
fi

for ((i=1;i<=60;i++));do
    sleep 1
    curl -sk --connect-timeout 10 --max-time 30 -I  https://goodrain.me/v2/ | head -1 | grep 200
    [ "$?" -eq 0 ] && export readyok="ok"  && break
done

echo -e "\033[35m Start load and push new vension images \033[0m"
while read line
do
	docker load -i $IMAGE_PATH/$line |awk -Fimage: '{print $2}' |xargs -I {} docker push {}
done <<< "$(ls $IMAGE_PATH|grep tgz)"
echo  -e "\033[32m load new version docker images success \033[0m"

echo -e "\033[35m Start load new version grctl and node \033[0m"
mv /opt/rainbond/etc/tools/bin/node /opt/rainbond/etc/tools/bin/node.$current_version
mv /opt/rainbond/etc/tools/bin/grctl /opt/rainbond/etc/tools/bin/grctl.$current_version

docker run --rm -v /opt/rainbond/etc/tools:/sysdir rainbond/cni:rbd_${version} tar zxf /pkg.tgz -C /sysdir
if [ $? -ne 0 ]; then
    echo -e "\033[31m load new version grctl and node failure \033[0m"
    exit 1
else
    echo  -e "\033[32m load new version grctl and node success \033[0m"
fi
export ANSIBLE_HOST_KEY_CHECKING=False
# rewrite ansible hosts
mkdir -p /opt/rainbond/rainbond-ansible/inventory
/opt/rainbond/etc/tools/bin/grctl ansible hosts
if [ $? -ne 0 ]; then
    echo -e "\033[31m Generate the ansible host list failure, Verify that the cluster is normal. \033[0m"
    exit 1
else
    echo  -e "\033[32m Generate the ansible host list successfully \033[0m"
fi

# ansible upgrade all node
echo -e "\033[35m Execute ansible upgrade script \033[0m"
ansible-playbook -i /opt/rainbond/rainbond-ansible/inventory/hosts /opt/rainbond/rainbond-ansible/upgrade.yml
if [ $? -ne 0 ]; then
    echo -e "\033[31m ansible upgrade all node failure \033[0m"
    exit 1
else
    echo  -e "\033[32m Success upgrade by ansible \033[0m"
fi
# clear data
rm -rf ${IMAGE_PATH}