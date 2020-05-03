
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




# Deploy components to implement HA for Management Service

LOCAL_NODE=`hostname`; echo $LOCAL_NODE
LOCAL_NODE_IP=`nslookup $LOCAL_NODE | grep "Address: " | grep -v "#" | gawk '{print $2}'` ; echo $LOCAL_NODE_IP
NODE1="${server_hostname_prefix}1" ; echo $NODE1
NODE2="${server_hostname_prefix}2" ; echo $NODE2
NODE1_IP=`nslookup $NODE1 | grep "Address: " | grep -v "#" | gawk '{print $2}'` ; echo $NODE1_IP
NODE2_IP=`nslookup $NODE2 | grep "Address: " | grep -v "#" | gawk '{print $2}'` ; echo $NODE2_IP
NODE1_FQDN="${server_hostname_prefix}1.${storage_subnet_domain_name}" ; echo $NODE1
NODE2_FQDN="${server_hostname_prefix}2.${storage_subnet_domain_name}" ; echo $NODE2
echo "$NODE1_IP $NODE1_FQDN $NODE1" >> /etc/hosts
echo "$NODE2_IP $NODE2_FQDN $NODE2" >> /etc/hosts
# VIRTUAL IP
TARGET_VIP=$management_vip_private_ip


# Call function to configure 2nd VNIC and 2nd Private IP address
configure_vnics
# Manually add VIP to Node1?
if [ "$LOCAL_NODE" = "$NODE1" ]; then
  vnicId=`curl -s http://169.254.169.254/opc/v1/vnics/ | jq '.[1].vnicId' | sed 's/"//g' ` ; echo $vnicId
  /root/secondary_vnic_all_configure.sh -c -e $management_vip_private_ip $vnicId
fi



echo "
LOCAL_NODE=\"${LOCAL_NODE}\"
LOCAL_NODE_IP=\"${LOCAL_NODE_IP}\"
NODE1=\"${NODE1}\"
NODE2=\"${NODE2}\"
NODE1_IP=\"${NODE1_IP}\"
NODE2_IP=\"${NODE2_IP}\"
NODE1_FQDN=\"${NODE1_FQDN}\"
NODE2_FQDN=\"${NODE2_FQDN}\"
TARGET_VIP=\"${TARGET_VIP}\"
management_high_availability=\"${management_high_availability}\"
management_vip_private_ip=\"${management_vip_private_ip}\"
management_server_filesystem_vnic_hostname_prefix=\"${management_server_filesystem_vnic_hostname_prefix}\"
filesystem_subnet_domain_name=\"${filesystem_subnet_domain_name}\"
server_node_count=\"${server_node_count}\"
server_hostname_prefix=\"${server_hostname_prefix}\"
disk_size=\"${disk_size}\"
disk_count=\"${disk_count}\"
storage_subnet_domain_name=\"${storage_subnet_domain_name}\"
vcn_domain_name=\"${vcn_domain_name}\"
hacluster_user_password=\"${hacluster_user_password}\"
" > /root/env_variables.sh


echo "source /root/env_variables.sh" >>  /root/.bash_profile

cp /etc/selinux/config /etc/selinux/config.backup
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
setenforce 0



# Wait for BVol attach to be completed, only if the shape is not DenseIO/BM.HPC2.36
nvme_lst=$(ls /dev/ | grep nvme | grep n1 | sort)
nvme_cnt=$(ls /dev/ | grep nvme | grep n1 | wc -l)
if [ $nvme_cnt -eq 0 ]; then
  # Wait for block-attach of the Block volumes to complete. Terraform then creates the below file on server nodes of cluster.
  while [ ! -f /tmp/block-attach.complete ]
  do
    sleep 60s
    echo "Waiting for block-attach via Terraform to  complete ..."
  done
fi


# Set a common password for hacluster user on the two nodes
echo -e "${hacluster_user_password}\n${hacluster_user_password}" | passwd hacluster

if [ $? -ne 0 ]; then
  echo "Setting password value of ${hacluster_user_password} for hacluster failed"
  exit 1;
fi


# copy ssh private key to both mgs nodes.
if [ "$LOCAL_NODE" = "$NODE1" ]; then
  corosync-keygen -l
  cp -av /etc/corosync/authkey /home/opc/authkey
  chown opc: /home/opc/authkey

  scp -i /home/opc/.ssh/id_rsa -o BatchMode=yes -o StrictHostkeyChecking=no -p -3 /home/opc/authkey opc@${NODE2_IP}:/home/opc/authkey

  #rm -f /home/opc/authkey
  # NODE2
  ssh -i /home/opc/.ssh/id_rsa -o BatchMode=yes -o StrictHostkeyChecking=no opc@${NODE2_IP} "sudo mv /home/opc/authkey /etc/corosync/authkey"
  while [ $? -ne 0 ]
  do
    echo "sleeping for 20s, so NODE2 can finish deploying corosync and required directories are in place....."
    sleep 20s
    ssh -i /home/opc/.ssh/id_rsa  -o BatchMode=yes -o StrictHostkeyChecking=no opc@${NODE2_IP} "sudo mv /home/opc/authkey /etc/corosync/authkey"
  done
  ssh -i /home/opc/.ssh/id_rsa  -o BatchMode=yes -o StrictHostkeyChecking=no opc@${NODE2_IP} "sudo chown root: /etc/corosync/authkey"
