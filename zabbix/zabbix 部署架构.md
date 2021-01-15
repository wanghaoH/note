# 概述

​	zabbix 目前部署方式为单机，数据库采用的阿里云的 RDS 实例

​	zabbix-server：CPU 4核  内存：8G   硬盘：40G

​	RDS 实例：CPU：8核   内存：32G   硬盘：200G

​	软件版本：

​			MySQL：5.6

​			zabbix： 3.2

​			nginx：	1.10.2

​			php:   	5.6

![zabbix 架构图](http://note.youdao.com/yws/api/personal/file/WEB43b9bd3a5a7c27a296665a2341579ffe?method=download&shareKey=0438bb0c71a1f5559702b077e27fa050)

## zabbix 主被动介绍

* 主动：agent请求server获取主动的监控项列表，并主动将监控项内需要检测的数据提交给server/proxy

  ```
  supported items通信过程
      Server打开一个TCP连接
      Server发送请求agent.ping\n
      Agent接收到请求并且响应<HEADER><DATALEN>1
      Server处理接收到的数据1
      关闭TCP连接
  not supported items通信过程
      Server打开一个TCP连接
      Server发送请求vfs.fs.size[/nono]\n
      Agent接收请求并且返回响应数据 <HEADER><DATALEN>ZBX_NOTSUPPORTED\0Cannot obtain filesystem information: [2] No such file or directory
      Server接收并处理数据, 将item的状态改为“ not supported ”
      关闭TCP连接
  ```

  ​

* 被动：server向agent请求获取监控项的数据，agent返回数据。

  ```
  Agent建立TCP连接
  Agent提交items列表收集的数据
  Server处理数据，并返回响应状态
  关闭TCP连接
  ```

  ​

# zabbix-server 部署

* 安装编译依赖包

  ```
  yum install gcc make gd-devel libjpeg-devel libpng-devel libxml2-devel bzip2-devel libcurl-devel curl-devel net-snmp-devel lrzsz
  ```

* 安装 nginx MySQL

  * 安装 MySQL 官方源

    ```
    rpm -ivh https://repo.mysql.com//mysql57-community-release-el6-11.noarch.rpm
    ```

  * 修改 yum 源配置文件

    ```
    vim /etc/yum.repos.d/mysql-community.repo
    将 [mysql56-community] 下 enabled=0 修改成 enabled=1
    将 [mysql57-community] 下 enabled=1 修改成 enabled=0
    ```

  * 安装 MySQL nginx

    ```
    yum install -y nginx mysql-server mysql-devel
    # 初始化数据库
    service mysqld start
    # 设置数据库密码
    /usr/bin/mysqladmin -u root password root1234
    # 配置 zabbix 数据库
    shell> mysql -uroot -proot1234
    mysql> create database zabbix character set utf8 collate utf8_bin;
    mysql> grant all privileges on zabbix.* to zabbix@localhost identified by 'zabbix';
    mysql> quit;
    ```

* 安装 php 环境

  ```
  rpm -Uvh http://ftp.iij.ad.jp/pub/linux/fedora/epel/6/i386/epel-release-6-8.noarch.rpm;
  rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-6.rpm;
  yum install -y libtiff libwebp
  yum install -y --enablerepo=remi --enablerepo=remi-php56 php php-mysql php-opcache php-pecl-apcu php-devel php-mbstring php-mcrypt php-mysqlnd php-phpunit-PHPUnit php-pecl-xdebug php-pecl-xhprof php-pdo php-pear php-fpm php-cli php-xml php-bcmath php-process php-gd php-common
  ```

  ​

* 安装 zabbix-server

  * 下载 zabbix-server 源码

    ```
    wget https://jaist.dl.sourceforge.net/project/zabbix/ZABBIX%20Latest%20Stable/3.2.9/zabbix-3.2.9.tar.gz
    tar -zxvf zabbix-3.2.9.tar.gz
    # 新建用户
    groupadd zabbix
    useradd -g zabbix zabbix
    cd zabbix-3.2.9
    ```

    * 安装 zabbix-server 以及 zabbix-agent

      ```
      ./configure --prefix=/usr/local/zabbix/ --sysconfdir=/etc/zabbix/ --enable-server --enable-agent --with-mysql --enable-ipv6 --with-net-snmp --with-libcurl --with-libxml2
      make install
      # zabbix 目录：/usr/local/zabbix/
      ```


    * 导入 mysql 数据库脚本

      ```
      mysql -uzabbix -pzabbix zabbix < database/mysql/schema.sql
      mysql -uzabbix -pzabbix zabbix < database/mysql/images.sql
      mysql -uzabbix -pzabbix zabbix < database/mysql/data.sql
      ```
    
    * 部署 zabbix-web
    
      ```
      mkdir /var/www/html/zabbix/
      cd frontends/php
      cp -a . /var/www/html/zabbix/
      ```

* 修改配置文件

  * 修改 zabbix-server 配置文件

    ```
    grep -vE '^$|^;|^#' /etc/zabbix_server.conf
    LogFile=/tmp/zabbix_server.log
    DBName=zabbix
    DBUser=zabbix
    DBPassword=zabbix
    DBPort=3306
    Timeout=4
    LogSlowQueries=3000
    ```

  * 修改 php 配置文件

    ```
    vim /etc/php.ini
    max_execution_time = 300 
    memory_limit = 128M 
    post_max_size = 16M 
    upload_max_filesize = 2M 
    max_input_time = 300 
    always_populate_raw_post_data -1
    date.timezone = PRC
    ```

  * 修改 nginx 配置文件

    ```
    vim /etc/nginx/conf.d/zabbix.conf
    # HTTPS server configuration

    server {
    	listen 443 ssl;
    	server_name zabbix.igamesofficial.com;

    	ssl_certificate /etc/nginx/certs/igamesofficial.com.pem;
    	ssl_certificate_key /etc/nginx/certs/igamesofficial.com.key;
    	ssl_session_cache shared:SSL:1m;
    	ssl_session_timeout 10m;
    	ssl_ciphers HIGH:!aNULL:!MD5;
    	ssl_prefer_server_ciphers on;
    	location / {
    		root /var/www/html/zabbix/;
    		index index.html index.htm index.php;
    	}

    	location ~ .*\.(php|php5)?$
    	{
    		fastcgi_pass 127.0.0.1:9000;
    		fastcgi_index index.php;
    		fastcgi_param SCRIPT_FILENAME /var/www/html/zabbix/$fastcgi_script_name;
    		include fastcgi_params;
    	}
    	location ~ .*\.(js|css|png|jpg|mp3|mp4|wam|gif|swf|jpeg)$ {
    		root /var/www/html/zabbix/;
            	expires 7d;
        	}
    	error_page 500 502 503 504 /50x.html;
    	location = /50x.html {
    		root /usr/share/nginx/html;
    	}

    	error_page 404 /404.html;
    	location = /40x.html {
    		root /usr/share/nginx/html;
    	}
    }

    vim /etc/nginx/conf.d/zabbix.conf
        server {
            listen       80 default_server;
            server_name  zabbix.igamesofficial.com;
            root         /var/www/html/zabbix/;

            location / {

    		 if (!-f $request_filename ){
                    rewrite ^/(.*) /index.php?$1;

            }

    	 location ~ .*\.(php|php5)?$
    	    {
          		#fastcgi_pass  default-cgi;
    	      fastcgi_pass  127.0.0.1:9000;
    	      fastcgi_index index.php;
    	      fastcgi_param SCRIPT_FILENAME /var/www/html/zabbix/$fastcgi_script_name;
    	      include fastcgi_params;
    	}
    	      error_page 404 /404.html;
                location = /40x.html {
            }

            error_page 500 502 503 504 /50x.html;
                location = /50x.html {
            }
        }
    }
    ```


* 启动

  ```
  service nginx start
  service php-fpm start
  /usr/local/zabbix/sbin/zabbix_server
  /usr/local/zabbix/sbin/zabbix_agentd
  访问 zabbix.igamesofficial.com 进行 web 安装配置
  默认用户名:Admin，密码:zabbix
  ```

# zabbix-proxy 部署
* 安装 MySQL

  * 安装 MySQL 官方源

    ```
    rpm -ivh https://repo.mysql.com//mysql57-community-release-el6-11.noarch.rpm
    ```

  * 修改 yum 源配置文件

    ```
    vim /etc/yum.repos.d/mysql-community.repo
    将 [mysql56-community] 下 enabled=0 修改成 enabled=1
    将 [mysql57-community] 下 enabled=1 修改成 enabled=0
    ```

  * 安装 MySQL 

    ```
    yum install -y mysql-server mysql-devel
    # 初始化数据库
    service mysqld start
    # 设置数据库密码
    /usr/bin/mysqladmin -u root password root1234
    # 配置 zabbix 数据库
    shell> mysql -uroot -proot1234
    mysql> create database zabbix character set utf8 collate utf8_bin;
    mysql> grant all privileges on zabbix.* to zabbix@localhost identified by 'zabbix';
    mysql> quit;
    ```

- 安装 zabbix-proxy

  ```
  rpm -ivh http://repo.zabbix.com/zabbix/3.2/rhel/6/x86_64/zabbix-release-3.2-1.el6.noarch.rpm
  yum install -y zabbix-proxy-mysql zabbix-sender zabbix-get
  ```

- 导入数据库文件

  ```
  zcat /usr/share/doc/zabbix-proxy-mysql-3.2.9/schema.sql.gz | mysql -uroot -p zabbix
  ```

- 修改配置文件

  ```
  grep -vE '^$|^;|^#' /etc/zabbix/zabbix_proxy.conf
  Server=60.205.206.165 //zabbix-server 的 IP 地址
  Hostname=Zabbix proxy 
  LogFile=/var/log/zabbix/zabbix_proxy.log
  LogFileSize=0
  PidFile=/var/run/zabbix/zabbix_proxy.pid
  DBName=zabbix
  DBUser=zabbix
  DBPassword=zabbix
  DBPort=3306
  SNMPTrapperFile=/var/log/snmptrap/snmptrap.log
  Timeout=4
  ExternalScripts=/usr/lib/zabbix/externalscripts
  LogSlowQueries=3000
  ```

- 启动

  ```
  service zabbix_proxy start
  ```

  ​

# zabbix-agent 部署

- 安装

  ```
  rpm -ivh http://repo.zabbix.com/zabbix/3.2/rhel/6/x86_64/zabbix-release-3.2-1.el6.noarch.rpm
  yum install -y zabbix-agent zabbix-sender zabbix-get
  ```

- 修改配置文件

  ```
  grep -vE '^$|^;|^#' /etc/zabbix/zabbix_agentd.conf
  PidFile=/var/run/zabbix/zabbix_agentd.pid
  LogFile=/var/log/zabbix/zabbix_agentd.log
  LogFileSize=0
  Server=172.17.157.144 // zabbix-server 或者 zabbix-proxy 的地址
  ServerActive=172.17.157.144 // zabbix-server 或者 zabbix-proxy 的地址
  Hostname=Zabbix agent
  Include=/etc/zabbix/zabbix_agentd.d/*.conf
  ```

- 启动

  ```
  service zabbix-agent start
  ```

# 基础模板概述

```
vim 
Include=/etc/zabbix/zabbix_agentd.d/zabbix_agentd.userparams.conf //配置文件存放目录
```

## Linux 基础性能

### 模板介绍

​	监控 linux 系统的基础性能（CPU、内存、TCP 、连接数、DiskIO等）	

### 使用方法

```
mkdir /etc/zabbix/zabbix_agentd.d
cp    tcp_conn_status.sh discover_disk.pl zbx_parse_iostat_values.sh port_status.sh /etc/zabbix/zabbix_agentd.d
vim zabbix_agentd.userparams.conf
# diskio discovery
UserParameter=discovery.disks.iostats,/etc/zabbix/zabbix_agentd.d/discover_disk.pl
UserParameter=custom.vfs.dev.iostats.rrqm[*],/etc/zabbix/zabbix_agentd.d/zbx_parse_iostat_values.sh $1 "rrqm/s"
UserParameter=custom.vfs.dev.iostats.wrqm[*],/etc/zabbix/zabbix_agentd.d/zbx_parse_iostat_values.sh $1 "wrqm/s"
UserParameter=custom.vfs.dev.iostats.rps[*],/etc/zabbix/zabbix_agentd.d/zbx_parse_iostat_values.sh $1 "r/s"
UserParameter=custom.vfs.dev.iostats.wps[*],/etc/zabbix/zabbix_agentd.d/zbx_parse_iostat_values.sh $1 "w/s"
UserParameter=custom.vfs.dev.iostats.rsec[*],/etc/zabbix/zabbix_agentd.d/zbx_parse_iostat_values.sh $1 "rsec/s"
UserParameter=custom.vfs.dev.iostats.wsec[*],/etc/zabbix/zabbix_agentd.d/zbx_parse_iostat_values.sh $1 "wsec/s"
UserParameter=custom.vfs.dev.iostats.avgrq[*],/etc/zabbix/zabbix_agentd.d/zbx_parse_iostat_values.sh $1 "avgrq-sz"
UserParameter=custom.vfs.dev.iostats.avgqu[*],/etc/zabbix/zabbix_agentd.d/zbx_parse_iostat_values.sh $1 "avgqu-sz"
UserParameter=custom.vfs.dev.iostats.await[*],/etc/zabbix/zabbix_agentd.d/zbx_parse_iostat_values.sh $1 "await"
UserParameter=custom.vfs.dev.iostats.svctm[*],/etc/zabbix/zabbix_agentd.d/zbx_parse_iostat_values.sh $1 "svctm"
UserParameter=custom.vfs.dev.iostats.util[*],/etc/zabbix/zabbix_agentd.d/zbx_parse_iostat_values.sh $1 "%util"
# TCP status
UserParameter=tcp.status[*],/etc/zabbix/zabbix_agentd.d/tcp_conn_status.sh $1
# 端口自动扫描
UserParameter=port_discovery,/etc/zabbix/zabbix_agentd.d/port_status.sh
```

从主机里链接 基础模板组中 Linux 基础性能 模板

## Mysql 性能监控

### 模板介绍

​	监控 MySQL 程序性能（版本、慢查询、语句条数等）

### 使用方法

```
cp mysql_status.sh /etc/zabbix/zabbix_agentd.d
vim mysql_status.sh
# 用户名
MYSQL_USER='root'

# 密码
MYSQL_PWD='Thbxz_momo2017'

# 主机地址/IP
MYSQL_HOST='127.0.0.1'

# 端口
MYSQL_PORT='3306'

vim zabbix_agentd.userparams.conf
# Mysql status
# 获取mysql版本
UserParameter=mysql.version,mysql -V
# 获取mysql性能指标
UserParameter=mysql.status[*],/etc/zabbix/zabbix_agentd.d/mysql_status.sh $1
```

从主机里链接 基础模板组中 Mysql 性能监控 模板

## Nginx 性能监控

### 模板介绍

​	监控 nginx 性能状况（活跃连接数、死活、处理请求数、QPS 等）

### 使用方法

```
cp nginx_status.sh /etc/zabbix/zabbix_agentd.d
vim nginx_status.sh
HOST="172.17.157.137"
PORT="80"

vim zabbix_agentd.userparams.conf
# nginx_status
UserParameter=nginx.status[*],/etc/zabbix/zabbix_agentd.d/nginx_status.sh $1
```

从主机里链接 基础模板组中 Nginx 性能监控 模板

## Redis 性能监控

### 模板介绍

​	监控 Redis 性能状况（每秒执行命令、连接数、内存使用等）

### 使用方法

```
cp zbx_parse_iostat_values.sh /etc/zabbix/zabbix_agentd.d
vim zbx_parse_iostat_values.sh
REDISPATH="redis-cli"
HOST="r-2zed83b174274cd4.redis.rds.aliyuncs.com"
PORT="6379"
REDIS_PA="$REDISPATH -h $HOST -p $PORT -a Thbxz2017 info"

vim zabbix_agentd.userparams.conf
# Redis 性能监控
UserParameter=redis_info[*],/usr/local/zabbix/script/zbx_redis.sh $1
```

从主机里链接 基础模板组中 Redis 性能监控 模板



