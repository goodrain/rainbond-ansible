#!/bin/bash

LOCAL_DNS="114.114.114.114"
MASTER_DNS=""
DEFALUT_DNS=""

#rep $LOCAL_DNS /etc/resolv.conf >/dev/null 2>&1
#if [ "$?" -eq 0 ];then
#    exit 0
#else
#    cat > /etc/resolv.conf <<EOF
#nameserver $LOCAL_DNS
#nameserver $MASTER_DNS
#nameserver $DEFALUT_DNS
#EOF
#    exit 1
#fi

exit 0