.PHONY: main

main: syntax_check

.PHONY: build_ansible 
build_ansible:
	docker build -t rainbond/rainspray:5.x .

syntax_check:
	ansible-playbook -i test/hosts.ini setup.yml  --syntax-check

local-test: build_ansible
	docker run -it --rm rainbond/rainspray:5.x bash