set -x

function confirm_service_starts {
  # put this in the background so the main script can terminate and continue with the deployment
  ( while !( systemctl restart $service_name )
  do
    # This ensures, all dependent services are up, until then retry
    echo waiting for beegfs-meta to come online
    sleep 10
  done ) &
}

function configure_disks {

# For meta-data, we need small block-size.  use 4K default.
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
    /opt/beegfs/sbin/beegfs-setup-meta -c /etc/beegfs/meta${count}.d/beegfs-meta.conf -p /data/mdt${count}/beegfs_meta -s ${id}${count} -S meta${id}-meta${count} -m ${management_server_filesystem_vnic_hostname_prefix}1.${filesystem_subnet_domain_name}
  elif [ $disk_cnt -eq 1 ]; then
    conf_file="/etc/beegfs/beegfs-meta.conf"
    /opt/beegfs/sbin/beegfs-setup-meta -p /data/mdt${count}/beegfs_meta -s $id -m ${management_server_filesystem_vnic_hostname_prefix}1.${filesystem_subnet_domain_name}
  else
    echo "No $disk_type disks"
  fi

  # Changes for multi-node:  https://www.beegfs.io/wiki/MultiMode
  sed -i "s/connMetaPortTCP.*= 8005/connMetaPortTCP              = ${port_index}/g"  ${conf_file}
  sed -i "s/connMetaPortUDP.*= 8005/connMetaPortUDP              = ${port_index}/g"  ${conf_file}
  sed -i "s|logStdFile.*= /var/log/beegfs-meta.log|logStdFile                   = /var/log/beegfs-meta${count}.log|g"  ${conf_file}
  port_index=$((port_index+1000))

  # BeeGFS tuning before start of service.
  sed -i 's/tuneNumWorkers.*= 0/tuneNumWorkers               = 64/g'  ${conf_file}
  # default of 32 is good.
  sed -i 's/connMaxInternodeNum.*= 32/connMaxInternodeNum          = 32/g'  ${conf_file}
  sed -i 's/storeAllowFirstRunInit.*= false/storeAllowFirstRunInit       = true/g'  ${conf_file}

  sed -i "s|connInterfacesFile.*=.*|connInterfacesFile          = /etc/beegfs/${type}-connInterfacesFile.conf|g"  ${conf_file}

  if [ $disk_cnt -ge 2 ]; then
    service_name="beegfs-meta@meta${count}"
  elif [ $disk_cnt -eq 1 ]; then
    service_name="beegfs-meta"
  else
    # This should not happen, since we are looping through nvme's
    echo "No $disk_type disks"
  fi

  systemctl start $service_name
  systemctl status $service_name
  systemctl enable $service_name
  confirm_service_starts


  count=$((count+1))

done


}




##############
function configure_vnics {

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

}


##############
# Start of script execution
#############

# Disable locate/mlocate/updatedb
# http://www.beegfs.com/wiki/ClientTuning#hn_59ca4f8bbb_3
# Metadata nodes.  The MDT's are mounted at /data/mdtX.
sed -i 's|/mnt|/mnt /data|g'  /etc/updatedb.conf


wget -O /etc/yum.repos.d/beegfs_rhel7.repo https://www.beegfs.io/release/latest-stable/dists/beegfs-rhel7.repo


# metadata service; libbeegfs-ib is only required for RDMA
#yum install beegfs-meta libbeegfs-ib  -y
yum install beegfs-meta -y



configure_vnics

privateIp=`curl -s http://169.254.169.254/opc/v1/vnics/ | jq '.[1].privateIp ' | sed 's/"//g' ` ; echo $privateIp
interface=`ip addr | grep -B2 $privateIp | grep "BROADCAST" | gawk -F ":" ' { print $2 } ' | sed -e 's/^[ \t]*//'` ; echo $interface
type="meta"
echo "$interface" > /etc/beegfs/${type}-connInterfacesFile.conf


# Extract value "n" from any hostname like storage-server-n. n>=1
num=`hostname | gawk -F"." '{ print $1 }' | gawk -F"-"  'NF>1&&$0=$(NF)'`
id=$num


nvme_lst=$(ls /dev/ | grep nvme | grep n1 | sort)
nvme_cnt=$(ls /dev/ | grep nvme | grep n1 | wc -l)

disk_lst=$nvme_lst
disk_cnt=$nvme_cnt
disk_type="nvme"
configure_disks



if [ $nvme_cnt -eq 0 ]; then

  # Wait for block-attach of the Block volumes to complete. Terraform then creates the below file on server nodes of cluster.
  while [ ! -f /tmp/block-attach.complete ]
  do
    sleep 60s
    echo "Waiting for block-attach via Terraform to  complete ..."
  done

    # Assuming no more than 4 disk will be used to create a single MDT disk.
    devices=(sdb sdc sdd sde sdf sdg sdh sdi nvme0n1 nvme1n1 nvme2n1 nvme3n1 nvme4n1 nvme5n1 nvme6n1 nvme7n1)
    for dev in "${devices[@]}"
    do
      echo deadline > /sys/block/${dev}/queue/scheduler
      echo 128 > /sys/block/${dev}/queue/nr_requests
      echo 128 > /sys/block/${dev}/queue/read_ahead_kb
      echo 256 > /sys/block/${dev}/queue/max_sectors_kb
    done

  # Gather list of block devices for setup
  blk_lst=$(lsblk -d --noheadings | egrep -v -w "sda1|sda2|sda3|sda" | grep -v nvme | awk '{ print $1 }' | sort)
  blk_cnt=$(lsblk -d --noheadings | egrep -v -w "sda1|sda2|sda3|sda" | grep -v nvme | wc -l)

  disk_lst=$blk_lst
  disk_cnt=$blk_cnt
  disk_type="block"
  configure_disks

# close - if [ $nvme_cnt -eq 0 ]; then
fi





