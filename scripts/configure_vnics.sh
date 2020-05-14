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
  vnic_cnt=`/root/secondary_vnic_all_configure.sh | grep "ocid1.vnic." | grep " UP " | wc -l` ;
  RC=1
  while ( [ $vnic_cnt -le 1 ] || [ $RC -ne 0 ] )
  do
    echo "sleep 10s" 
    sleep 10
    systemctl restart secondnic.service
    RC=$?
    vnic_cnt=`/root/secondary_vnic_all_configure.sh | grep "ocid1.vnic." | grep " UP " | wc -l` ; 
  done

}

