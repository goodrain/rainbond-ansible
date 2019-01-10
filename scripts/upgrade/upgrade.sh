#!/bin/bash

IMAGE_LOCAL="/grdata/services/offline/rainbond.images.upgrade.tgz"
IMAGE_PATH="/grdata/services/offline/upgrade"

if [ "$IMAGE_LOCAL" ];then
    [ -d "${IMAGE_PATH}" ] && mkdir -pv ${IMAGE_PATH}
    tar xf ${IMAGE_LOCAL} -C ${IMAGE_PATH}
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

ansible-playbook -i /opt/rainbond/rainbond-ansible/inventory/hosts /opt/rainbond/rainbond-ansible/upgrade.yml
