#!/bin/sh
set -x
echo "FINDME-ip_move.sh"
if [ -z $CRM_alert_version ]; then
    echo "$0 must be run by Pacemaker version 1.1.15 or later"
    exit 0
fi
 
if [ "${CRM_alert_kind}" = "resource" -a "${CRM_alert_target_rc}" = "0" -a "${CRM_alert_task}" = "start" -a "${CRM_alert_rsc}" = "TYPE_VIP" ]
then
    tstamp="$CRM_alert_timestamp: "
    echo "${tstamp}Moving IP" >> "${CRM_alert_recipient}"
    /home/oracle-cli/move_secip.sh >> "${CRM_alert_recipient}" 2>> "${CRM_alert_recipient}"
fi
