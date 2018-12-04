centos-build:
	docker build -t localbuild:centos -f Dockerfile.centos .

centos-make:
	docker run --rm -v ${PWD}/centos/7:/opt/rainbond/install/install/pkgs/centos localbuild:centos

