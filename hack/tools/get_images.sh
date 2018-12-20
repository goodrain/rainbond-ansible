#!/bin/bash

offline_image_path=${1:-/opt/rainbond/offline/images}
version=5.0
rainbond=(mq eventlog webcli gateway worker chaos api app-ui monitor)
base=(rbd-db rbd-dns rbd-repo)
runtime=(builder runner adapter)
k8s=(kube-scheduler kube-controller-manager kube-apiserver)
plugins=(tcm mesh_plugin)
mkdir -pv ${offline_image_path}/{base,rainbond}

base_images(){
    docker pull rainbond/cni:k8s_5.0
    docker save rainbond/cni:k8s_5.0 > ${offline_image_path}/base/cni_k8s.tgz
    docker pull rainbond/kubecfg:dev
    docker save rainbond/kubecfg:dev > ${offline_image_path}/base/kubecfg_dev.tgz
    docker pull rainbond/cfssl:dev
    docker save rainbond/cfssl:dev > ${offline_image_path}/base/cfssl_dev.tgz
    for img in ${base[@]}
    do
        [ -f "${offline_image_path}/base/${img}.tgz" ] && rm -rf ${offline_image_path}/base/${img}.tgz
        docker pull rainbond/${img}:${version}
        docker tag rainbond/${img}:${version} goodrain.me/${img}:${version}
        docker save goodrain.me/${img}:${version} > ${offline_image_path}/base/${img}.tgz
    done
    for pimg in ${plugins[@]}
    do
        docker pull rainbond/plugins:${pimg}
        docker tag rainbond/plugins:${pimg} goodrain.me/${pimg}
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
        docker pull rainbond/${kimg}:v1.10.11
        docker tag rainbond/${kimg}:v1.10.11 goodrain.me/${kimg}:v1.10.11
        [ -f "${offline_image_path}/base/${kimg}.tgz" ] && rm -rf ${offline_image_path}/base/${kimg}.tgz
        docker save goodrain.me/${kimg}:v1.10.11 > ${offline_image_path}/base/${kimg}.tgz
    done
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
    docker pull rainbond/cni:rbd_5.0
    docker save rainbond/cni:rbd_5.0 > ${offline_image_path}/rainbond/cni_rbd.tgz
}

rainbond_tgz(){
    rainbond_images
    pushd $offline_image_path/rainbond
        [ -f "$offline_image_path/rainbond.images.tgz" ] && rm -rf $offline_image_path/rainbond.images.tgz
        tar zcf $offline_image_path/rainbond.images.tgz `find .  | sed 1d`
    popd
}

base_tgz(){
    base_images
    pushd $offline_image_path/base
        [ -f "$offline_image_path/base.images.tgz" ] && rm -rf $offline_image_path/base.images.tgz
        tar zcf $offline_image_path/base.images.tgz `find .  | sed 1d`
    popd
}


rainbond_tgz
base_tgz