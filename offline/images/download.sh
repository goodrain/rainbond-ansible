#!/bin/bash

cat ./image.txt | while read line
do
    docker pull $line
    echo "docker pull $line"
    image=${line#*/}
    prefix=${image%:*}
    if [ "$prefix" == "cfssl" -o "$prefix" == "kubecfg" ];then
        docker save ${line} > ./${prefix}.tgz
    else
        docker tag $line goodrain.me/${image}
        docker save goodrain.me/${line#*/} > ./${prefix}.tgz
    fi
done