set -x

echo "storage_server_dual_nics=\"${storage_server_dual_nics}\"" >> /tmp/env_variables.sh


wget -O /etc/yum.repos.d/beegfs_rhel7.repo https://www.beegfs.io/release/latest-stable/dists/beegfs-rhel7.repo
cp beegfs-rhel7.repo /etc/yum.repos.d/


# client and command-line utils
yum install beegfs-client beegfs-helperd beegfs-utils -y



# client
/opt/beegfs/sbin/beegfs-setup-client -m ${management_server_filesystem_vnic_hostname_prefix}1.${filesystem_subnet_domain_name}

# Start services.  They create log files here:  /var/log/beegfs-...
systemctl start beegfs-client


