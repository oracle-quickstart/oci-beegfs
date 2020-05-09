set -x




#
# Start of script
#
# All this logic is only for single node - management service
if [ "$management_high_availability" = "true" ]; then
  mgmt_host=${management_vip_private_ip}
  exit 0;
else
  mgmt_host=${management_server_filesystem_vnic_hostname_prefix}1.${filesystem_subnet_domain_name}

  # call function
  configure_vnics

  wget -O /etc/yum.repos.d/beegfs_rhel7.repo https://www.beegfs.io/release/latest-stable/dists/beegfs-rhel7.repo
  yum install beegfs-mgmtd -y

  num=`hostname | gawk -F"." '{ print $1 }' | gawk -F"-"  'NF>1&&$0=$(NF)'`
  id=$num
  count=1

  nvme_lst=$(ls /dev/ | grep nvme | grep n1 | sort)
  nvme_cnt=$(ls /dev/ | grep nvme | grep n1 | wc -l)

  count=1
  disk_list=""
  for disk in $nvme_lst
  do
    if [ $count -eq 1 ];then
      mkfs.xfs /dev/$disk
      mkdir -p /data/mgt${count}
      mount -t xfs -o noatime,inode64,nobarrier /dev/$disk /data/mgt${count}
      mkdir -p /data/mgt${count}/beegfs_mgmtd
      /opt/beegfs/sbin/beegfs-setup-mgmtd -p /data/mgt${count}/beegfs_mgmtd
      echo "/dev/$disk  /data/mgt${count}   xfs     defaults,_netdev,noatime,inode64        0 0" >> /etc/fstab
    fi
    count=$((count+1))
  done



  if [ $nvme_cnt -eq 0 ]; then


    # Wait for block-attach of the Block volumes to complete. Terraform then creates the below file on server nodes of cluster.
    while [ ! -f /tmp/block-attach.complete ]
    do
      sleep 60s
      echo "Waiting for block-attach via Terraform to  complete ..."
    done


    # Gather list of block devices for setup
    blk_lst=$(lsblk -d --noheadings | egrep -v -w "sda1|sda2|sda3|sda" | grep -v nvme | awk '{ print $1 }' | sort)
    blk_cnt=$(lsblk -d --noheadings | egrep -v -w "sda1|sda2|sda3|sda" | grep -v nvme | wc -l)

    count=1
    for disk in $blk_lst
    do
      if [ $count -eq 1 ];then
        mkfs.xfs /dev/$disk
        mkdir -p /data/mgt${count}
        mount -t xfs -o noatime,inode64,nobarrier /dev/$disk /data/mgt${count}
        mkdir -p /data/mgt${count}/beegfs_mgmtd
        /opt/beegfs/sbin/beegfs-setup-mgmtd -p /data/mgt${count}/beegfs_mgmtd
        echo "/dev/$disk  /data/mgt${count}   xfs     defaults,_netdev,noatime,inode64        0 0" >> /etc/fstab
      fi
      count=$((count+1))
    done

  fi

  # Update beegfs files to use 2nd VNIC only, otherwise nodes will try 1st VNIC and then 2nd. It results in high latency.
  privateIp=`curl -s http://169.254.169.254/opc/v1/vnics/ | jq '.[1].privateIp ' | sed 's/"//g' ` ; echo $privateIp
  interface=`ip addr | grep -B2 $privateIp | grep "BROADCAST" | gawk -F ":" ' { print $2 } ' | sed -e 's/^[ \t]*//'` ; echo $interface
  type="mgmtd"
  cat /etc/beegfs/beegfs-${type}.conf | grep "^connInterfacesFile"
  echo "$interface" > /etc/beegfs/${type}-connInterfacesFile.conf
  sed -i "s|connInterfacesFile.*=.*|connInterfacesFile          = /etc/beegfs/${type}-connInterfacesFile.conf|g"  /etc/beegfs/beegfs-${type}.conf
  cat /etc/beegfs/beegfs-${type}.conf | grep "^connInterfacesFile"
  cat /etc/beegfs/${type}-connInterfacesFile.conf

  systemctl start beegfs-mgmtd ; systemctl status beegfs-mgmtd
  #systemctl enable beegfs-mgmtd

fi