fi

cp /home/opc/config/corosync.conf /etc/corosync/
chown root: /etc/corosync/corosync.conf
sed -i "s/LOCAL_NODE_IP/${LOCAL_NODE_IP}/" /etc/corosync/corosync.conf
sed -i "s/NODE1/${NODE1}/" /etc/corosync/corosync.conf
sed -i "s/NODE2/${NODE2}/" /etc/corosync/corosync.conf

mv -vn /etc/drbd.d/global_common.conf /etc/drbd.d/global_common.conf.orig
cp -f /home/opc/config/global_common.conf  /etc/drbd.d/global_common.conf
chown root: /etc/drbd.d/global_common.conf

mkdir /etc/corosync/service.d/
cp -f /home/opc/config/pcmk /etc/corosync/service.d/pcmk
chown root: /etc/corosync/service.d/pcmk

mv -vn /etc/sysconfig/corosync /etc/sysconfig/corosync.orig
cp -f /home/opc/config/corosync  /etc/sysconfig/corosync
chown root: /etc/sysconfig/corosync

mkdir /var/log/corosync/
systemctl start corosync
ssh -i /home/opc/.ssh/id_rsa  -o BatchMode=yes -o StrictHostkeyChecking=no opc@${NODE2_IP}  'sudo systemctl status  corosync  | grep "(running)" ' ;
while ( [ $? -ne 0 ] )
do
  # give the infrastructure another 10 seconds to provide the metadata for the second vnic
  echo "waiting for corosync to come online on node2"
  sleep 10
  ssh -i /home/opc/.ssh/id_rsa  -o BatchMode=yes -o StrictHostkeyChecking=no opc@${NODE2_IP}  'sudo systemctl status  corosync  | grep "(running)" ' ;
done

corosync-cmapctl | grep members

cp /home/opc/config/drbd_cleanup.sh  /var/lib/pacemaker/drbd_cleanup.sh
chown root: /var/lib/pacemaker/drbd_cleanup.sh
chmod 0755 /var/lib/pacemaker/drbd_cleanup.sh
touch /var/log/pacemaker_drbd_file.log
chown hacluster:haclient /var/log/pacemaker_drbd_file.log


cp /home/opc/config/r0.res /etc/drbd.d/r0.res
chown root: /etc/drbd.d/r0.res
sed -i "s/NODE1_IP/${NODE1_IP}/" /etc/drbd.d/r0.res
sed -i "s/NODE2_IP/${NODE2_IP}/" /etc/drbd.d/r0.res

# Configuring PCSD
systemctl start pcsd.service
ssh -i /home/opc/.ssh/id_rsa  -o BatchMode=yes -o StrictHostkeyChecking=no opc@${NODE2_IP}  'sudo systemctl status  pcsd  | grep "(running)" ' ;
while ( [ $? -ne 0 ] )
do
  # give the infrastructure another 10 seconds to provide the metadata for the second vnic
  echo "waiting for pcsd.service to come online on node2"
  sleep 10
  ssh -i /home/opc/.ssh/id_rsa  -o BatchMode=yes -o StrictHostkeyChecking=no opc@${NODE2_IP}  'sudo systemctl status  pcsd  | grep "(running)" ' ;
done


if [ "$LOCAL_NODE" = "$NODE1" ]; then
  echo ${hacluster_user_password} | pcs cluster auth --name beegfs_mgs_cluster ${NODE1} ${NODE2} -u hacluster
fi

# Install OCI CLI, so we can use Instance Principal to move floating VIP from one node to another.
# Configuring OCI-CLI
mkdir /home/oracle-cli/
chown root: /home/oracle-cli/
chmod 755 /home/oracle-cli/
wget https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh
bash install.sh --accept-all-defaults --exec-dir /home/oracle-cli/bin/ --install-dir /home/oracle-cli/lib/
rm -f install.sh
rm -rf /root/bin/oci-cli-scripts
mkdir /home/oracle-cli/.oci
chown hacluster:haclient /home/oracle-cli/.oci
chmod 700 /home/oracle-cli/.oci
# Required - to ensure oci can be used in existing shell.
# source /root/.bash_profile
/home/oracle-cli/bin/oci os ns get --auth instance_principal
# https://docs.cloud.oracle.com/en-us/iaas/Content/Identity/Tasks/callingservicesfrominstances.htm#Configur


