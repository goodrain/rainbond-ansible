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

offline_image_path="/opt/rainbond/offline/images"
version=5.1.0
rainbond=(mq eventlog webcli gateway worker chaos api app-ui monitor)
baserbd=(rbd-dns)
base=(rbd-db runner builder)
runtime=(adapter)
k8s=(kube-scheduler kube-controller-manager kube-apiserver)
plugins=(tcm mesh_plugin rbd-init-probe)
rm -rf ${offline_image_path}
mkdir -pv ${offline_image_path}/{base,rainbond}

#docker images | grep "rainbond" | awk '{print $1":"$2}' | xargs -I {} docker rmi {}
#docker images | grep "goodrain.me" | awk '{print $3}' | xargs -I {} docker rmi {}

buildtime="2019-03-11-5.1.0"

base_images(){
    docker pull rainbond/cni:k8s_5.1.0
    docker save rainbond/cni:k8s_5.1.0 > ${offline_image_path}/base/cni_k8s.tgz
    docker pull rainbond/kubecfg:dev
    docker save rainbond/kubecfg:dev > ${offline_image_path}/base/kubecfg_dev.tgz
    docker pull rainbond/cfssl:dev
    docker save rainbond/cfssl:dev > ${offline_image_path}/base/cfssl_dev.tgz
    for bimg in ${baserbd[@]}
    do
	[ -f "${offline_image_path}/base/${bimg}.tgz"] && rm -rf ${offline_image_path}/base/${bimg}.tgz
        docker pull rainbond/${bimg}:${version}
        docker tag rainbond/${bimg}:${version} goodrain.me/${bimg}:${version}
        docker save goodrain.me/${bimg}:${version} > ${offline_image_path}/base/${bimg}.tgz
    done
    for img in ${base[@]}
    do
        [ -f "${offline_image_path}/base/${img}.tgz" ] && rm -rf ${offline_image_path}/base/${img}.tgz
        docker pull rainbond/${img}:${version}
        docker tag rainbond/${img}:${version} goodrain.me/${img}
        docker save goodrain.me/${img} > ${offline_image_path}/base/${img}.tgz
    done
    for pimg in ${plugins[@]}
    do
        docker pull rainbond/${pimg}:${version}
        docker tag rainbond/${pimg}:${version} goodrain.me/${pimg}
        [ -f "${offline_image_path}/base/${pimg}.tgz" ] && rm -rf ${offline_image_path}/base/${pimg}.tgz
        docker save goodrain.me/${pimg}> ${offline_image_path}/base/${pimg}.tgz
    done
    for rimg in ${runtime[@]}
    do
        docker pull rainbond/${rimg}:${version}
        docker tag rainbond/${rimg}:${version} goodrain.me/${rimg}
        [ -f "${offline_image_path}/base/${rimg}.tgz" ] && rm -rf ${offline_image_path}/base/${rimg}.tgz
        docker save goodrain.me/${rimg}> ${offline_image_path}/base/${rimg}.tgz
    done
    for kimg in ${k8s[@]}
    do
        docker pull rainbond/${kimg}:v1.10.13
        docker tag rainbond/${kimg}:v1.10.13 goodrain.me/${kimg}:v1.10.13
        [ -f "${offline_image_path}/base/${kimg}.tgz" ] && rm -rf ${offline_image_path}/base/${kimg}.tgz
        docker save goodrain.me/${kimg}:v1.10.13 > ${offline_image_path}/base/${kimg}.tgz
    done
    docker pull rainbond/rbd-repo:6.5.9
    docker tag rainbond/rbd-repo:6.5.9 goodrain.me/rbd-repo:6.5.9
    docker save goodrain.me/rbd-repo:6.5.9 > ${offline_image_path}/base/repo.tgz
    docker pull rainbond/rbd-registry:2.6.2
    docker tag rainbond/rbd-registry:2.6.2 goodrain.me/rbd-registry:2.6.2
    docker save goodrain.me/rbd-registry:2.6.2 > ${offline_image_path}/base/hub.tgz
    docker pull rainbond/calico-node:v3.3.1
    docker tag rainbond/calico-node:v3.3.1 goodrain.me/calico-node:v3.3.1
    docker save goodrain.me/calico-node:v3.3.1 > ${offline_image_path}/base/calico.tgz
    docker pull rainbond/etcd:v3.2.25
    docker tag rainbond/etcd:v3.2.25 goodrain.me/etcd:v3.2.25
    docker save goodrain.me/etcd:v3.2.25 > ${offline_image_path}/base/etcd.tgz
    docker pull rainbond/pause-amd64:3.0
    docker tag rainbond/pause-amd64:3.0 goodrain.me/pause-amd64:3.0
    docker save goodrain.me/pause-amd64:3.0 > ${offline_image_path}/base/pause.tgz
}

rainbond_images(){
    for img in ${rainbond[@]}
    do
        docker pull rainbond/rbd-${img}:${version}
        docker tag rainbond/rbd-${img}:${version} goodrain.me/rbd-${img}:${version}
        [ -f "${offline_image_path}/rainbond/${img}.tgz" ] && rm -rf ${offline_image_path}/rainbond/${img}.tgz
        docker save goodrain.me/rbd-${img}:${version} > ${offline_image_path}/rainbond/${img}.tgz
    done
    docker pull rainbond/cni:rbd_${version}
    docker save rainbond/cni:rbd_${version} > ${offline_image_path}/rainbond/cni_rbd.tgz
}

rainbond_tgz(){
    rainbond_images
    pushd $offline_image_path/rainbond
        [ -f "$offline_image_path/rainbond.images.${buildtime}.tgz" ] && rm -rf $offline_image_path/rainbond.images.${buildtime}.tgz
        tar zcf $offline_image_path/rainbond.images.${buildtime}.tgz `find .  | sed 1d`
        sha256sum  $offline_image_path/rainbond.images.${buildtime}.tgz | awk '{print $1}' > $offline_image_path/rainbond.images.${buildtime}.sha256sum.txt
    popd
}

base_tgz(){
    base_images
    pushd $offline_image_path/base
        [ -f "$offline_image_path/base.images.${buildtime}.tgz" ] && rm -rf $offline_image_path/base.images.${buildtime}.tgz
        tar zcf $offline_image_path/base.images.${buildtime}.tgz `find .  | sed 1d`
        sha256sum $offline_image_path/base.images.${buildtime}.tgz | awk '{print $1}' > $offline_image_path/base.images.${buildtime}.sha256sum.txt
    popd
}


case $1 in
	rainbond)
		rainbond_tgz
	;;
	base)
		base_tgz
	;;
	*)
		rainbond_tgz push
		base_tgz push
	;;
esac