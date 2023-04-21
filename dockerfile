FROM ubuntu:22.04
WORKDIR /discourse-env
COPY init /discourse-env/
COPY install /discourse-env/
COPY mirror /discourse-env/
COPY pg_hba.conf /discourse-env/
COPY sources.list /discourse-env/
COPY discourse-app /discourse-app/
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
RUN apt-get update
RUN apt-get -y install sudo
RUN apt-get -y install wget
RUN apt-get -y install tcl
RUN cp /discourse-env/sources.list /etc/apt/sources.list
RUN apt-get update
RUN apt-get -y install pkg-config
RUN apt-get install -y git tzdata
RUN date
RUN export USER=root
RUN bash /discourse-env/init
RUN bash /discourse-env/mirror
# 固定环境变量
ENV PATH=/root/.rbenv/shims:/root/.rbenv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
RUN sudo service postgresql stop
# 执行预安装脚本
RUN cd /discourse-app/
RUN bash -c "source /discourse-env/install"
WORKDIR /discourse-app
RUN bundle install
RUN yarn install
