#!/bin/bash

nfs_server={{ master_ip }}

num=$(showmount -e $nfs_server | grep "/opt/rainbond" | wc -l)

if [ "$num" -ne 0 ];then
    exit 0
else
    exit 1
fi