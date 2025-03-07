

ssh-keygen
wget https://622.gomillion.org/authorized_keys
chmod 600 authorized_keys

cd ..

cd /etc/yum.repos.d
vim mariadb.repo -- then add the mariadb.org text
amazon-linux-extras install epel -y
yum install MariaDB-server MariaDB-client galera-4 rsync dos2unix -y

systemctl enable mariadb
systemctl start mariadb
