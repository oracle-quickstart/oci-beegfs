set -x

function confirm_service_starts {
  # put this in the background so the main script can terminate and continue with the deployment
  ( while !( systemctl restart $service_name )
  do
    echo waiting for beegfs-meta to come online
    sleep 10
  done ) &
}

function configure_disks {

# For meta-data, use 4K default.
block_size=4

count=1
port_index=8005
conf_file="/etc/beegfs/beegfs-meta.conf"
for disk in $disk_lst
do
    mount_device_name="/dev/$disk"
    stride=$((block_size*1024/4096)) ;  echo $stride
    stripe_width=$((stride*1)) ; echo $stripe_width
    mkfs.ext4 -i 2048 -I 512 -J size=400 -Odir_index,filetype -E stride=${stride},stripe_width=${stripe_width} -F $mount_device_name
    mkdir -p /data/mdt${count}
    mount -onoatime,nodiratime,user_xattr  $mount_device_name /data/mdt${count}
    mkdir -p /data/mdt${count}/beegfs_meta

    echo "$mount_device_name  /data/mdt${count}   ext4     defaults,_netdev,noatime,nodiratime,user_xattr        0 0" >> /etc/fstab


  if [ $disk_cnt -ge 2 ]; then
    conf_dir="/etc/beegfs/meta${count}.d"
    conf_file="${conf_dir}/beegfs-meta.conf"
    mkdir $conf_dir
    cp /etc/beegfs/beegfs-meta.conf "$conf_dir/"
    /opt/beegfs/sbin/beegfs-setup-meta -c /etc/beegfs/meta${count}.d/beegfs-meta.conf -p /data/mdt${count}/beegfs_meta -s ${id}${count} -S meta${id}-meta${count} -m ${mgmt_host}
  elif [ $disk_cnt -eq 1 ]; then
    conf_file="/etc/beegfs/beegfs-meta.conf"
    /opt/beegfs/sbin/beegfs-setup-meta -p /data/mdt${count}/beegfs_meta -s $id -m ${mgmt_host}
  else
    echo "No $disk_type disks"
  fi

  # Changes for multi-node:  https://www.beegfs.io/wiki/MultiMode
  sed -i "s/connMetaPortTCP.*= 8005/connMetaPortTCP              = ${port_index}/g"  ${conf_file}
  sed -i "s/connMetaPortUDP.*= 8005/connMetaPortUDP              = ${port_index}/g"  ${conf_file}
  sed -i "s|logStdFile.*= /var/log/beegfs-meta.log|logStdFile                   = /var/log/beegfs-meta${count}.log|g"  ${conf_file}
  port_index=$((port_index+1000))

  # BeeGFS tuning
  sed -i 's/tuneNumWorkers.*= 0/tuneNumWorkers               = 64/g'  ${conf_file}
  sed -i 's/connMaxInternodeNum.*= 32/connMaxInternodeNum          = 32/g'  ${conf_file}
  sed -i 's/storeAllowFirstRunInit.*= false/storeAllowFirstRunInit       = true/g'  ${conf_file}
  sed -i "s|connInterfacesFile.*=.*|connInterfacesFile          = /etc/beegfs/${type}-connInterfacesFile.conf|g"  ${conf_file}

  if [ $disk_cnt -ge 2 ]; then
    service_name="beegfs-meta@meta${count}"
  elif [ $disk_cnt -eq 1 ]; then
    service_name="beegfs-meta"
  else
    echo "No $disk_type disks"
  fi

  systemctl start $service_name
  systemctl status $service_name
  systemctl disable $service_name
  confirm_service_starts
  systemctl list-unit-files | grep beegfs

  count=$((count+1))

done


}



# Start of script

# Disable locate/mlocate/updatedb
# http://www.beegfs.com/wiki/ClientTuning#hn_59ca4f8bbb_3
# Metadata nodes.  The MDT's are mounted at /data/mdtX.
sed -i 's|/mnt|/mnt /data|g'  /etc/updatedb.conf

# All this logic is only for non HA metadata service
if [ "$metadata_high_availability" = "true" ]; then
  echo "do nothing"
else

num=`hostname | gawk -F"." '{ print $1 }' | gawk -F"-"  'NF>1&&$0=$(NF)'`
id=$num

nvme_lst=$(ls /dev/ | grep nvme | grep n1 | sort)
nvme_cnt=$(ls /dev/ | grep nvme | grep n1 | wc -l)

disk_lst=$nvme_lst
disk_cnt=$nvme_cnt
disk_type="nvme"
configure_disks

if [ $nvme_cnt -eq 0 ]; then

  # Wait for block-attach of the Block volumes to complete.
  while [ ! -f /tmp/block-attach.complete ]
  do
    sleep 60s
    echo "Waiting for block-attach via Terraform to  complete ..."
  done


  blk_lst=$(lsblk -d --noheadings | egrep -v -w "sda1|sda2|sda3|sda" | grep -v nvme | awk '{ print $1 }' | sort)
  blk_cnt=$(lsblk -d --noheadings | egrep -v -w "sda1|sda2|sda3|sda" | grep -v nvme | wc -l)

  disk_lst=$blk_lst
  disk_cnt=$blk_cnt
  disk_type="block"
  configure_disks

# close - if [ $nvme_cnt -eq 0 ]; then
fi

# close of non-HA metadata if condition
fi



