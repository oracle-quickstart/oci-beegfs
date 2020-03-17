set -x

#echo "storage_server_dual_nics=\"${storage_server_dual_nics}\"" >> /tmp/env_variables.sh


# For OL UEK
sudo yum install "kernel-uek-devel-uname-r == $(uname -r)"

# To install a kernel-uek-devel version which is for the installed kernel version.
# For CentOS
sudo yum install "kernel-devel-uname-r == $(uname -r)"
if [ $? -eq 0 ]; then
  echo "found correct rpm"
else
  kernelVersion=`uname -a  | gawk -F" " '{ print $3 }' ` ; echo $kernelVersion
  yum install -y redhat-lsb-core
  lsb_release -a
  fullOSReleaseVersion=`lsb_release -a | grep "Release:" | gawk -F" " '{ print $2 }'` ; echo $fullOSReleaseVersion
  rpmDownloadURLPrefix="http://archive.kernel.org/centos-vault/${fullOSReleaseVersion}/updates/x86_64/Packages"
  curl -O ${rpmDownloadURLPrefix}/kernel-devel-${kernelVersion}.rpm
  rpm -Uvh kernel-devel-${kernelVersion}.rpm  --oldpackage
fi


###### Commented this out - since I found a better way above  ######
# http://archive.kernel.org/centos-vault/7.6.1810/updates/x86_64/Packages/
# http://ftp.scientificlinux.org/linux/scientific/7.6/x86_64/updates/security
####kernelVersion=`uname -a  | gawk -F" " '{ print $3 }' ` ; echo $kernelVersion
####yum install -y redhat-lsb-core
####lsb_release -a
####osVersion=`lsb_release -a | grep "Release:" | gawk -F" " '{ print $2 }' | gawk -F"." '{ print $1"."$2 }' ` ; echo $osVersion
#rpmDownloadURLPrefix="http://ftp.scientificlinux.org/linux/scientific/${osVersion}/x86_64/updates/security"
#curl -O ${rpmDownloadURLPrefix}/kernel-devel-${kernelVersion}.rpm

####fullOSReleaseVersion=`lsb_release -a | grep "Release:" | gawk -F" " '{ print $2 }'` ; echo $fullOSReleaseVersion
####rpmDownloadURLPrefix="http://archive.kernel.org/centos-vault/${fullOSReleaseVersion}/updates/x86_64/Packages"
####curl -O ${rpmDownloadURLPrefix}/kernel-devel-${kernelVersion}.rpm

# --oldpackage
####rpm -Uvh kernel-devel-${kernelVersion}.rpm  --oldpackage
###### Commented this out - since I found a better way above  ######


wget -O /etc/yum.repos.d/beegfs_rhel7.repo https://www.beegfs.io/release/latest-stable/dists/beegfs-rhel7.repo


# client and command-line utils
yum install beegfs-client beegfs-helperd beegfs-utils -y

# client
/opt/beegfs/sbin/beegfs-setup-client -m ${management_server_filesystem_vnic_hostname_prefix}1.${filesystem_subnet_domain_name}

sed -i 's/connMaxInternodeNum.*= 12/connMaxInternodeNum          = 24/g'  /etc/beegfs/beegfs-client.conf

# Start services.  They create log files here:  /var/log/beegfs-...
systemctl start beegfs-helperd ; systemctl status beegfs-helperd
systemctl start beegfs-client ; systemctl status beegfs-client

systemctl enable beegfs-helperd
systemctl enable beegfs-client

# Retry until successful. It retries until all dependent server nodes and their services/deamons are up and ready for clients to connect and mount file system
( while !( systemctl restart beegfs-client )
do
   # This ensures, all dependent services are up, until then retry
   echo waiting for beegfs-client to come online
   sleep 10
done ) &

# post deployment, optional scripts like ior_install.sh will only run if below file exist. 
touch /tmp/mount.complete
