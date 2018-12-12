#!/bin/bash

DOMAIN_API="http://domain.grapps.cn"

# calico pod-network-cidr
calico_pod_network_cidr="192.168.0.0/16"
# calico & flannel (canal) pod-network-cidr
canal_pod_network_cidr="10.244.0.0/16"
# flannel pod-network-cidr
flannel_pod_network_cidr="10.244.0.0/16"


# api
#enable-feature=windows