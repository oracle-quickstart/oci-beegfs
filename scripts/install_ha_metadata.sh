SSH_OPTIONS=" -i /home/opc/.ssh/id_rsa -o BatchMode=yes -o StrictHostkeyChecking=no "
MDATA_VNIC_URL="http://169.254.169.254/opc/v1/vnics/"
TYPE_VIP="mds_VIP"

##wget -O /etc/yum.repos.d/beegfs_rhel7.repo https://www.beegfs.io/release/latest-stable/dists/beegfs-rhel7.repo
# management service
##yum install beegfs-meta -y
install_beegfs "meta"

if [ "$management_high_availability" = "true" ]; then
  mgmt_host=${management_vip_private_ip}
else
  mgmt_host=${management_server_filesystem_vnic_hostname_prefix}1.${filesystem_subnet_domain_name}
fi

# Call function to configure 2nd VNIC
configure_vnics

if [ "$metadata_high_availability" = "true" ]; then
    # Deploy components to implement HA for Metadata Service

    LOCAL_NODE=`hostname`;
    NODE1_INDEX=""
    NODE2_INDEX=""
    index="-1"
    index=`echo $LOCAL_NODE | gawk -F"$server_hostname_prefix" ' { print $2 } ' `
    echo $index

    if [ $((index % 2))  -eq 0 ] ; then
      echo even
      NODE1_INDEX=$((index-1))
      NODE2_INDEX=$index
    else
      echo odd
      NODE1_INDEX=$index
      NODE2_INDEX=$((index+1))
    fi

    LOCAL_NODE_IP=`nslookup $LOCAL_NODE | grep "Address: " | grep -v "#" | gawk '{print $2}'` ;
    NODE1="${server_hostname_prefix}${NODE1_INDEX}" ;
    NODE2="${server_hostname_prefix}${NODE2_INDEX}" ;
    NODE1_IP=`nslookup $NODE1 | grep "Address: " | grep -v "#" | gawk '{print $2}'` ;
    NODE2_IP=`nslookup $NODE2 | grep "Address: " | grep -v "#" | gawk '{print $2}'` ;
    NODE1_FQDN="${NODE1}.${storage_subnet_domain_name}" ;
    NODE2_FQDN="${NODE2}.${storage_subnet_domain_name}" ;
    echo "$NODE1_IP $NODE1_FQDN $NODE1" >> /etc/hosts
    echo "$NODE2_IP $NODE2_FQDN $NODE2" >> /etc/hosts
    # VIRTUAL IP
    TARGET_VIP=$metadata_vip_private_ip




    if [ "$LOCAL_NODE" = "$NODE1" ]; then

      node1vnic=`curl -s $MDATA_VNIC_URL | jq '.[1].vnicId' | sed 's/"//g' ` ;

      ssh ${SSH_OPTIONS}  opc@${NODE2_IP} "ls -l /home/opc/.ssh/id_rsa"
      while [ $? -ne 0 ]
      do
        echo "wait for TF scripts to copy ssh keys..."
        sleep 5s
        ssh ${SSH_OPTIONS}  opc@${NODE2_IP} "ls -l /home/opc/.ssh/id_rsa"
      done

      node2vnic_w_quotes=`ssh ${SSH_OPTIONS} opc@${NODE2_IP} "curl -s $MDATA_VNIC_URL | jq '.[1].vnicId'  "` ;
      node2vnic=`echo $node2vnic_w_quotes |  sed 's/"//g' ` ;
    else
      # SWAP logic, since its node2 here.
      node2vnic=`curl -s $MDATA_VNIC_URL | jq '.[1].vnicId' | sed 's/"//g' ` ;

      ssh ${SSH_OPTIONS}  opc@${NODE1_IP} "ls -l /home/opc/.ssh/id_rsa"
      while [ $? -ne 0 ]
      do
        echo "wait for TF scripts to copy ssh keys..."
        sleep 5s
        ssh ${SSH_OPTIONS}  opc@${NODE1_IP} "ls -l /home/opc/.ssh/id_rsa"
      done

      node1vnic_w_quotes=`ssh ${SSH_OPTIONS} opc@${NODE1_IP} "curl -s $MDATA_VNIC_URL | jq '.[1].vnicId'  "` ;
      node1vnic=`echo $node1vnic_w_quotes |  sed 's/"//g' ` ;
    fi
    subnetCidrBlock=`curl -s $MDATA_VNIC_URL | jq '.[1].subnetCidrBlock  ' | sed 's/"//g' ` ;
    cidr_netmask=`echo $subnetCidrBlock | gawk -F"/" '{ print $2 }'` ;


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
    metadata_high_availability=\"${metadata_high_availability}\"
    metadata_vip_private_ip=\"${metadata_vip_private_ip}\"
    management_server_filesystem_vnic_hostname_prefix=\"${management_server_filesystem_vnic_hostname_prefix}\"
    filesystem_subnet_domain_name=\"${filesystem_subnet_domain_name}\"
    server_node_count=\"${server_node_count}\"
    server_hostname_prefix=\"${server_hostname_prefix}\"
    disk_size=\"${disk_size}\"
    disk_count=\"${disk_count}\"
    storage_subnet_domain_name=\"${storage_subnet_domain_name}\"
    vcn_domain_name=\"${vcn_domain_name}\"
    hacluster_user_password=\"${hacluster_user_password}\"
    node1vnic=\"${node1vnic}\"
    node2vnic=\"${node2vnic}\"
    subnetCidrBlock=\"${subnetCidrBlock}\"
    cidr_netmask=\"${cidr_netmask}\"
    metadata_use_shared_disk=\"${metadata_use_shared_disk}\"
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

    # Set password for hacluster user on both nodes
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

      scp ${SSH_OPTIONS}  -p -3 /home/opc/authkey opc@${NODE2_IP}:/home/opc/authkey

      ssh ${SSH_OPTIONS}  opc@${NODE2_IP} "sudo mv /home/opc/authkey /etc/corosync/authkey"
      while [ $? -ne 0 ]
      do
        echo "sleeping for 20s, so NODE2 can finish deploying corosync and create directories....."
        sleep 20s
        ssh ${SSH_OPTIONS} opc@${NODE2_IP} "sudo mv /home/opc/authkey /etc/corosync/authkey"
      done
      ssh ${SSH_OPTIONS} opc@${NODE2_IP} "sudo chown root: /etc/corosync/authkey"
      rm -f /home/opc/authkey
    fi

    cp /home/opc/config/corosync.conf /etc/corosync/
    chown root: /etc/corosync/corosync.conf
    sed -i "s/LOCAL_NODE_IP/${LOCAL_NODE_IP}/" /etc/corosync/corosync.conf
    sed -i "s/NODE1/${NODE1}/" /etc/corosync/corosync.conf
    sed -i "s/NODE2/${NODE2}/" /etc/corosync/corosync.conf


    mkdir /etc/corosync/service.d/
    cp -f /home/opc/config/pcmk /etc/corosync/service.d/pcmk
    chown root: /etc/corosync/service.d/pcmk

    mv -vn /etc/sysconfig/corosync /etc/sysconfig/corosync.orig
    cp -f /home/opc/config/corosync  /etc/sysconfig/corosync
    chown root: /etc/sysconfig/corosync

    mkdir /var/log/corosync/
    # Primary reason for this while loop, is to ensure node2 get the authkey file from node1. Until then, Node2 should not start corosync service.
    if [ "$LOCAL_NODE" = "$NODE2" ]; then
      while ( ! [ -f /etc/corosync/authkey ] )
      do
        echo "wait for /etc/corosync/authkey to get transfer from node1"
        sleep 5s
      done
    fi

    systemctl start corosync
    if [ "$LOCAL_NODE" = "$NODE1" ]; then
      ssh ${SSH_OPTIONS} opc@${NODE2_IP}  'sudo systemctl status  corosync  | grep "(running)" ' ;
      while ( [ $? -ne 0 ] )
      do
        echo "waiting for corosync to come online on node2"
        sleep 10
        ssh ${SSH_OPTIONS} opc@${NODE2_IP}  'sudo systemctl status  corosync  | grep "(running)" ' ;
      done
    fi

    corosync-cmapctl | grep members


    # Configuring PCSD
    systemctl start pcsd.service
    if [ "$LOCAL_NODE" = "$NODE1" ]; then
      ssh ${SSH_OPTIONS} opc@${NODE2_IP}  'sudo systemctl status  pcsd  | grep "(running)" ' ;
      while ( [ $? -ne 0 ] )
      do
        echo "waiting for pcsd.service to come online on node2"
        sleep 10
        ssh ${SSH_OPTIONS} opc@${NODE2_IP}  'sudo systemctl status  pcsd  | grep "(running)" ' ;
      done
    fi

    if [ "$LOCAL_NODE" = "$NODE1" ]; then
      echo ${hacluster_user_password} | pcs cluster auth --name beegfs_mds_cluster ${NODE1} ${NODE2} -u hacluster
    fi

    # use Instance Principal for auth
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
    /home/oracle-cli/bin/oci os ns get --auth instance_principal

    cp /home/opc/config/move_secip.sh /home/oracle-cli/move_secip.sh
    chmod +x /home/oracle-cli/move_secip.sh
    chmod 700 /home/oracle-cli/move_secip.sh
    chown hacluster:haclient /home/oracle-cli/move_secip.sh
    cp -f /root/env_variables.sh /home/oracle-cli/
    chown hacluster:haclient /home/oracle-cli/env_variables.sh

    cp /home/opc/config/ip_move.sh   /var/lib/pacemaker/ip_move.sh
    chown root: /var/lib/pacemaker/ip_move.sh
    chmod 0755 /var/lib/pacemaker/ip_move.sh
    sed -i "s|TYPE_VIP|${TYPE_VIP}|g" /var/lib/pacemaker/ip_move.sh
    touch /var/log/pacemaker_ip_move.log
    chown hacluster:haclient /var/log/pacemaker_ip_move.log

    cd /root;
    if [ "$LOCAL_NODE" = "$NODE1" ]; then


    pcs_group_parameter=" --group mdsgroup"

      pcs cluster start --all
      sleep 10s
      pcs status
      pcs cluster cib /root/beegfs_mds_cfg
      pcs -f /root/beegfs_mds_cfg property set stonith-enabled=false
      # In 2 nodes, there is no quorum. hence no-quorum-policy=ignore  instead of no-quorum-policy=stop
      pcs -f /root/beegfs_mds_cfg property set no-quorum-policy=ignore
      pcs -f /root/beegfs_mds_cfg resource defaults resource-stickiness=100
      pcs -f /root/beegfs_mds_cfg resource defaults migration-threshold=1


      pcs -f /root/beegfs_mds_cfg resource create mdt_fs Filesystem \
      device="/dev/oracleoci/oraclevdb" \
      directory="/data/mdt1" \
      fstype="ext4" \
      options="noatime,nodiratime,user_xattr" \
      $pcs_group_parameter


    pcs -f /root/beegfs_mds_cfg resource create beegfs_mds_service systemd:beegfs-meta.service \
    op monitor interval=15s  \
    op start timeout=120 \
    op stop timeout=60 \
    $pcs_group_parameter

    pcs -f /root/beegfs_mds_cfg resource create mds_VIP ocf:heartbeat:IPaddr2 ip=${TARGET_VIP} cidr_netmask=${cidr_netmask} op monitor interval=20s $pcs_group_parameter

    pcs -f /root/beegfs_mds_cfg alert create id=ip_move description="Move IP address using oci-cli" path=/var/lib/pacemaker/ip_move.sh
    pcs -f /root/beegfs_mds_cfg alert recipient add ip_move id=logfile_ip_move value=/var/log/pacemaker_ip_move.log



      pcs -f /root/beegfs_mds_cfg constraint colocation add beegfs_mds_service with mdt_fs INFINITY
      # Result in service working only with non VIP IP on port 8005, hence removed below line.
      # pcs -f /root/beegfs_mds_cfg constraint order mdt_fs then mds_VIP
      pcs -f /root/beegfs_mds_cfg constraint order mdt_fs then beegfs_mds_service
      pcs -f /root/beegfs_mds_cfg constraint colocation add mds_VIP with beegfs_mds_service INFINITY
      # Result in service working only with non VIP IP on port 8005, hence removed below line.
      # pcs -f /root/beegfs_mds_cfg constraint order mds_VIP then beegfs_mds_service
      pcs -f /root/beegfs_mds_cfg constraint order beegfs_mds_service then mds_VIP
    # end of if loop node = node1
    fi



    # create mount point directory.
    if [ "$LOCAL_NODE" = "$NODE1" ]; then

      block_size=4
      stride=$((block_size*1024/4096)) ;
      stripe_width=$((stride*1)) ;


  blk_lst=$(ls /dev/oracleoci/oraclevd* | egrep -v "oraclevda$|oraclevda1$|oraclevda2$|oraclevda3$" | sort) ; echo $blk_lst
  # /dev/oracleoci/oraclevdb /dev/oracleoci/oraclevdc /dev/oracleoci/oraclevdd
  blk_cnt=$(ls /dev/oracleoci/oraclevd* | egrep -v "oraclevda$|oraclevda1$|oraclevda2$|oraclevda3$" | wc -l); echo $blk_cnt



  mdt_count=1
  # Extract value "n" from any hostname like storage-server-n
  num=`hostname | gawk -F"." '{ print $1 }' | gawk -F"-"  'NF>1&&$0=$(NF)'`
  id=$num
  count=1

    for disk in $blk_lst
    do

    device_name="$disk"
    mkfs.ext4 -m 0 -F -i 2048 -I 512 -J size=400 -Odir_index,filetype -E lazy_itable_init=0,lazy_journal_init=0,stride=${stride},stripe_width=${stripe_width},discard -F $device_name
    mkdir -p /data/mdt${mdt_count}
    mount -onoatime,nodiratime,user_xattr $device_name /data/mdt${mdt_count}
    mkdir -p /data/mdt${mdt_count}/beegfs_meta

    /opt/beegfs/sbin/beegfs-setup-meta -p /data/mdt${mdt_count}/beegfs_meta  -s $id -m ${mgmt_host}


