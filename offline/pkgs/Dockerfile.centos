FROM centos:7.4.1708

ADD rbd.repo /etc/yum.repos.d/rbd.repo

ADD download.centos /download.sh

RUN chmod +x download.sh

ENTRYPOINT [ "/download.sh" ]