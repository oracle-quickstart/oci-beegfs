#!/bin/sh
if [ -z $CRM_alert_version ]; then
    echo "$0 must be run by Pacemaker version 1.1.15 or later"
    exit 0
fi
 
tstamp="$CRM_alert_timestamp: "
 
case $CRM_alert_kind in
    resource)
        if [ ${CRM_alert_interval} = "0" ]; then
            CRM_alert_interval=""
        else
            CRM_alert_interval=" (${CRM_alert_interval})"
        fi
 
        if [ ${CRM_alert_target_rc} = "0" ]; then
            CRM_alert_target_rc=""
        else
            CRM_alert_target_rc=" (target: ${CRM_alert_target_rc})"
        fi
 
        case ${CRM_alert_desc} in
            Cancelled) ;;
            *)
                echo "${tstamp}Resource operation "${CRM_alert_task}${CRM_alert_interval}" for "${CRM_alert_rsc}" on "${CRM_alert_node}": ${CRM_alert_desc}${CRM_alert_target_rc}" >> "${CRM_alert_recipient}"
                if [ "${CRM_alert_task}" = "stop" ] && [ "${CRM_alert_desc}" = "Timed Out" ]; then
                    echo "Executing recovering..." >> "${CRM_alert_recipient}"
                    pcs resource cleanup ${CRM_alert_rsc}
                fi
                ;;
        esac
        ;;
    *)
        echo "${tstamp}Unhandled $CRM_alert_kind alert" >> "${CRM_alert_recipient}"
        env | grep CRM_alert >> "${CRM_alert_recipient}"
        ;;
esac
