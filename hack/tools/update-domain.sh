#!/bin/bash

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