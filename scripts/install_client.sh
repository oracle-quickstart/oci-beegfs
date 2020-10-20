set -x

# Disable SELinux
cp /etc/selinux/config /etc/selinux/config.backup
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
setenforce 0


# For OL UEK
# To install a kernel-uek-devel version which is for the installed kernel version.
uname -r | grep "uek.x86_64$"
if [ $? -eq 0 ]; then
  echo "Oracle Linux UEK kernel found"
  sudo yum install -y --setopt=skip_missing_names_on_install=False  "kernel-uek-devel-uname-r == $(uname -r)"
  if [ $? -ne 0 ]; then
    kernelVersion=`uname -a  | gawk -F" " '{ print $3 }' ` ; echo $kernelVersion
    curl -O https://yum.oracle.com/repo/OracleLinux/OL7/UEKR5/archive/x86_64/getPackage/kernel-uek-devel-${kernelVersion}.rpm
    yum install -y ./kernel-uek-devel-${kernelVersion}.rpm
  fi
else
    cat /etc/os-release | grep "^NAME=" | grep "CentOS"
    if [ $? -eq 0 ]; then
        # For CentOS
        sudo yum install -y --setopt=skip_missing_names_on_install=False "kernel-devel-uname-r == $(uname -r)"
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
    fi

    cat /etc/os-release | grep "^NAME=" | grep -i "Oracle"
    if [ $? -eq 0 ]; then
      sudo yum install -y --setopt=skip_missing_names_on_install=False "kernel-devel-uname-r == $(uname -r)"
    fi
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



if [ "$management_high_availability" = "true" ]; then
  mgmt_host=${management_vip_private_ip}
else
  mgmt_host=${management_server_filesystem_vnic_hostname_prefix}1.${filesystem_subnet_domain_name}
fi


# client and command-line utils
##wget -O /etc/yum.repos.d/beegfs_rhel7.repo https://www.beegfs.io/release/latest-stable/dists/beegfs-rhel7.repo
##yum install beegfs-client beegfs-helperd beegfs-utils -y
install_beegfs "client"

# For OL UEK
# To install a kernel-uek-devel version which is for the installed kernel version.
uname -r | grep "uek.x86_64$"
if [ $? -eq 0 ]; then
  echo "Oracle Linux UEK kernel found"
  sudo yum install -y elfutils-libelf-devel
  #  Fix for OL UEK for beegfs rebuild to work.  Should be ran after beegfs-client is installed.
  sed -i -e '/ifeq.*compat-2.6.h/,+3 s/^/# /' /opt/beegfs/src/client/client_module_7/source/Makefile

  # if Node is HPC node, then rebuild using RDMA, even if you do not plan to use RDMA for beegfs.
  ifconfig | grep enp94s0f0
  if [ $? -eq 0 ]; then
    sed -i 's|^buildArgs=-j8|buildArgs=-j8 BEEGFS_OPENTK_IBVERBS=1 OFED_INCLUDE_PATH=/usr/src/ofa_kernel/default/include|g' /etc/beegfs/beegfs-client-autobuild.conf
  fi
  # UEK without RDMA also needs rebuild.
  # Run rebuild command
  /etc/init.d/beegfs-client rebuild
fi


# client setup
/opt/beegfs/sbin/beegfs-setup-client -m ${mgmt_host}

# Update client mount config to use custom mount point. /mnt/beegfs
sed -i "s|/mnt/beegfs|${mount_point}|g"  /etc/beegfs/beegfs-mounts.conf



# client tuning
sed -i 's/connMaxInternodeNum.*= 12/connMaxInternodeNum          = 24/g'  /etc/beegfs/beegfs-client.conf
# https://www.beegfs.io/wiki/Striping
echo "tuneFileCacheBufSize = 2097152" >> /etc/beegfs/beegfs-client.conf


# On Client nodes, update beegfs files to use 1st VNIC only, sometimes can result in high latency.
privateIp=`curl -s http://169.254.169.254/opc/v1/vnics/ | jq '.[0].privateIp ' | sed 's/"//g' ` ; echo $privateIp
interface=`ip addr | grep -B2 $privateIp | grep "BROADCAST" | gawk -F ":" ' { print $2 } ' | sed -e 's/^[ \t]*//'` ; echo $interface
type="client"
cat /etc/beegfs/beegfs-${type}.conf | grep "^connInterfacesFile"
echo "$interface" > /etc/beegfs/${type}-connInterfacesFile.conf
sed -i "s|connInterfacesFile.*=.*|connInterfacesFile          = /etc/beegfs/${type}-connInterfacesFile.conf|g"  /etc/beegfs/beegfs-${type}.conf
cat /etc/beegfs/beegfs-${type}.conf | grep "^connInterfacesFile"
cat /etc/beegfs/${type}-connInterfacesFile.conf


# Start services.  They create log files here:  /var/log/beegfs-...
systemctl start beegfs-helperd ; systemctl status beegfs-helperd
systemctl start beegfs-client ; systemctl status beegfs-client

systemctl enable beegfs-helperd
systemctl disable beegfs-client
systemctl list-unit-files | grep beegfs

# Retry until successful. It retries until all dependent server nodes and their services/deamons are up and ready for clients to connect and mount file system
( while !( systemctl restart beegfs-client )
do
   # This ensures, all dependent services are up, until then retry
   echo waiting for beegfs-client to come online
   sleep 10
done ) 

df -h

# Update stripe_size
beegfs-ctl --setpattern --chunksize=${stripe_size} --numtargets=4 ${mount_point}

# post deployment, optional scripts like ior_install.sh will only run if below file exist. 
touch /tmp/mount.complete

