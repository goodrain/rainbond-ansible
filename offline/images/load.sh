#!/bin/bash

set -x

pushd /opt/rainbond/rainbond-ansible/offline/images
ls | grep tgz | xargs -I {} docker load -i ./{}
popd
