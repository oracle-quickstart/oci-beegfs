set -x

echo "storage_server_dual_nics=\"${storage_server_dual_nics}\"" >> /tmp/env_variables.sh


wget -O /etc/yum.repos.d/beegfs_rhel7.repo https://www.beegfs.io/release/latest-stable/dists/beegfs-rhel7.repo


# metadata service; libbeegfs-ib is only required for RDMA
#yum install beegfs-meta libbeegfs-ib  -y
yum install beegfs-meta -y


chunk_size=${block_size}; chunk_size_tmp=`echo $chunk_size | gawk -F"k|K|KB|kb" ' { print $1 }'` ;
echo $chunk_size_tmp;


nvme_lst=$(ls /dev/ | grep nvme | grep n1 | sort)
nvme_cnt=$(ls /dev/ | grep nvme | grep n1 | wc -l)

disk_list=""
for disk in $nvme_lst
do
  disk_list="$disk_list /dev/$disk"
done
echo "disk_list=$disk_list"

if [ $nvme_cnt -ge 2 ]; then
  raid_device_count=$nvme_cnt
  raid_device_name="md0"
  # mdadm requires the chunk size to use uppercase K, eg: 64K. But mkfs.xfs su option expects it to be lowercase k.  eg: su=64k
  mdadm --create $raid_device_name --level=0 --chunk=${block_size}K --raid-devices=$nvme_cnt $disk_list
  mount_device_name="/dev/md/${raid_device_name}"
elif [ $nvme_cnt -eq 1 ]; then
  mount_device_name="$disk_list"
else
  echo "No NVMe disks"
fi

if [ $nvme_cnt -ge 1 ]; then
  # Extract value "n" from any hostname like storage-server-n. n>=1
  num=`hostname | gawk -F"." '{ print $1 }' | gawk -F"-"  'NF>1&&$0=$(NF)'`
  id=$num
  count=1
  # mdadm requires the chunk size to use uppercase K, eg: 64K. But mkfs.xfs su option expects it to be lowercase k.  eg: su=64k
  mkfs.xfs -d su=${block_size}k,sw=$nvme_cnt -l version=2,su=${block_size}k $mount_device_name
  mkdir -p /data/mdt${count}
  mount -t xfs -o noatime,inode64,nobarrier $mount_device_name /data/mdt${count}
  mkdir -p /data/mdt${count}/beegfs_meta
  /opt/beegfs/sbin/beegfs-setup-meta -p /data/mdt${count}/beegfs_meta -s $id -m ${management_server_filesystem_vnic_hostname_prefix}1.${filesystem_subnet_domain_name}
  echo "$mount_device_name  /data/mdt${count}   xfs     noatime,inode64,nobarrier  1 2" >> /etc/fstab

fi


if [ $nvme_cnt -eq 0 ]; then


  # Wait for block-attach of the Block volumes to complete. Terraform then creates the below file on server nodes of cluster.
  while [ ! -f /tmp/block-attach.complete ]
  do
    sleep 60s
    echo "Waiting for block-attach via Terraform to  complete ..."
  done


  # Gather list of block devices for setup
  blk_lst=$(lsblk -d --noheadings | grep -v sda | grep -v nvme | awk '{ print $1 }' | sort)
  blk_cnt=$(lsblk -d --noheadings | grep -v sda | grep -v nvme | wc -l)

  disk_list=""
  for disk in $blk_lst
  do
    disk_list="$disk_list /dev/$disk"
  done
  echo "disk_list=$disk_list"

  if [ $blk_cnt -ge 2 ]; then
    raid_device_count=$blk_cnt
    raid_device_name="md0"
    # mdadm requires the chunk size to use uppercase K, eg: 64K. But mkfs.xfs su option expects it to be lowercase k.  eg: su=64k
    mdadm --create $raid_device_name --level=0 --chunk=${block_size}K --raid-devices=$blk_cnt $disk_list
    mount_device_name="/dev/md/${raid_device_name}"
  elif [ $blk_cnt -eq 1 ]; then
    mount_device_name="$disk_list"
  else
    echo "No Block Volume disks"
  fi


  if [ $blk_cnt -ge 1 ]; then
    # Extract value "n" from any hostname like storage-server-n. n>=1
    num=`hostname | gawk -F"." '{ print $1 }' | gawk -F"-"  'NF>1&&$0=$(NF)'`
    id=$num
    count=1
    # mdadm requires the chunk size to use uppercase K, eg: 64K. But mkfs.xfs su option expects it to be lowercase k.  eg: su=64k
    mkfs.xfs -d su=${block_size}k,sw=$blk_cnt -l version=2,su=${block_size}k $mount_device_name
    mkdir -p /data/mdt${count}
    mount -t xfs -o noatime,inode64,nobarrier $mount_device_name /data/mdt${count}
    mkdir -p /data/mdt${count}/beegfs_meta
    /opt/beegfs/sbin/beegfs-setup-meta -p /data/mdt${count}/beegfs_meta -s $id -m ${management_server_filesystem_vnic_hostname_prefix}1.${filesystem_subnet_domain_name}
    echo "$mount_device_name  /data/mdt${count}   xfs     noatime,inode64,nobarrier  1 2" >> /etc/fstab

  fi

# close - if [ $nvme_cnt -eq 0 ]; then
fi


# Configure second vNIC
scriptsource="https://raw.githubusercontent.com/oracle/terraform-examples/master/examples/oci/connect_vcns_using_multiple_vnics/scripts/secondary_vnic_all_configure.sh"
vnicscript=/root/secondary_vnic_all_configure.sh
curl -s $scriptsource > $vnicscript
chmod +x $vnicscript
cat > /etc/systemd/system/secondnic.service << EOF
[Unit]
Description=Script to configure a secondary vNIC

[Service]
Type=oneshot
ExecStart=$vnicscript -c
ExecStop=$vnicscript -d
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target

EOF

systemctl enable secondnic.service
systemctl start secondnic.service

# put this in the background so the main script can terminate and continue with the deployment
while !( systemctl restart secondnic.service )
do
   # give the infrastructure another 10 seconds to provide the metadata for the second vnic
   echo waiting for second NIC to come online
   sleep 10
done


# Start services.  They create log files here:  /var/log/beegfs-...
systemctl start beegfs-meta
systemctl enable beegfs-meta


# put this in the background so the main script can terminate and continue with the deployment
( while !( systemctl restart beegfs-meta )
do
   # This ensures, all dependent services are up, until then retry
   echo waiting for beegfs-meta to come online
   sleep 10
done ) &

