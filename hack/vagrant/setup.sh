#!/bin/bash

echo root:vagrant|chpasswd

apt-get install expect -y

expect -c "
set timeout 20
spawn su - root
expect "Password:"
send "vagrant\r"
interact
"

id

ssh-keygen -t rsa -f /root/.ssh/id_rsa -P ""

sshkey="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDM4tQLufzkc5RDIRaa1N4zuXOuCSrEr4Z+cIu3U5/Z0dB1TYUBxrdAShNBoANnaL484gkXdjVDcebDGKZfOj5uvERH0FbCvrEzAYuJB+MSdLyGPDUxaae0glGWWY3tEtgT0Rr/BM/JVebUbjsZUnFGjpQS2UkSeOa9y1dtNvOAPSBZmy4N+lhBhyDSn3+gKLOXZ8btvDg2McdwIdjws6ecPkxMUxWshQlL1I/qecyJ35pr1h3f6nTVbRwApwenhEBdouW3GT0ImHPUQEd5yXg+HqwZqrWO2qwie953Rl7OofEDUR0ZcdY7vf6qxqy4w22TM2k03kj0gfQ00kC8kZuf ysicing@debian.local"
echo "${sshkey}" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
echo 'Welcome to Vagrant-built virtual machine. -.-' > /etc/motd

sed -i -e 's/^PasswordAuthentication no/#PasswordAuthentication no/g' /etc/ssh/sshd_config

systemctl restart sshd

[ ! -f "/vagrant/grctl" ] && wget https://pkg.rainbond.com/releases/common/v5.0/grctl -O /vagrant/grctl

chmod +x /vagrant/grctl

if [ "$1" == 1 ];then
    echo "start init node"
    /vagrant/grctl init --iip $2 --role manage --rainbond-version devel --rainbond-repo https://github.com/ysicing/rainbond-ansible.git
else
    echo "start join node"
    expect -c "
    set timeout 100
    spawn ssh root@172.20.0.101
    expect {
    \"yes/no\"   { send \"yes\n\"; exp_continue; }
    \"password\" { send \"vagrant\n\"; }
    \"already exist on the remote system\" { exit 1; }
    }
    expect eof
    "
    ssh 172.20.0.101 grctl node add --host $1 --iip $2 --root-pass vagrant --role compute
    uid=$(ssh 172.20.0.101 grctl node list | grep $2 | awk '{print $2}')
    ssh 172.20.0.101 grctl node install $uid
    ssh 172.20.0.101 grctl node up $uid
fi