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

IMAGE_R6D_LOCAL="/grdata/services/offline/rainbond.images.upgrade.5.1.2.tgz"
IMAGE_BASE_LOCAL="/grdata/services/offline/runtime.upgrade.5.1.2.tgz"

IMAGE_PATH="/grdata/services/offline/upgrade"

INSTALL_SCRIPT="/grdata/services/offline/rainbond-ansible.upgrade.5.1.2.tgz"

[ -d "${IMAGE_PATH}" ] || mkdir -pv ${IMAGE_PATH}

if [ -f "$IMAGE_R6D_LOCAL" ]; then
    tar xf ${IMAGE_R6D_LOCAL} -C ${IMAGE_PATH}
else
    exit 1
fi

if [ -f "$IMAGE_BASE_LOCAL" ]; then
    tar xf ${IMAGE_BASE_LOCAL} -C ${IMAGE_PATH}
else
    exit 1
fi

version_check=$(grctl version | grep "5.1." | wc -l)
if [ "$version_check" -eq 0 ]; then
    echo "请升级至5.1.0版本后在升级至5.1.x版本 https://t.goodrain.com/t/rainbond-v5-1-1/803"
    exit 1
fi

check_grdata=$(df -h | grep "/grdata$" | wc -l)
if [ "$check_grdata" == 0 ]; then
    disk=$(df | grep "/$" | awk '{print $4}' | tr 'G' ' ')
else
    disk=$(df | grep "/grdata$" | awk '{print $4}' | tr 'G' ' ')
fi
DISK_LIMIT=6000000
DISK_STATUS=$(awk -v num1=$disk -v num2=$DISK_LIMIT 'BEGIN{print(num1>=num2)?"0":"1"}')
if [ "$DISK_STATUS" -ne '0' ]; then
    echo "!!! 磁盘(/grdata)至少可用空间大于6GB(now ${disk}GB)"
    exit 1
fi

if [ -f "$INSTALL_SCRIPT" ];then
    mv /opt/rainbond/rainbond-ansible /opt/rainbond/rainbond-ansible_5.1.1
    tar xf ${INSTALL_SCRIPT} -C /opt/rainbond
    rm -rf /opt/rainbond/rainbond-ansible/inventory
    cp -a /opt/rainbond/rainbond-ansible_5.1.1/inventory /opt/rainbond/rainbond-ansible
    cp -a /opt/rainbond/rainbond-ansible_5.1.1/roles/rainvar/defaults/main.yml /opt/rainbond/rainbond-ansible/roles/rainvar/defaults/main.yml
    #secretkey=$(cat /opt/rainbond/rainbond-ansible_5.1.0/roles/rainvar/defaults/main.yml | grep secretkey | awk '{print $2}')
    #db_pass=$(cat /opt/rainbond/rainbond-ansible_5.1.0/roles/rainvar/defaults/main.yml | grep db_pass | awk '{print $2}')
    #pod_cidr=$(cat /opt/rainbond/rainbond-ansible_5.1.0/roles/rainvar/defaults/main.yml | grep pod_cidr | awk '{print $2}')
    #app_domain=$(cat /opt/rainbond/rainbond-ansible_5.1.0/roles/rainvar/defaults/main.yml | grep app_domain | awk '{print $2}')
    #default_dns_local=$(cat /opt/rainbond/rainbond-ansible_5.1.0/roles/rainvar/defaults/main.yml | grep default_dns_local | awk '{print $2}')
    #sed -i -r  "s/(^secretkey: ).*/\1$secretkey/" /opt/rainbond/rainbond-ansible/roles/rainvar/defaults/main.yml
    #sed -i -r  "s/(^db_pass: ).*/\1$db_pass/" /opt/rainbond/rainbond-ansible/roles/rainvar/defaults/main.yml
    #sed -i -r  "s#(^pod_cidr: ).*#\1$pod_cidr#" /opt/rainbond/rainbond-ansible/roles/rainvar/defaults/main.yml
    #sed -i -r  "s/(^app_domain: ).*/\1$app_domain/" /opt/rainbond/rainbond-ansible/roles/rainvar/defaults/main.yml
    #sed -i -r  "s/(^default_dns_local: ).*/\1$default_dns_local/" /opt/rainbond/rainbond-ansible/roles/rainvar/defaults/main.yml
else
    exit 1
fi

pushd $IMAGE_PATH
ls | grep tgz | xargs -I {} docker load -i ./{}
popd

for ((i=1;i<=60;i++));do
    sleep 1
    curl -sk --connect-timeout 10 --max-time 30 -I  https://goodrain.me/v2/ | head -1 | grep 200
    [ "$?" -eq 0 ] && export readyok="ok"  && break
done

[ ! -z "$readyok" ] && docker images | grep "goodrain.me" | grep -vE "(2018|2019|none|v|k8s|rbd_|5\.0|3\.0)" | awk '{print $1":"$2}' | xargs -I {} docker push {}

mv /opt/rainbond/etc/tools/bin/node /opt/rainbond/etc/tools/bin/node.5.1.1
mv /opt/rainbond/etc/tools/bin/grctl /opt/rainbond/etc/tools/bin/grctl.5.1.1

docker run --rm -v /opt/rainbond/etc/tools:/sysdir rainbond/cni:rbd_5.1.2 tar zxf /pkg.tgz -C /sysdir

export ANSIBLE_HOST_KEY_CHECKING=False

ansible-playbook -i /opt/rainbond/rainbond-ansible/inventory/hosts /opt/rainbond/rainbond-ansible/upgrade.yml

rm -rf ${IMAGE_R6D_LOCAL}
rm -rf ${IMAGE_BASE_LOCAL}
rm -rf ${IMAGE_PATH}