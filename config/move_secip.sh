#!/bin/sh
##### OCI vNIC variables
source /root/env_variables.sh
ocibin="/home/oracle-cli/bin/oci"
# .oci/config - not used
configfile="/home/oracle-cli/.oci/config"
# Add Dynamic Group and Policy in compartment - before installing this.  
instanceprincipal="--auth instance_principal"
server="\$(hostname -s)"
node1vnic="ocid1.vnic.oc1.iad.xxxx"
node2vnic="ocid1.vnic.oc1.iad.yyyy"
node1vnic=`curl -s http://169.254.169.254/opc/v1/vnics/ | jq '.[1].vnicId' | sed 's/"//g' ` ; echo $node1vnic
node2vnic_w_quotes=`ssh -i /home/opc/.ssh/id_rsa  -o BatchMode=yes -o StrictHostkeyChecking=no opc@10.0.3.2 "curl -s http://169.254.169.254/opc/v1/vnics/ | jq '.[1].vnicId'  "` ; echo $node2vnic_w_quotes
node2vnic=`echo $node2vnic_w_quotes |  sed 's/"//g' ` ; echo $node2vnic
vnicip="${TARGET_VIP}"
##### OCI/IPaddr Integration
if [ "\${server}" = "${NODE1}" ]
then
   \${ocibin} \${instanceprincipal} network vnic assign-private-ip --unassign-if-already-assigned --vnic-id \${node1vnic} --ip-address \${vnicip}
else
   \${ocibin} \${instanceprincipal} network vnic assign-private-ip --unassign-if-already-assigned --vnic-id \${node2vnic} --ip-address \${vnicip}
fi