#    echo "MDS${id}HA" > /data/ost${ost_count}/beegfs_storage/nodeID
#    echo "${id}" > /data/ost${ost_count}/beegfs_storage/nodeNumID
#    echo "OST${ost_count}" > /data/ost${ost_count}/beegfs_storage/targetID
#    echo "${ost_count}" > /data/ost${ost_count}/beegfs_storage/targetNumID

echo "MDS${id}HA" > /data/mdt${mdt_count}/beegfs_meta/nodeID
echo "${id}" > /data/mdt${mdt_count}/beegfs_meta/nodeNumID
echo "${id}MDT${mdt_count}" > /data/mdt${mdt_count}/beegfs_meta/targetID
echo "${id}${mdt_count}" > /data/mdt${mdt_count}/beegfs_meta/targetNumID

    count=$((count+1))
    mdt_count=$((mdt_count+1))

    done




#      device_name="/dev/oracleoci/oraclevdb"

#      mkfs.ext4 -m 0 -F -i 2048 -I 512 -J size=400 -Odir_index,filetype -E lazy_itable_init=0,lazy_journal_init=0,stride=${stride},stripe_width=${stripe_width},discard -F $device_name
#      mount -onoatime,nodiratime,user_xattr $device_name /data/mdt1

#      mkdir -p /data/mdt1/beegfs_meta
#      id=1
#      /opt/beegfs/sbin/beegfs-setup-meta -p /data/mdt1/beegfs_meta  -s $id -m ${mgmt_host}

