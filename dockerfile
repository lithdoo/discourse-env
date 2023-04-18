FROM ubuntu:22.04
WORKDIR /discourse-env
COPY install /discourse-env/
COPY pg_hba.conf /discourse-env/
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
RUN apt-get update
RUN apt-get -y install sudo
RUN apt-get -y install wget
RUN apt-get -y install tcl
RUN apt-get -y install pkg-config
RUN apt-get install -y git tzdata
RUN date
RUN export USER=root
RUN bash /discourse-env/install