cp /home/opc/config/move_secip.sh /home/oracle-cli/move_secip.sh
chmod +x /home/oracle-cli/move_secip.sh
chmod 700 /home/oracle-cli/move_secip.sh
chown hacluster:haclient /home/oracle-cli/move_secip.sh


cp /home/opc/config/ip_move.sh   /var/lib/pacemaker/ip_move.sh
chown root: /var/lib/pacemaker/ip_move.sh
chmod 0755 /var/lib/pacemaker/ip_move.sh
touch /var/log/pacemaker_ip_move.log
chown hacluster:haclient /var/log/pacemaker_ip_move.log

cd /root;
if [ "$LOCAL_NODE" = "$NODE1" ]; then

  pcs cluster start --all
  sleep 10s
  pcs status
  # file will be created on node1 in /root folder - named: beegfs_cfg
  pcs cluster cib /root/beegfs_cfg
  pcs -f /root/beegfs_cfg property set stonith-enabled=false
  # In 2 nodes, there is no quorum. hence no-quorum-policy=ignore  instead of no-quorum-policy=stop
  pcs -f /root/beegfs_cfg property set no-quorum-policy=ignore
  pcs -f /root/beegfs_cfg resource defaults resource-stickiness=200
  pcs -f /root/beegfs_cfg resource defaults migration-threshold=1
# Add DRBD
  pcs -f /root/beegfs_cfg resource create beegfs_drbd ocf:linbit:drbd \
drbd_resource=r0 \
op monitor role=Master interval=29 timeout=20 \
op monitor role=Slave interval=31 timeout=20 \
op start timeout=120 \
op stop timeout=60
  pcs -f /root/beegfs_cfg resource master mgs_primary beegfs_drbd \
master-max=1 master-node-max=1 \
clone-max=2 clone-node-max=1 \
notify=true
# Add filesystem resource
  pcs -f /root/beegfs_cfg resource create mgt_fs Filesystem \
device="/dev/drbd0" \
directory="/data/mgt1" \
fstype="ext4"
# Add IPaddr2 resource
pcs -f /root/beegfs_cfg resource create mgs_VIP ocf:heartbeat:IPaddr2 ip=${TARGET_VIP} cidr_netmask=24 op monitor interval=20s
pcs -f /root/beegfs_cfg alert create id=ip_move description="Move IP address using oci-cli" path=/var/lib/pacemaker/ip_move.sh
pcs -f /root/beegfs_cfg alert recipient add ip_move id=logfile_ip_move value=/var/log/pacemaker_ip_move.log
# Add beegfs service
pcs -f /root/beegfs_cfg resource create beegfs_mgs_service systemd:beegfs-mgmtd.service
pcs -f /root/beegfs_cfg alert create id=drbd_cleanup_file description="Monitor DRBD events and perform post cleanup" path=/var/lib/pacemaker/drbd_cleanup.sh
pcs -f /root/beegfs_cfg alert recipient add drbd_cleanup_file id=logfile value=/var/log/pacemaker_drbd_file.log
# Add constraint
  pcs -f /root/beegfs_cfg constraint colocation add mgt_fs with mgs_primary INFINITY with-rsc-role=Master
  pcs -f /root/beegfs_cfg constraint order promote mgs_primary then start mgt_fs
  pcs -f /root/beegfs_cfg constraint colocation add beegfs_mgs_service with mgt_fs INFINITY
  pcs -f /root/beegfs_cfg constraint order mgt_fs then mgs_VIP
  pcs -f /root/beegfs_cfg constraint colocation add mgs_VIP with beegfs_mgs_service INFINITY
  pcs -f /root/beegfs_cfg constraint order mgs_VIP then beegfs_mgs_service
fi


# DRBD - rest of the config
mkfs.ext4 -m 0 -F -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/sdb
dd if=/dev/zero of=/dev/sdb bs=1k count=1024
drbdadm create-md r0
drbdadm up r0


wget -O /etc/yum.repos.d/beegfs_rhel7.repo https://www.beegfs.io/release/latest-stable/dists/beegfs-rhel7.repo
# management service
yum install beegfs-mgmtd -y

