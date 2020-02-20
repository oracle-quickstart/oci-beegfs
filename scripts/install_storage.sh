set -x

echo "storage_server_dual_nics=\"${storage_server_dual_nics}\"" >> /tmp/env_variables.sh


wget -O /etc/yum.repos.d/beegfs_rhel7.repo https://www.beegfs.io/release/latest-stable/dists/beegfs-rhel7.repo
cp beegfs-rhel7.repo /etc/yum.repos.d/


# storage service; libbeegfs-ib is only required for RDMA
#yum install beegfs-storage libbeegfs-ib -y
yum install beegfs-storage -y



mkdir -p /data
mkdir -p /data/mnt/myraid1/beegfs_storage
/opt/beegfs/sbin/beegfs-setup-storage -p /data/mnt/myraid1/beegfs_storage -s 3 -i 301 -m ${management_server_filesystem_vnic_hostname_prefix}1.${filesystem_subnet_domain_name}

#To add a second storage target on this same machine:
mkdir -p /data/mnt/myraid2/beegfs_storage
/opt/beegfs/sbin/beegfs-setup-storage -p /data/mnt/myraid2/beegfs_storage -s 3 -i 302


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
systemctl start beegfs-helperd


