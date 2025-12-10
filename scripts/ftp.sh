#!/bin/bash

apt-get update -y
apt-get upgrade -y
apt-get install vsftpd -y
apt-get install libpam-mysql -y

systemctl enable vsftpd
systemctl restart vsftpd

mv "/etc/vsftpd.conf" "/etc/vsftpd.conf.old"
cat <<EOF > /etc/vsftpd.conf
listen=YES
listen_ipv6=NO
write_enable=YES

anonymous_enable=NO
local_enable=YES

chroot_local_user=YES
chroot_list_enable=NO
allow_writeable_chroot=YES

pasv_enable=YES
pasv_min_port=3000
pasv_max_port=3100

pam_service_name=vsftpd
utf8_filesystem=YES

guest_enable=YES
guest_username=ftp

user_sub_token=\$USER
local_root=/home/ftp/\$USER

pasv_address=${ftp_public_ip}
virtual_use_local_privs=YES
EOF

mv "/etc/pam.d/vsftpd" "/etc/pam.d/vsftpd.old"
cat <<EOF > /etc/pam.d/vsftpd
auth    required pam_mysql.so user=ftp passwd=Contraseña host=${bd_private_ip} db=ftp_users table=users usercolumn=username passwdcolumn=password crypt=0
account required pam_mysql.so user=ftp passwd=Contraseña host=${bd_private_ip} db=ftp_users table=users usercolumn=username passwdcolumn=password crypt=0
EOF

mkdir -p /home/ftp/diego
sudo chmod -R 755 /home/ftp
sudo chown -R ftp:ftp /home/ftp

systemctl restart vsftpd

echo "vsftpd configurado con FTP IP pública: ${ftp_public_ip} y BD IP privada: ${bd_private_ip}"