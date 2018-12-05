ansible-playbook -i inventory/hosts.ini hack/step/01.prepare.yml --syntax-check
ansible-playbook -i inventory/hosts.ini hack/step/02.etcd.yml --syntax-check
ansible-playbook -i inventory/hosts.ini hack/step/03.docker.yml --syntax-check
ansible-playbook -i inventory/hosts.ini hack/step/04.kube-master.yml --syntax-check