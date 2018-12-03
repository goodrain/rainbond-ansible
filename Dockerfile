FROM rainbond/baseimage:ubuntu1604

ADD hack/docker/rainspray.list /etc/apt/sources.list

RUN curl -fsSL http://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | apt-key add - \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y libssl-dev python-dev sshpass python-pip docker-ce \
    && /usr/bin/python -m pip install -U pip setuptools \
    && /usr/bin/python -m pip install ansible docker-py \
    && rm -rf /var/lib/apt/lists/* 

RUN apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y iputils-ping openssh-server \
    && rm -rf /var/lib/apt/lists/* 

RUN mkdir -p /opt/rainbond/rainbond-ansible
WORKDIR /opt/rainbond/rainbond-ansible
COPY . .