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

user_sub_token=$USER
local_root=/home/ftp/$USER

EOF

mv "/etc/pam.d/vsftpd" "/etc/pam.d/vsftpd.old"
cat <<EOF > /etc/pam.d/vsftpd
# Standard behaviour for ftpd(8).
#auth	required	pam_listfile.so item=user sense=deny file=/etc/ftpusers onerr=succeed

# Note: vsftpd handles anonymous logins on its own. Do not enable pam_ftp.so.

# Standard pam includes
#@include common-account
#@include common-session
#@include common-auth
#auth	required	pam_shells.so

auth    required pam_mysql.so user=ftp passwd=Contraseña host=172.31.92.246 db=ftp_users table=users usercolumn=username passwdcolumn=password crypt=0
account required pam_mysql.so user=ftp passwd=Contraseña host=172.31.92.246 db=ftp_users table=users usercolumn=username passwdcolumn=password crypt=0

EOF

systemctl restart vsftpd

echo "vsftpd configurado"