SSH_OPTIONS=" -i /home/opc/.ssh/id_rsa -o BatchMode=yes -o StrictHostkeyChecking=no "
MDATA_VNIC_URL="http://169.254.169.254/opc/v1/vnics/"
TYPE_VIP="mgs_VIP"


if [ "$management_high_availability" = "true" ]; then
    # Deploy components to implement HA for Management Service

    LOCAL_NODE=`hostname`;
    LOCAL_NODE_IP=`nslookup $LOCAL_NODE | grep "Address: " | grep -v "#" | gawk '{print $2}'` ;
    NODE1="${server_hostname_prefix}1" ;
    NODE2="${server_hostname_prefix}2" ;
    NODE1_IP=`nslookup $NODE1 | grep "Address: " | grep -v "#" | gawk '{print $2}'` ;
    NODE2_IP=`nslookup $NODE2 | grep "Address: " | grep -v "#" | gawk '{print $2}'` ;
    NODE1_FQDN="${server_hostname_prefix}1.${storage_subnet_domain_name}" ;
    NODE2_FQDN="${server_hostname_prefix}2.${storage_subnet_domain_name}" ;
    echo "$NODE1_IP $NODE1_FQDN $NODE1" >> /etc/hosts
    echo "$NODE2_IP $NODE2_FQDN $NODE2" >> /etc/hosts
    # VIRTUAL IP
    TARGET_VIP=$management_vip_private_ip

    QUORUM=$quorum_hostname
    QUORUM_IP=`nslookup $QUORUM | grep "Address: " | grep -v "#" | gawk '{print $2}'`
    QUORUM_FQDN="${QUORUM}.${storage_subnet_domain_name}" ;
    echo "$QUORUM_IP $QUORUM_FQDN $QUORUM" >> /etc/hosts


    # Call function to configure 2nd VNIC
    configure_vnics
    if [ "$LOCAL_NODE" = "$NODE1" ]; then

      node1vnic=`curl -s $MDATA_VNIC_URL | jq '.[1].vnicId' | sed 's/"//g' `

      ssh ${SSH_OPTIONS} opc@${NODE2_IP} "ls -l /home/opc/.ssh/id_rsa"
      while [ $? -ne 0 ]
      do
        echo "wait for TF scripts to copy ssh keys to the nodes...sleeping"
        sleep 5s
        ssh ${SSH_OPTIONS} opc@${NODE2_IP} "ls -l /home/opc/.ssh/id_rsa"
      done

      node2vnic_w_quotes=`ssh ${SSH_OPTIONS} opc@${NODE2_IP} "curl -s $MDATA_VNIC_URL | jq '.[1].vnicId'  "` ;
      node2vnic=`echo $node2vnic_w_quotes |  sed 's/"//g' `
    else
      # SWAP logic, since its node2 here.
      node2vnic=`curl -s $MDATA_VNIC_URL | jq '.[1].vnicId' | sed 's/"//g' `

      ssh ${SSH_OPTIONS} opc@${NODE1_IP} "ls -l /home/opc/.ssh/id_rsa"
      while [ $? -ne 0 ]
      do
        echo "wait for TF scripts to copy ssh keys to the nodes...sleeping"
        sleep 5s
        ssh ${SSH_OPTIONS} opc@${NODE1_IP} "ls -l /home/opc/.ssh/id_rsa"
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
QUORUM=\"${QUORUM}\"
QUORUM_IP=\"${QUORUM_IP}\"
QUORUM_FQDN=\"${QUORUM_FQDN}\"
    " > /root/env_variables.sh


    echo "source /root/env_variables.sh" >>  /root/.bash_profile

    cp /etc/selinux/config /etc/selinux/config.backup
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    setenforce 0



    # Wait for BVol attach to be completed, only if the shape is not DenseIO/BM.HPC2.36
    nvme_lst=$(ls /dev/ | grep nvme | grep n1 | sort)
    nvme_cnt=$(ls /dev/ | grep nvme | grep n1 | wc -l)
    if [ $nvme_cnt -eq 0 ]; then
      # Wait for block-attach to complete. Terraform then creates the below file on server nodes
      while [ ! -f /tmp/block-attach.complete ]
      do
        sleep 60s
        echo "Waiting for block-attach via Terraform to  complete ..."
      done
    fi

    # Set password for hacluster user
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

      scp ${SSH_OPTIONS} -p -3 /home/opc/authkey opc@${NODE2_IP}:/home/opc/authkey

      ssh ${SSH_OPTIONS} opc@${NODE2_IP} "sudo mv /home/opc/authkey /etc/corosync/authkey"
      while [ $? -ne 0 ]
      do
        echo "sleeping for 20s, so NODE2 can finish deploying corosync and required directories are in place....."
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

    cp /home/opc/config/drbd_cleanup.sh  /var/lib/pacemaker/drbd_cleanup.sh
    chown root: /var/lib/pacemaker/drbd_cleanup.sh
    chmod 0755 /var/lib/pacemaker/drbd_cleanup.sh
    touch /var/log/pacemaker_drbd_file.log
    chown hacluster:haclient /var/log/pacemaker_drbd_file.log

    cp /home/opc/config/r0.res /etc/drbd.d/r0.res
    chown root: /etc/drbd.d/r0.res
    sed -i "s/NODE1_IP/${NODE1_IP}/g" /etc/drbd.d/r0.res
    sed -i "s/NODE2_IP/${NODE2_IP}/g" /etc/drbd.d/r0.res
    sed -i "s/NODE1/${NODE1}/g" /etc/drbd.d/r0.res
    sed -i "s/NODE2/${NODE2}/g" /etc/drbd.d/r0.res
    sed -i "s/QUORUM_IP/${QUORUM_IP}/g" /etc/drbd.d/r0.res
    sed -i "s/QUORUM/${QUORUM}/g" /etc/drbd.d/r0.res

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
      echo ${hacluster_user_password} | pcs cluster auth --name beegfs_mgs_cluster ${NODE1} ${NODE2} -u hacluster
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
    # need to copy file to below folder and change permission, used by move_secip.sh
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

      pcs cluster start --all
      sleep 10s
      pcs status
      pcs cluster cib /root/beegfs_cfg
      pcs -f /root/beegfs_cfg property set stonith-enabled=false
      # For 2 nodes, with no quorum node. use no-quorum-policy=ignore  instead of no-quorum-policy=stop
      pcs -f mysql_cfg property set no-quorum-policy=stop
      #pcs -f /root/beegfs_cfg property set no-quorum-policy=ignore
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
    pcs -f /root/beegfs_cfg resource create mgs_VIP ocf:heartbeat:IPaddr2 ip=${TARGET_VIP} cidr_netmask=${cidr_netmask} op monitor interval=20s
    pcs -f /root/beegfs_cfg alert create id=ip_move description="Move IP address using oci-cli" path=/var/lib/pacemaker/ip_move.sh
    pcs -f /root/beegfs_cfg alert recipient add ip_move id=logfile_ip_move value=/var/log/pacemaker_ip_move.log
    # Add beegfs service
    pcs -f /root/beegfs_cfg resource create beegfs_mgs_service systemd:beegfs-mgmtd.service \
    op monitor interval=15s
    pcs -f /root/beegfs_cfg alert create id=drbd_cleanup_file description="Monitor DRBD events and perform post cleanup" path=/var/lib/pacemaker/drbd_cleanup.sh
    pcs -f /root/beegfs_cfg alert recipient add drbd_cleanup_file id=logfile value=/var/log/pacemaker_drbd_file.log
    # Add constraint
      pcs -f /root/beegfs_cfg constraint colocation add mgt_fs with mgs_primary INFINITY with-rsc-role=Master
      pcs -f /root/beegfs_cfg constraint order promote mgs_primary then start mgt_fs
      pcs -f /root/beegfs_cfg constraint colocation add beegfs_mgs_service with mgt_fs INFINITY
      pcs -f /root/beegfs_cfg constraint order mgt_fs then beegfs_mgs_service
      pcs -f /root/beegfs_cfg constraint colocation add mgs_VIP with beegfs_mgs_service INFINITY
      pcs -f /root/beegfs_cfg constraint order beegfs_mgs_service then mgs_VIP
    fi


    # DRBD - rest of the config
    mkfs.ext4 -m 0 -F -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/sdb
    dd if=/dev/zero of=/dev/sdb bs=1k count=1024
    drbdadm create-md r0
    drbdadm up r0

    wget -O /etc/yum.repos.d/beegfs_rhel7.repo https://www.beegfs.io/release/latest-stable/dists/beegfs-rhel7.repo
    yum install beegfs-mgmtd -y

    # mount point
    mkdir -p /data/mgt1
    if [ "$LOCAL_NODE" = "$NODE1" ]; then
      drbdadm primary r0 --force
      drbdadm -- --overwrite-data-of-peer primary r0
      mkfs.ext4 -m 0 -F -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/drbd0
      mount -o defaults /dev/drbd0 /data/mgt1

      # always assume Bvol sdb. leave nvme code in place for future.
      mkdir -p /data/mgt1/beegfs_mgmtd

      # only on node1 -  node 2 will get these changes as part of drbd
      /opt/beegfs/sbin/beegfs-setup-mgmtd -p /data/mgt1/beegfs_mgmtd

      echo MGSHA > /data/mgt1/beegfs_mgmtd/nodeID
      echo 1 > /data/mgt1/beegfs_mgmtd/nodeNumID
      echo MGT1 > /data/mgt1/beegfs_mgmtd/targetID
      echo 1 > /data/mgt1/beegfs_mgmtd/targetNumID

      # beegfs -use 2nd VNIC interface
      privateIp=`curl -s $MDATA_VNIC_URL | jq '.[1].privateIp ' | sed 's/"//g' ` ;
      interface=`ip addr | grep -B2 $privateIp | grep "BROADCAST" | gawk -F ":" ' { print $2 } ' | sed -e 's/^[ \t]*//'` ;
      type="mgmtd"
      cat /etc/beegfs/beegfs-${type}.conf | grep "^connInterfacesFile"
      echo "$interface" > /etc/beegfs/${type}-connInterfacesFile.conf
      sed -i "s|connInterfacesFile.*=.*|connInterfacesFile          = /etc/beegfs/${type}-connInterfacesFile.conf|g"  /etc/beegfs/beegfs-${type}.conf
      cat /etc/beegfs/beegfs-${type}.conf | grep "^connInterfacesFile"
      cat /etc/beegfs/${type}-connInterfacesFile.conf

      echo y | cp -f /etc/beegfs/beegfs-${type}.conf /home/opc/
      scp ${SSH_OPTIONS} -p -3 /home/opc/beegfs-${type}.conf opc@${NODE2_IP}:/home/opc/beegfs-${type}.conf
      ssh ${SSH_OPTIONS} opc@${NODE2_IP} "sudo mv /home/opc/beegfs-${type}.conf /etc/beegfs/beegfs-${type}.conf"
      ssh ${SSH_OPTIONS} opc@${NODE2_IP} "sudo chown root: /etc/beegfs/beegfs-${type}.conf"

      echo y | cp -f /etc/beegfs/${type}-connInterfacesFile.conf /home/opc/
      scp ${SSH_OPTIONS} -p -3 /home/opc/${type}-connInterfacesFile.conf opc@${NODE2_IP}:/home/opc/${type}-connInterfacesFile.conf
      ssh ${SSH_OPTIONS} opc@${NODE2_IP} "sudo mv /home/opc/${type}-connInterfacesFile.conf /etc/beegfs/${type}-connInterfacesFile.conf"
      ssh ${SSH_OPTIONS} opc@${NODE2_IP} "sudo chown root: /etc/beegfs/${type}-connInterfacesFile.conf"

    fi

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
    ######  pcs resource cleanup beegfs_mgs_service


    exit 0
fi
