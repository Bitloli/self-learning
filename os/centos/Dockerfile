from centos
# RUN yum groupinstall "Development Tools"
RUN cd /etc/yum.repos.d/
RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
RUN sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*

RUN yum install -y ncurses-devel bison flex elfutils-libelf-devel openssl-devel
# RUN yum group install "Development Tools"
RUN yum groupinstall -y "Development Tools"
RUN yum install -y python3
RUN yum install -y bc
RUN yum makecache
RUN sed -i 's/enabled=0/enabled=1/' /etc/yum.repos.d/CentOS-Linux-PowerTools.repo
RUN yum install -y dwarves
# RUN yum install -y kconfig-conf
RUN yum -y install sudo
RUN yum -y install rsync
RUN useradd -m docker
RUN echo "docker:docker" | chpasswd
RUN usermod -aG wheel docker
USER docker
WORKDIR /home/docker
