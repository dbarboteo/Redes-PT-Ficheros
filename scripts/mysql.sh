#!/bin/bash

apt-get update -y
apt-get upgrade -y
apt-get install mariadb-server mariadb-client -y

systemctl enable mariadb
systemctl restart mariadb

mv "/etc/mysql/mariadb.conf.d/50-server.cnf" "/etc/mysql/mariadb.conf.d/50-server.cnf.old"
cp /home/ubuntu/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf

mysql -e "CREATE DATABASE ftp_users;"
mysql -e "CREATE USER 'ftp'@'172.31.%.%' IDENTIFIED BY 'Contraseña';"
mysql -e "GRANT ALL PRIVILEGES ON ftp_users.* TO 'ftp'@'172.31.%.%';"
mysql -e "FLUSH PRIVILEGES;"


echo "mySQL instalado"