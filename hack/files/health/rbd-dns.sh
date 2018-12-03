#!/bin/bash

isExist=`netstat -pantu | grep ":53 " | grep "kube-dns" | wc -l`

if (($isExist != 0)); then
  exit 0
else
  exit 1
fi