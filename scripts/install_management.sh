set -x


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
  vnic_cnt=`/root/secondary_vnic_all_configure.sh | grep "ocid1.vnic." | grep " UP " | wc -l` ; echo $vnic_cnt
  while ( [ $vnic_cnt -le 1 ] )
  do
    # give the infrastructure another 10 seconds to provide the metadata for the second vnic
    echo waiting for second NIC to come online
    sleep 10
    systemctl restart secondnic.service
    vnic_cnt=`/root/secondary_vnic_all_configure.sh | grep "ocid1.vnic." | grep " UP " | wc -l` ; echo $vnic_cnt
  done

}



#################
# Start of script
#################


# call function
configure_vnics

if [ "$management_high_availability" = "true" ]; then
  mgmt_host=${management_vip_private_ip}
  vnicId=`curl -s http://169.254.169.254/opc/v1/vnics/ | jq '.[1].vnicId' | sed 's/"//g' ` ; echo $vnicId
  /root/secondary_vnic_all_configure.sh -c -e $management_vip_private_ip $vnicId
else
  mgmt_host=${management_server_filesystem_vnic_hostname_prefix}1.${filesystem_subnet_domain_name}
fi



wget -O /etc/yum.repos.d/beegfs_rhel7.repo https://www.beegfs.io/release/latest-stable/dists/beegfs-rhel7.repo





# management service
yum install beegfs-mgmtd -y

# admon service (optional)
# yum install beegfs-admon -y
# yum install java -y

# Extract value "n" from any hostname like storage-server-n. n>=1
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

  # Set this values to make Management NodeID be not dependent on node hostname and thus allow to use the same settings on a different node for HA.
  # https://www.beegfs.io/wiki/FAQ#force_nodeid
#echo MGSHA > /data/mgt${count}/beegfs_mgmtd/nodeID
#  echo 1 > /data/mgt${count}/beegfs_mgmtd/nodeNumID
# echo MGT1 > /data/mgt${count}/beegfs_mgmtd/targetID
#  echo 1 > /data/mgt${count}/beegfs_mgmtd/targetNumID


  # Update beegfs files to use 2nd VNIC only, otherwise nodes will try 1st VNIC and then 2nd. It results in high latency.
  privateIp=`curl -s http://169.254.169.254/opc/v1/vnics/ | jq '.[1].privateIp ' | sed 's/"//g' ` ; echo $privateIp
  interface=`ip addr | grep -B2 $privateIp | grep "BROADCAST" | gawk -F ":" ' { print $2 } ' | sed -e 's/^[ \t]*//'` ; echo $interface
  type="mgmtd"
  cat /etc/beegfs/beegfs-${type}.conf | grep "^connInterfacesFile"
  echo "$interface" > /etc/beegfs/${type}-connInterfacesFile.conf
  sed -i "s|connInterfacesFile.*=.*|connInterfacesFile          = /etc/beegfs/${type}-connInterfacesFile.conf|g"  /etc/beegfs/beegfs-${type}.conf
  cat /etc/beegfs/beegfs-${type}.conf | grep "^connInterfacesFile"
  cat /etc/beegfs/${type}-connInterfacesFile.conf


# Start services.  They create log files here:  /var/log/beegfs-...
###if [ "$(hostname -s | tail -c 3)" = "-1" ]; then
  systemctl start beegfs-mgmtd ; systemctl status beegfs-mgmtd
#  systemctl enable beegfs-mgmtd
###fi

# cp /etc/beegfs/beegfs-admon.conf /etc/beegfs/beegfs-admon.conf.backup
# sed -i "s/sysMgmtdHost/sysMgmtdHost=${management_server_filesystem_vnic_hostname_prefix}1.${filesystem_subnet_domain_name}/g" /etc/beegfs/beegfs-admon.conf

#  systemctl start beegfs-admon
#  systemctl enable beegfs-admon

