#!/bin/bash

IMAGE_LOCAL="/grdata/services/offline/rainbond.images.upgrade.5.0.4.tgz"
IMAGE_PATH="/grdata/services/offline/upgrade"

INSTALL_SCRIPT="/grdata/services/offline/rainbond-ansible.upgrade.5.0.4.tgz"

if [ -f "$IMAGE_LOCAL" ];then
    [ -d "${IMAGE_PATH}" ] || mkdir -pv ${IMAGE_PATH}
    tar xf ${IMAGE_LOCAL} -C ${IMAGE_PATH}
else
    exit 1
fi

if [ -f "$INSTALL_SCRIPT" ];then
    mv /opt/rainbond/rainbond-ansible /opt/rainbond/rainbond-ansible_5.0.3
    tar xf ${INSTALL_SCRIPT} -C /opt/rainbond
    rm -rf /opt/rainbond/rainbond-ansible/inventory
    cp -a /opt/rainbond/rainbond-ansible_5.0.3/inventory /opt/rainbond/rainbond-ansible
    secretkey=$(cat /opt/rainbond/rainbond-ansible_5.0.3/roles/rainvar/defaults/main.yml | grep secretkey | awk '{print $2}')
    db_pass=$(cat /opt/rainbond/rainbond-ansible_5.0.3/roles/rainvar/defaults/main.yml | grep db_pass | awk '{print $2}')
    pod_cidr=$(cat /opt/rainbond/rainbond-ansible_5.0.3/roles/rainvar/defaults/main.yml | grep pod_cidr | awk '{print $2}')
    app_domain=$(cat /opt/rainbond/rainbond-ansible_5.0.3/roles/rainvar/defaults/main.yml | grep app_domain | awk '{print $2}')
    default_dns_local=$(cat /opt/rainbond/rainbond-ansible_5.0.3/roles/rainvar/defaults/main.yml | grep default_dns_local | awk '{print $2}')
    sed -i -r  "s/(^secretkey: ).*/\1$secretkey/" /opt/rainbond/rainbond-ansible/roles/rainvar/defaults/main.yml
    sed -i -r  "s/(^db_pass: ).*/\1$db_pass/" /opt/rainbond/rainbond-ansible/roles/rainvar/defaults/main.yml
    sed -i -r  "s#(^pod_cidr: ).*#\1$pod_cidr#" /opt/rainbond/rainbond-ansible/roles/rainvar/defaults/main.yml
    sed -i -r  "s/(^app_domain: ).*/\1$app_domain/" /opt/rainbond/rainbond-ansible/roles/rainvar/defaults/main.yml
    sed -i -r  "s/(^default_dns_local: ).*/\1$default_dns_local/" /opt/rainbond/rainbond-ansible/roles/rainvar/defaults/main.yml
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

[ ! -z "$readyok" ] && docker images | grep "goodrain.me" | awk '{print $1":"$2}' | xargs -I {} docker push {}

#echo "patch 5.0.3"
#docker pull rainbond/rbd-builder:5.0
#docker tag rainbond/rbd-builder:5.0 goodrain.me/builder
#docker push goodrain.me/builder
#docker pull rainbond/rbd-dns:5.0
#docker tag rainbond/rbd-dns:5.0 goodrain.me/rbd-dns:5.0
#docker push goodrain.me/rbd-dns:5.0
#echo "patch 5.0.2"
#docker pull rainbond/plugins:tcm
#docker tag rainbond/plugins:tcm goodrain.me/tcm
#docker push goodrain.me/tcm

docker run --rm -v /opt/rainbond/etc/tools:/sysdir rainbond/cni:rbd_5.0 tar zxf /pkg.tgz -C /sysdir

ansible-playbook -i /opt/rainbond/rainbond-ansible/inventory/hosts /opt/rainbond/rainbond-ansible/upgrade.yml
