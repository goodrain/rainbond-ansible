.PHONY: main

main: syntax_check

.PHONY: build_ansible 
build_ansible:
	docker build -t rainbond/rainspray:5.x .

syntax_check:
	ansible-playbook -i test/hosts.ini setup.yml  --syntax-check

local-test: build_ansible
	docker run -it --rm rainbond/rainspray:5.x bash
archive:
	git archive --output rainbond-ansible.upgrade.5.1.7.tgz `git symbolic-ref --short -q HEAD`