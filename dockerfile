FROM ubuntu:18.04
WORKDIR /discourse-env
COPY install /discourse-env/
RUN apt-get update
RUN apt-get -y install sudo
# RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
# RUN apt-get install -y git tzdata
# RUN date
RUN bash /discourse-env/install
# RUN sudo -E apt-get -y install systemd
# RUN sudo timedatectl set-timezone Asia/Shanghai
# RUN sudo -E apt-get -y install postgresql
# CMD [ "bash /discours-env/install"] 