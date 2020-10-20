#!/bin/sh
set -x
echo "FINDME-move_secip.sh"
##### OCI vNIC variables
source /home/oracle-cli/env_variables.sh
ocibin="/home/oracle-cli/bin/oci"
# .oci/config - not used
configfile="/home/oracle-cli/.oci/config"
# Add Dynamic Group and Policy in compartment - before installing this.  
instanceprincipal="--auth instance_principal"
server="$(hostname -s)"
vnicip="${TARGET_VIP}"
echo "Print: ${node1vnic} ${vnicip} ${node2vnic}  "
##### OCI/IPaddr Integration
if [ "${server}" = "${NODE1}" ]
then
   ${ocibin} ${instanceprincipal} network vnic assign-private-ip --unassign-if-already-assigned --vnic-id ${node1vnic} --ip-address ${vnicip}
else
   ${ocibin} ${instanceprincipal} network vnic assign-private-ip --unassign-if-already-assigned --vnic-id ${node2vnic} --ip-address ${vnicip}
fi


if [ $? -eq 0 ]; then
  exit 0
else
  exit 1
fi
