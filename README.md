[![Build Status](https://travis-ci.org/goodrain/rainbond-ansible.svg?branch=devel)](https://travis-ci.org/goodrain/rainbond-ansible)
[![FOSSA Status](https://app.fossa.io/api/projects/git%2Bgithub.com%2Fgoodrain%2Frainbond-ansible.svg?type=shield)](https://app.fossa.io/projects/git%2Bgithub.com%2Fgoodrain%2Frainbond-ansible?ref=badge_shield)

# Ansible Playbook For Rainbond

## Overview

> Deploy a Production Ready Rainbond Cluster

## Tutorial

#### Stable version installation

current version: 5.1.4

```bash
wget https://pkg.rainbond.com/releases/common/v5.1/grctl
chmod +x ./grctl
./grctl init  --iip <内网ip/Internal IP> --eip <外网ip/External IP>
```

Refer to the documentation for more information [online installation](https://www.rainbond.com/docs/user-operations/op-guide/recommendation/)


#### Development version installation

current version: devel

```bash
wget https://pkg.rainbond.com/releases/common/v5.1/grctl
chmod +x ./grctl
./grctl init --iip <内网ip/Internal IP> --eip <外网ip/External IP> --rainbond-version devel
```

## License

Rainbond-Ansible is under the Apache 2.0 license.



[![FOSSA Status](https://app.fossa.io/api/projects/git%2Bgithub.com%2Fgoodrain%2Frainbond-ansible.svg?type=large)](https://app.fossa.io/projects/git%2Bgithub.com%2Fgoodrain%2Frainbond-ansible?ref=badge_large)