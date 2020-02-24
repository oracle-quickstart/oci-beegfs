set -x

echo "storage_server_dual_nics=\"${storage_server_dual_nics}\"" >> /tmp/env_variables.sh


wget -O /etc/yum.repos.d/beegfs_rhel7.repo https://www.beegfs.io/release/latest-stable/dists/beegfs-rhel7.repo


# storage service; libbeegfs-ib is only required for RDMA
#yum install beegfs-storage libbeegfs-ib -y
yum install beegfs-storage -y



nvme_lst=$(ls /dev/ | grep nvme | grep n1 | sort)
nvme_cnt=$(ls /dev/ | grep nvme | grep n1 | wc -l)

# Extract value "n" from any hostname like storage-server-n
num=`hostname | gawk -F"." '{ print $1 }' | gawk -F"-"  'NF>1&&$0=$(NF)'`
id=$num

count=1
# Create XFS directly on the block. No need for pvcreate/LVM, etc.
for disk in $nvme_lst
do
    mkfs.xfs /dev/$disk
    mkdir -p /data/ost${count}
    mount -t xfs -o noatime,inode64,nobarrier /dev/$disk /data/ost${count}
    mkdir -p /data/ost${count}/beegfs_storage
    /opt/beegfs/sbin/beegfs-setup-storage -p /data/ost${count}/beegfs_storage -s $id -i ${id}${count} -m ${management_server_filesystem_vnic_hostname_prefix}1.${filesystem_subnet_domain_name}
    count=$((count+1))
done


if [ $nvme_cnt -eq 0 ]; then

# Wait for block-attach of the Block volumes to complete. Terraform then creates the below file on server nodes of cluster.
while [ ! -f /tmp/block-attach.complete ]
do
  sleep 60s
  echo "Waiting for block-attach via Terraform to  complete ..."
done


# Gather list of block devices for brick config
blk_lst=$(lsblk -d --noheadings | grep -v sda | awk '{ print $1 }' | sort)
blk_cnt=$(lsblk -d --noheadings | grep -v sda | wc -l)

# Extract value "n" from any hostname like storage-server-n
num=`hostname | gawk -F"." '{ print $1 }' | gawk -F"-"  'NF>1&&$0=$(NF)'`
id=$num

count=1
# Create XFS directly on the block. No need for pvcreate/LVM, etc.
for disk in $blk_lst
do
    mkfs.xfs /dev/$disk
    mkdir -p /data/ost${count}
    mount -t xfs -o noatime,inode64,nobarrier /dev/$disk /data/ost${count}
    mkdir -p /data/ost${count}/beegfs_storage
    /opt/beegfs/sbin/beegfs-setup-storage -p /data/ost${count}/beegfs_storage -s $id -i ${id}${count} -m ${management_server_filesystem_vnic_hostname_prefix}1.${filesystem_subnet_domain_name}
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
   echo waiting for second NIC to come online
   sleep 10
done


# Start services.  They create log files here:  /var/log/beegfs-...
systemctl start beegfs-storage

# Retry until successful. It retries until all dependent server nodes and their services/deamons are up and ready to connect
( while !( systemctl restart beegfs-storage )
do
   # This ensures, all dependent services are up, until then retry
   echo waiting for beegfs-storage to come online
   sleep 10
done ) &
