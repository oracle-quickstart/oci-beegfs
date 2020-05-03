#######################################################"
################# Turn Off the Firewall ###############"
#######################################################"
echo "Turning off the Firewall..."
which apt-get &> /dev/null
if [ $? -eq 0 ] ; then
    echo "" > /etc/iptables/rules.v4
    echo "" > /etc/iptables/rules.v6

    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X
    iptables -t mangle -F
    iptables -t mangle -X
    iptables -P INPUT ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -P FORWARD ACCEPT
else
    service firewalld stop
    chkconfig firewalld off
fi

# Disable SELinux
cp -f /etc/selinux/config /etc/selinux/config.backup
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
setenforce 0


# Build the folder structure
cd ~/; mkdir -p rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
# Getting RPM Build
yum -y install rpm-build

# First compiling DRBD version 9
yum install "kernel-devel-uname-r == $(uname -r)"  -y
yum install "kernel-uek-devel-uname-r == $(uname -r)" -y

yum -y install cpp gcc gcc-c++

wget http://www.linbit.com/downloads/drbd/9.0/drbd-9.0.19-1.tar.gz
tar zxvf drbd-9.0.19-1.tar.gz
cd drbd-9.0.19-1/
make kmp-rpm

cd ~/
# Now compiling drbd-utils
yum -y install flex po4a gcc-c++ automake libxslt docbook-style-xsl
# Had to use 9.0.0 from archive instead of 9.10.0
wget http://www.linbit.com/downloads/drbd/utils/archive/drbd-utils-9.0.0.tar.gz
tar zxvf drbd-utils-9.0.0.tar.gz
cd drbd-utils-9.0.0/
sed -i '/%bcond_without sbinsymlinks/a %undefine with_sbinsymlinks' drbd.spec.in
./configure
make rpm
cd ~/

yum -y localinstall /root/rpmbuild/RPMS/x86_64/drbd-utils-9.0.0-1.el7.x86_64.rpm
yum -y localinstall /root/rpmbuild/RPMS/x86_64/drbd-bash-completion-9.0.0-1.el7.x86_64.rpm
yum -y localinstall /root/rpmbuild/RPMS/x86_64/drbd-pacemaker-9.0.0-1.el7.x86_64.rpm
yum -y localinstall /root/rpmbuild/RPMS/x86_64/kmod-drbd-9.0.19_3.10.0_1062.9.1-1.x86_64.rpm

# Disable DRBD if enabled by default.
systemctl disable drbd

#
yum -y install pcs pacemaker corosync
# disable all of them for the image.  Then once the DRBD is configured completely (after reboot) and all the below services are also configured, then enable them, so on each reboot, these services will be on already.
systemctl disable pcsd
systemctl disable pacemaker
systemctl disable corosync


#reboot

