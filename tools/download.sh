#!/bin/bash
# This script describes where to download the official released binaries needed 
# It's suggested to download the entire *.tar.gz at https://pan.baidu.com/s/1c4RFaA

K8S_VER=v1.10.11
ETCD_VER=v3.2.25
DOCKER_VER=17.06.2-ce
CNI_VER=v0.7.4
DOCKER_COMPOSE=1.23.1
HARBOR=v1.5.2
CFSSL_VERSION=R1.2
ARCH=linux-amd64
DOWNLOAD_URL=https://pkg.cfssl.org
CFSSL_PKG=(cfssl cfssljson cfssl-certinfo)

pushd ../files/bin

  echo "download cfssl ..."
  [ ! -f "ssl/cfssl" ] && (
    mkdir ssl
    for pkg in ${CFSSL_PKG[@]}
    do
      curl -s -L ${DOWNLOAD_URL}/${CFSSL_VERSION}/${pkg}_${ARCH} -o ./ssl/${pkg}
      chmod +x ./ssl/${pkg}
    done
  )
  echo "download k8s hyperkube binary"
  [ ! -f "k8s/hyperkube" ] && (
    mkdir k8s
    curl -s -L https://storage.googleapis.com/kubernetes-release/release/${K8S_VER}/bin/linux/amd64/hyperkube -o ./k8s/hyperkube
    chmod +x ./k8s/hyperkube
  )
  echo "download etcd binary"
  [ ! -f "etcd/etcd" ] && (
    mkdir etcd
    curl -s -L https://storage.googleapis.com/etcd/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
    tar xf /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz -C /tmp/
    mv  /tmp/etcd-${ETCD_VER}-linux-amd64/etcd* ./etcd/
    chmod +x ./etcd/etcd*
  )

  echo "download docker binaries..."
  [ ! -f "docker/docker" ] && (
    mkdir docker
    curl -L https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VER}.tgz -o /tmp/docker-${DOCKER_VER}.tgz
    tar xf /tmp/docker-${DOCKER_VER}.tgz -C /tmp/
    mv -f /tmp/docker/docker* ./docker/
    chmod +x ./docker/docker*
  )

  echo "download docker-compose"
  [ ! -f "docker/docker-compose" ] && (
    curl -s -L https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE}/docker-compose-Linux-x86_64 -o ./docker/docker-compose
    chmod +x ./docker/docker-compose
  )

  #echo "download harbor-offline-installer"
  #[ ! -f "harbor" ] && (
  #  curl -s -L https://github.com/vmware/harbor/releases/download/${HARBOR}/harbor-offline-installer-${HARBOR}.tgz -o /tmp/harbor-offline-installer-${HARBOR}.tgz
  #
  #)

  echo "download cni plugins"
  [ ! -f "cni/flannel" ] && (
    mkdir -p cni
    curl -s -L https://github.com/containernetworking/plugins/releases/download/${CNI_VER}/cni-plugins-amd64-${CNI_VER}.tgz -o /tmp/cni-plugins-amd64-${CNI_VER}.tgz
    tar xf /tmp/cni-plugins-amd64-${CNI_VER}.tgz -C $PWD/cni/
  )

popd