# FROM fedora:latest

# RUN echo "[fedora]" > /etc/yum.repos.d/fedora.repo
# RUN echo "name=Fedora \$releasever - \$basearch" >> /etc/yum.repos.d/fedora.repo
# RUN echo "failovermethod=priority" >> /etc/yum.repos.d/fedora.repo
# RUN echo "baseurl=https://mirrors.tuna.tsinghua.edu.cn/fedora/releases/\$releasever/Everything/\$basearch/os/" >> /etc/yum.repos.d/fedora.repo
# RUN echo "metadata_expire=28d" >> /etc/yum.repos.d/fedora.repo
# RUN echo "gpgcheck=1" >> /etc/yum.repos.d/fedora.repo
# RUN echo "gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-\$releasever-\$basearch" >> /etc/yum.repos.d/fedora.repo
# RUN echo "skip_if_unavailable=False" >> /etc/yum.repos.d/fedora.repo
# https://fedoraproject.org/wiki/Building_a_custom_kernel
# RUN echo "fastestmirror=1" >> /etc/dnf/dnf.conf
# RUN dnf install -y fedpkg
# RUN dnf install -y fedora-packager
# RUN dnf install -y rpmdevtools
# RUN dnf install -y ncurses-devel
# RUN dnf install -y pesign grubby
# RUN dnf builddep kernel.spec