# create mount point directory on both nodes.
mkdir -p /data/mgt1
if [ "$LOCAL_NODE" = "$NODE1" ]; then
  drbdadm primary r0 --force
  drbdadm -- --overwrite-data-of-peer primary r0
  mkfs.ext4 -m 0 -F -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/drbd0
  mount -o defaults /dev/drbd0 /data/mgt1

  # always assume Bvol sdb. leave nvme code in place for future.
  # no mounting
  # no fstab
  mkdir -p /data/mgt1/beegfs_mgmtd

  # only on node1 -  node 2 will get these changes as part of drbd
  /opt/beegfs/sbin/beegfs-setup-mgmtd -p /data/mgt1/beegfs_mgmtd

  echo MGSHA > /data/mgt1/beegfs_mgmtd/nodeID
  echo 1 > /data/mgt1/beegfs_mgmtd/nodeNumID
  echo MGT1 > /data/mgt1/beegfs_mgmtd/targetID
  echo 1 > /data/mgt1/beegfs_mgmtd/targetNumID

  # Run on node1 only
  # Update beegfs files to use 2nd VNIC only, otherwise nodes will try 1st VNIC and then 2nd. It results in high latency.
  privateIp=`curl -s http://169.254.169.254/opc/v1/vnics/ | jq '.[1].privateIp ' | sed 's/"//g' ` ; echo $privateIp
  interface=`ip addr | grep -B2 $privateIp | grep "BROADCAST" | gawk -F ":" ' { print $2 } ' | sed -e 's/^[ \t]*//'` ; echo $interface
  type="mgmtd"
  cat /etc/beegfs/beegfs-${type}.conf | grep "^connInterfacesFile"
  echo "$interface" > /etc/beegfs/${type}-connInterfacesFile.conf
  sed -i "s|connInterfacesFile.*=.*|connInterfacesFile          = /etc/beegfs/${type}-connInterfacesFile.conf|g"  /etc/beegfs/beegfs-${type}.conf
  cat /etc/beegfs/beegfs-${type}.conf | grep "^connInterfacesFile"
  cat /etc/beegfs/${type}-connInterfacesFile.conf

fi

# Copy files to node2
cp /etc/beegfs/beegfs-${type}.conf /home/opc/
scp -i /home/opc/.ssh/id_rsa -o BatchMode=yes -o StrictHostkeyChecking=no -p -3 /home/opc/beegfs-${type}.conf opc@${NODE2_IP}:/home/opc/beegfs-${type}.conf
ssh -i /home/opc/.ssh/id_rsa -o BatchMode=yes -o StrictHostkeyChecking=no opc@${NODE2_IP} "sudo mv /home/opc/beegfs-${type}.conf /etc/beegfs/beegfs-${type}.conf"
ssh -i /home/opc/.ssh/id_rsa  -o BatchMode=yes -o StrictHostkeyChecking=no opc@${NODE2_IP} "sudo chown root: /etc/beegfs/beegfs-${type}.conf"

cp /etc/beegfs/${type}-connInterfacesFile.conf /home/opc/
scp -i /home/opc/.ssh/id_rsa -o BatchMode=yes -o StrictHostkeyChecking=no -p -3 /home/opc/${type}-connInterfacesFile.conf opc@${NODE2_IP}:/home/opc/${type}-connInterfacesFile.conf
ssh -i /home/opc/.ssh/id_rsa -o BatchMode=yes -o StrictHostkeyChecking=no opc@${NODE2_IP} "sudo mv /home/opc/${type}-connInterfacesFile.conf /etc/beegfs/${type}-connInterfacesFile.conf"
ssh -i /home/opc/.ssh/id_rsa  -o BatchMode=yes -o StrictHostkeyChecking=no opc@${NODE2_IP} "sudo chown root: /etc/beegfs/${type}-connInterfacesFile.conf"


systemctl disable  beegfs-mgmtd.service

systemctl enable pcsd;
systemctl enable pacemaker;
systemctl enable corosync;

# Now push the configuration so it becomes active on the pcs cluster.
if [ "$LOCAL_NODE" = "$NODE1" ]; then
  pcs cluster cib-push /root/beegfs_cfg
fi
sleep 5s

pcs status

# Only PCS is expected to manage and control the services.  If you manually start or stop them, it will start on the other node, provided there were no pending errors on that node from previous run.  So it there is a section like below in "pcs status", it means something went wrong last time service was ran on that node and if the errors are display, it means either those issues were not fixed or they were fixed but admin forgot to run the command "pcs resource cleanup <service_name>".
##  Failed Resource Actions:
##  * beegfs_mgs_service_monitor_60000 on mgs-server-2 'not running' (7): call=89, status=complete, exitreason='',
##  last-rc-change='Sat May  2 09:38:40 2020', queued=0ms, exec=0ms
##  * beegfs_mgs_service_monitor_60000 on mgs-server-1 'not running' (7): call=62, status=complete, exitreason='',
##  last-rc-change='Sat May  2 09:29:36 2020', queued=0ms, exec=0ms
######  pcs resource cleanup beegfs_mgs_service


exit 0
