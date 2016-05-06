FROM centos:7
MAINTAINER Dmitry Kuzmenkov <dmitry@wagh.ru>

RUN useradd yoda
RUN localedef -c -i en_US -f UTF-8 en_US.UTF-8
WORKDIR /home/yoda

ENV LANGUAGE en_US:en
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

ENTRYPOINT ["/init"]


