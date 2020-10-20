
echo "Turning off the Firewall..."
service firewalld stop
chkconfig firewalld off

cp /etc/selinux/config /etc/selinux/config.backup
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
setenforce 0

yum install -y -q telnet
