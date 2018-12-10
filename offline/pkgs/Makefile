centos-build:
	docker build -t localbuild:centos -f Dockerfile.centos .

centos-make:
	docker run --rm -v ${PWD}/centos/7:/opt/rainbond/rainbond-ansible/offline/pkgs/centos/7 localbuild:centos

