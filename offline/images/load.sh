#!/bin/bash

set -x

pushd /grdata/services/offline/images
ls | grep tgz | xargs -I {} docker load -i ./{}
popd
