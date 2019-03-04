#!/bin/bash

nfs_server={{ MASTER_IP }}

num=$(showmount -e $nfs_server | grep "/grdata " | wc -l)

if [ "$num" -eq 1 ];then
    exit 0
else
    exit 1
fi