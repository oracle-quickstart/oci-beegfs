set -x

SSH_OPTIONS=" -i /home/opc/.ssh/id_rsa -o BatchMode=yes -o StrictHostkeyChecking=no "
MDATA_VNIC_URL="http://169.254.169.254/opc/v1/vnics/"
TYPE_VIP="oss_VIP"


if [ "$storage_use_shared_disk" = "true" ]; then
 echo "skip this script file"
else



  if [ "$management_high_availability" = "true" ]; then
    mgmt_host=${management_vip_private_ip}
  else
    mgmt_host=${management_server_filesystem_vnic_hostname_prefix}1.${filesystem_subnet_domain_name}
  fi



  # storage service
  ##wget -O /etc/yum.repos.d/beegfs_rhel7.repo https://www.beegfs.io/release/latest-stable/dists/beegfs-rhel7.repo
  ##yum install beegfs-storage -y
  install_beegfs "storage"

ost_count=1
if [ "$storage_tier_1_disk_type" = "Local_NVMe_SSD" ]; then
  nvme_lst=$(ls /dev/ | grep nvme | grep n1 | sort)
  nvme_cnt=$(ls /dev/ | grep nvme | grep n1 | wc -l)

  # Extract value "n" from any hostname like storage-server-n
  num=`hostname | gawk -F"." '{ print $1 }' | gawk -F"-"  'NF>1&&$0=$(NF)'`
  id=$num
  # disk_type=0 for local nvme, 1 for high, 2 for balanced and 3 for low performance block volumes.
  disk_type=0
  count=1
  # Create XFS directly on the block. No need for pvcreate/LVM, etc.
  for disk in $nvme_lst
  do
      mkfs.xfs /dev/$disk
      mkdir -p /data/ost${ost_count}
      mount -t xfs -o noatime,inode64,nobarrier /dev/$disk /data/ost${ost_count}
      mkdir -p /data/ost${ost_count}/beegfs_storage
      /opt/beegfs/sbin/beegfs-setup-storage -p /data/ost${ost_count}/beegfs_storage -s $id -i ${id}${disk_type}${ost_count} -m ${mgmt_host}
      echo "/dev/$disk  /data/ost${ost_count}   xfs     defaults,_netdev,noatime,inode64        0 0" >> /etc/fstab
      count=$((count+1))
      ost_count=$((ost_count+1))
  done
fi


###if [ $nvme_cnt -eq 0 ]; then
if [ "$storage_tier_1_disk_type" = "Local_NVMe_SSD" ]; then
  all_block_count=$((storage_tier_2_disk_count + storage_tier_3_disk_count + storage_tier_4_disk_count))
else
  all_block_count=$((storage_tier_1_disk_count + storage_tier_2_disk_count + storage_tier_3_disk_count))
fi

# only wait for BVolume attach, if we expect blocks to be attached.
if [ $all_block_count -gt 0 ]; then
  # Wait for block-attach of the Block volumes to complete. Terraform then creates the below file on server nodes of cluster.
  while [ ! -f /tmp/block-attach.complete ]
  do
    sleep 60s
    echo "Waiting for block-attach via Terraform to  complete ..."
  done
fi

# Gather list of block devices for brick config
blk_lst=$(lsblk -d --noheadings | egrep -v -w "sda1|sda2|sda3|sda" | grep -v nvme | awk '{ print $1 }' | sort)
blk_cnt=$(lsblk -d --noheadings | egrep -v -w "sda1|sda2|sda3|sda" | grep -v nvme | wc -l)

if [ $blk_cnt -ne $all_block_count ]; then
  echo "Total block volume attached not matching input, exiting."
  exit 1;
fi

# Extract value "n" from any hostname like storage-server-n
num=`hostname | gawk -F"." '{ print $1 }' | gawk -F"-"  'NF>1&&$0=$(NF)'`
id=$num
disk_type=99
count=1
# Create XFS directly on the block. No need for pvcreate/LVM, etc.
for disk in $blk_lst
do

   if [ "$storage_tier_1_disk_type" = "Local_NVMe_SSD" ]; then
     if [ $count -le $storage_tier_2_disk_count ]; then
       disk_type=1
     elif [ $count -le $((storage_tier_2_disk_count+storage_tier_3_disk_count)) ]; then
       disk_type=2
     elif [ $count -le $((storage_tier_2_disk_count+storage_tier_3_disk_count+storage_tier_4_disk_count)) ];   then
       disk_type=3
     else
       echo "This should not happen, attached blocks are more than required by filesystem"
       #exit 1;
     fi
   else
     if [ $count -le $storage_tier_1_disk_count ]; then
       disk_type=1
     elif [ $count -le $((storage_tier_1_disk_count+storage_tier_2_disk_count)) ]; then
       disk_type=2
     elif [ $count -le $((storage_tier_1_disk_count+storage_tier_2_disk_count+storage_tier_3_disk_count)) ];   then
       disk_type=3
     else
       echo "This should not happen, attached blocks are more than required by filesystem"
       #exit 1;
     fi
   fi
    mkfs.xfs /dev/$disk
    mkdir -p /data/ost${ost_count}
    mount -t xfs -o noatime,inode64,nobarrier /dev/$disk /data/ost${ost_count}
    mkdir -p /data/ost${ost_count}/beegfs_storage
    /opt/beegfs/sbin/beegfs-setup-storage -p /data/ost${ost_count}/beegfs_storage -s $id -i ${id}${disk_type}${ost_count} -m ${mgmt_host}
    echo "/dev/$disk  /data/ost${ost_count}   xfs     defaults,_netdev,noatime,inode64        0 0" >> /etc/fstab
    count=$((count+1))
    ost_count=$((ost_count+1))
done

###fi

# call function
configure_vnics


sed -i 's/connMaxInternodeNum.*= 12/connMaxInternodeNum          = 24/g'  /etc/beegfs/beegfs-storage.conf
sed -i 's/storeAllowFirstRunInit.*= false/storeAllowFirstRunInit       = true/g'  /etc/beegfs/beegfs-storage.conf

# Update beegfs files to use 2nd VNIC only, otherwise nodes will try 1st VNIC and then 2nd. It results in high latency.
privateIp=`curl -s $MDATA_VNIC_URL | jq '.[1].privateIp ' | sed 's/"//g' ` ; echo $privateIp
interface=`ip addr | grep -B2 $privateIp | grep "BROADCAST" | gawk -F ":" ' { print $2 } ' | sed -e 's/^[ \t]*//'` ; echo $interface
type="storage"
cat /etc/beegfs/beegfs-${type}.conf | grep "^connInterfacesFile"
echo "$interface" > /etc/beegfs/${type}-connInterfacesFile.conf
sed -i "s|connInterfacesFile.*=.*|connInterfacesFile          = /etc/beegfs/${type}-connInterfacesFile.conf|g"  /etc/beegfs/beegfs-${type}.conf
cat /etc/beegfs/beegfs-${type}.conf | grep "^connInterfacesFile"
cat /etc/beegfs/${type}-connInterfacesFile.conf

# Start services.  They create log files here:  /var/log/beegfs-...
systemctl start beegfs-storage ; systemctl status beegfs-storage
systemctl disable beegfs-storage
systemctl list-unit-files | grep beegfs

# Retry until successful. It retries until all dependent server nodes and their services/deamons are up and ready to connect
( while !( systemctl restart beegfs-storage )
do
   # This ensures, all dependent services are up, until then retry
   echo waiting for beegfs-storage to come online
   sleep 10
done ) &

# end of else of if [ "$storage_use_shared_disk" = "true" ]; then
fi