#      echo MDSHA > /data/mdt1/beegfs_meta/nodeID
#      echo 1 > /data/mdt1/beegfs_meta/nodeNumID
#      echo MDT1 > /data/mdt1/beegfs_meta/targetID
#      echo 1 > /data/mdt1/beegfs_meta/targetNumID

      # use 2nd VNIC interface
      privateIp=`curl -s $MDATA_VNIC_URL | jq '.[1].privateIp ' | sed 's/"//g' ` ;
      interface=`ip addr | grep -B2 $privateIp | grep "BROADCAST" | gawk -F ":" ' { print $2 } ' | sed -e 's/^[ \t]*//'` ;
      type="meta"
      echo "$interface" > /etc/beegfs/${type}-connInterfacesFile.conf
      sed -i "s|connInterfacesFile.*=.*|connInterfacesFile          = /etc/beegfs/${type}-connInterfacesFile.conf|g"  /etc/beegfs/beegfs-${type}.conf

      conf_file="/etc/beegfs/beegfs-${type}.conf"
      sed -i 's/tuneNumWorkers.*= 0/tuneNumWorkers               = 64/g'  ${conf_file}
      sed -i 's/connMaxInternodeNum.*= 32/connMaxInternodeNum          = 32/g'  ${conf_file}
      sed -i 's/storeAllowFirstRunInit.*= false/storeAllowFirstRunInit       = true/g'  ${conf_file}

      # Copy files to node2
      echo y | cp  /etc/beegfs/beegfs-${type}.conf /home/opc/
      scp ${SSH_OPTIONS} -p -3 /home/opc/beegfs-${type}.conf opc@${NODE2_IP}:/home/opc/beegfs-${type}.conf
      ssh ${SSH_OPTIONS} opc@${NODE2_IP} "sudo mv /home/opc/beegfs-${type}.conf /etc/beegfs/beegfs-${type}.conf"
      ssh ${SSH_OPTIONS} opc@${NODE2_IP} "sudo chown root: /etc/beegfs/beegfs-${type}.conf"

      echo y | cp  /etc/beegfs/${type}-connInterfacesFile.conf /home/opc/
      scp ${SSH_OPTIONS}  -p -3 /home/opc/${type}-connInterfacesFile.conf opc@${NODE2_IP}:/home/opc/${type}-connInterfacesFile.conf
      ssh ${SSH_OPTIONS}  opc@${NODE2_IP} "sudo mv /home/opc/${type}-connInterfacesFile.conf /etc/beegfs/${type}-connInterfacesFile.conf"
      ssh ${SSH_OPTIONS} opc@${NODE2_IP} "sudo chown root: /etc/beegfs/${type}-connInterfacesFile.conf"

  else
    blk_cnt=$(ls /dev/oracleoci/oraclevd* | egrep -v "oraclevda$|oraclevda1$|oraclevda2$|oraclevda3$" | wc -l); echo $blk_cnt
    ct=1;
    while [ $ct -le $blk_cnt ] ; do echo $ct ; mkdir -p /data/mdt${ct} ; ct=$((ct+1)) ;  done ;
  fi


    systemctl disable  beegfs-meta.service

    systemctl enable pcsd;
    systemctl enable pacemaker;
    systemctl enable corosync;

    # Now push the configuration so it becomes active.
    if [ "$LOCAL_NODE" = "$NODE1" ]; then
      pcs cluster cib-push /root/beegfs_mds_cfg
      sleep 5s
    else
      # for node1 to finish the configuration
      sleep 30s
    fi
    pcs status

    #  pcs resource cleanup beegfs_mds_service
    
fi

