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