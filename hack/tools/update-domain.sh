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

IP=$1

function domain() {
    EX_DOMAIN=$(cat /opt/rainbond/.domain.log)
    grep "grapps.cn" /opt/rainbond/.domain.log > /dev/null
    if [ "$?" -ne 0 ];then
        echo "DOMAIN NOT ALLOW,Only Support grapps.cn"
    else
        /usr/local/bin/domain-cli --newip $IP > /dev/null
        if [ $? -eq 0 ];then
            echo "domain change Success!!!"
        else
            echo "domain change error!!!"
        fi
    fi
}

case $1 in
    *)
        domain
    ;;
esac