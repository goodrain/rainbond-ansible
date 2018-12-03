ansible-playbook -i inventory/hosts.ini 01.prepare.yml --syntax-check
ansible-playbook -i inventory/hosts.ini 02.etcd.yml --syntax-check
ansible-playbook -i inventory/hosts.ini 03.docker.yml --syntax-check
ansible-playbook -i inventory/hosts.ini 04.kube-master.yml --syntax-check