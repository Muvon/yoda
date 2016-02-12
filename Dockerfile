FROM centos:7
MAINTAINER Dmitry Kuzmenkov <dmitry@wagh.ru>

RUN rpm --import http://dag.wieers.com/rpm/packages/RPM-GPG-KEY.dag.txt
RUN rpm --import https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-6
RUN rpm --import http://repo.webtatic.com/yum/RPM-GPG-KEY-webtatic-andy

RUN rpm -Uvh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm
RUN rpm -Uvh https://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm
RUN rpm -Uvh http://dl.iuscommunity.org/pub/ius/stable/CentOS/7/x86_64/ius-release-1.0-14.ius.centos7.noarch.rpm
RUN rpm -Uvh http://pkgs.repoforge.org/rpmforge-release/rpmforge-release-0.5.3-1.el7.rf.x86_64.rpm
RUN rpm -Uvh http://repo.webtatic.com/yum/el7/webtatic-release.rpm

RUN yum clean all
RUN yum repolist
RUN yum update -y

