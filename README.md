# DISCOURSE-ENV

一个包含 discourse 构建环境的 docker 镜像

```
docker build -t discourse-env:latest .
```

## 安装脚本

(https://raw.githubusercontent.com/discourse/install-rails/master/linux)[https://raw.githubusercontent.com/discourse/install-rails/master/linux]

## PostgreSQL 安装失败处理

直接执行脚本会发生如下错误

```
psql: could not connect to server: No such file or directory
    Is the server running locally and accepting
    connections on Unix domain socket "/var/run/postgresql/.s.PGSQL.5432"?
```

解决方法参考 (https://stackoverflow.com/questions/31645550/postgresql-why-psql-cant-connect-to-server)[https://stackoverflow.com/questions/31645550/postgresql-why-psql-cant-connect-to-serverc]

1. 修改 pg_hba.conf 文件

```
# "local" is for Unix domain socket connections only
local       all       all       peer
```
修改为
```
# "local" is for Unix domain socket connections only
local       all       all       trust
```

2. 重启 pgsl 服务

```
sudo /etc/init.d/postgresql restart
```

如果缺少 $USER 则还需执行 `export USER=root`


## 构建完成后无法连接到数据库

构建完成后，在 image 上启动的时候会找不到 Redis 和 PGSQL 服务。

需要手动重启服务。

```
redis-server --daemonize yes
sudo /etc/init.d/postgresql restart
```