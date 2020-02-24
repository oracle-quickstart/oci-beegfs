set -x

echo "storage_server_dual_nics=\"${storage_server_dual_nics}\"" >> /tmp/env_variables.sh


wget -O /etc/yum.repos.d/beegfs_rhel7.repo https://www.beegfs.io/release/latest-stable/dists/beegfs-rhel7.repo

# management service
yum install beegfs-mgmtd -y

# admon service (optional)
yum install beegfs-admon -y
yum install java -y

chunk_size=${block_size}; chunk_size_tmp=`echo $chunk_size | gawk -F"K" ' { print $1 }'` ;
echo $chunk_size_tmp;


nvme_lst=$(ls /dev/ | grep nvme | grep n1 | sort)
nvme_cnt=$(ls /dev/ | grep nvme | grep n1 | wc -l)

disk_list=""
for disk in $nvme_lst
do
  disk_list="$disk_list /dev/$disk"
done
echo "disk_list=$disk_list"
raid_device_count=$nvme_cnt
raid_device_name="md0"
mdadm --create md0 --level=0 --chunk=$chunk_size --raid-devices=$nvme_cnt $disk_list


# Extract value "n" from any hostname like storage-server-n. n>=1
num=`hostname | gawk -F"." '{ print $1 }' | gawk -F"-"  'NF>1&&$0=$(NF)'`
id=$num
count=1

mkfs.xfs -d su=${block_size},sw=$nvme_cnt -l version=2,su=${block_size} /dev/md0
mkdir -p /data/mgt${count}
    mount -t xfs -o noatime,inode64,nobarrier /dev/md0 /data/mgt${count}
    mkdir -p /data/mgt${count}/beegfs_mgmtd
    /opt/beegfs/sbin/beegfs-setup-mgmtd -p /data/mgt${count}/beegfs_mgmtd


if [ $nvme_cnt -eq 0 ]; then


# Wait for block-attach of the Block volumes to complete. Terraform then creates the below file on server nodes of cluster.
while [ ! -f /tmp/block-attach.complete ]
do
  sleep 60s
  echo "Waiting for block-attach via Terraform to  complete ..."
done


# Gather list of block devices for setup
blk_lst=$(lsblk -d --noheadings | grep -v sda | awk '{ print $1 }' | sort)
blk_cnt=$(lsblk -d --noheadings | grep -v sda | wc -l)

count=1
for disk in $blk_lst
do
    mkfs.xfs /dev/$disk
    mkdir -p /data/mgt${count}
    mount -t xfs -o noatime,inode64,nobarrier /dev/$disk /data/mgt${count}
    mkdir -p /data/mgt${count}/beegfs_mgmtd
    /opt/beegfs/sbin/beegfs-setup-mgmtd -p /data/mgt${count}/beegfs_mgmtd
    count=$((count+1))
done

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
   echo waiting for second NIC to come online >> $logfile
   sleep 10
done


# Start services.  They create log files here:  /var/log/beegfs-...
systemctl start beegfs-mgmtd

cp /etc/beegfs/beegfs-admon.conf /etc/beegfs/beegfs-admon.conf.backup
sed -i "s/sysMgmtdHost/sysMgmtdHost=${management_server_filesystem_vnic_hostname_prefix}1.${filesystem_subnet_domain_name}/g" /etc/beegfs/beegfs-admon.conf

systemctl start beegfs-admon

