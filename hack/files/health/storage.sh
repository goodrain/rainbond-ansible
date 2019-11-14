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

check_key="{{ secretkey }}"

if [ -f "/grdata/services/storage/health.check" ];then
    cat /grdata/services/storage/health.check | grep "$check_key" > /dev/null
    if [ "$?" -eq 0 ];then
        exit 0
    else
        exit 1
    fi
else
    [ -d "/grdata/services/storage" ] || mkdir -p /grdata/services/storage
    cat /opt/rainbond/.init/secretkey > /grdata/services/storage/health.check
    exit 1
fi