[![Build Status](https://travis-ci.org/goodrain/rainbond-ansible.svg?branch=devel)](https://travis-ci.org/goodrain/rainbond-ansible)

# Ansible Playbook For Rainbond

## Overview

> Deploy a Production Ready Rainbond Cluster

## Tutorial

#### Stable version installation

current version: 5.0.2

```bash
wget https://pkg.rainbond.com/releases/common/v5.0/grctl
chmod +x ./grctl
./grctl init  --iip <内网ip/Internal IP> --eip <外网ip/External IP>
```

Refer to the documentation for more information [online installation](https://www.rainbond.com/docs/stable/getting-started/online-installation.html)


#### Development version installation

current version: devel

```bash
wget https://pkg.rainbond.com/releases/common/v5.0/grctl
chmod +x ./grctl
./grctl init --iip <内网ip/Internal IP> --eip <外网ip/External IP> --rainbond-version devel
```

## License

Rainbond-Ansible is under the Apache 2.0 license.

