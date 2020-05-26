#SSH_OPTIONS=" -i /home/opc/.ssh/id_rsa -o BatchMode=yes -o StrictHostkeyChecking=no "
#MDATA_VNIC_URL="http://169.254.169.254/opc/v1/vnics/"
#TYPE_VIP="mgs_VIP"




if [ "$management_high_availability" = "true" ]; then
    # Deploy components to implement HA for Management Service

    sleep 5s;
    QUORUM=$quorum_hostname
    QUORUM_IP=`nslookup $QUORUM | grep "Address: " | grep -v "#" | gawk '{print $2}'` ; echo $QUORUM_IP
    QUORUM_FQDN="${QUORUM}.${storage_subnet_domain_name}" ; echo $QUORUM_FQDN

    LOCAL_NODE=`hostname`; echo $LOCAL_NODE
    LOCAL_NODE_IP=`nslookup $LOCAL_NODE | grep "Address: " | grep -v "#" | gawk '{print $2}'` ; echo $LOCAL_NODE_IP
    QUORUM_FQDN=`hostname --fqdn`;
    QUORUM=$LOCAL_NODE
    QUORUM_IP=$LOCAL_NODE_IP
    NODE1="${server_hostname_prefix}1" ; echo $NODE1
    NODE2="${server_hostname_prefix}2" ; echo $NODE2

    NODE1_IP=`nslookup $NODE1 | grep "Address: " | grep -v "#" | gawk '{print $2}'` ;
    while [ -z $NODE1_IP ]
    do
      sleep 5s;
      echo sleeping
      NODE1_IP=`nslookup $NODE1 | grep "Address: " | grep -v "#" | gawk '{print $2}'` ;
    done
    NODE2_IP=`nslookup $NODE2 | grep "Address: " | grep -v "#" | gawk '{print $2}'` ; echo $NODE2_IP
    NODE1_FQDN="${server_hostname_prefix}1.${storage_subnet_domain_name}" ; echo $NODE1_FQDN
    NODE2_FQDN="${server_hostname_prefix}2.${storage_subnet_domain_name}" ; echo $NODE2_FQDN
    echo "$NODE1_IP $NODE1_FQDN $NODE1" >> /etc/hosts
    echo "$NODE2_IP $NODE2_FQDN $NODE2" >> /etc/hosts
    echo "$QUORUM_IP $QUORUM_FQDN $QUORUM" >> /etc/hosts

    # VIRTUAL IP
    TARGET_VIP=$management_vip_private_ip

    


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
    storage_subnet_domain_name=\"${storage_subnet_domain_name}\"
    vcn_domain_name=\"${vcn_domain_name}\"
QUORUM=\"${QUORUM}\"
QUORUM_IP=\"${QUORUM_IP}\"
QUORUM_FQDN=\"${QUORUM_FQDN}\"
    " > /root/env_variables.sh


    echo "source /root/env_variables.sh" >>  /root/.bash_profile

    cp /etc/selinux/config /etc/selinux/config.backup
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    setenforce 0

    systemctl disable drbd


    while [ ! -f /home/opc/config/global_common.conf ]
    do
      echo sleeping ; sleep 5s;
    done
    sleep 5s;
    mv -vn /etc/drbd.d/global_common.conf /etc/drbd.d/global_common.conf.orig
    cp -f /home/opc/config/global_common.conf  /etc/drbd.d/global_common.conf
    chown root: /etc/drbd.d/global_common.conf


    cp /home/opc/config/r0.res /etc/drbd.d/r0.res
    chown root: /etc/drbd.d/r0.res
    sed -i "s/NODE1_IP/${NODE1_IP}/g" /etc/drbd.d/r0.res
    sed -i "s/NODE2_IP/${NODE2_IP}/g" /etc/drbd.d/r0.res
    sed -i "s/NODE1/${NODE1}/g" /etc/drbd.d/r0.res
    sed -i "s/NODE2/${NODE2}/g" /etc/drbd.d/r0.res
    sed -i "s/QUORUM_IP/${QUORUM_IP}/g" /etc/drbd.d/r0.res
    sed -i "s/QUORUM/${QUORUM}/g" /etc/drbd.d/r0.res

    systemctl enable drbd

    drbdadm up r0

fi
