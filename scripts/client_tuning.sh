
function tune_nics() {
  hpc_node=false
  intel_node=true
  lscpu | grep "Vendor ID:"  | grep "AuthenticAMD"
  if [ $? -eq 0 ];  then
    echo "do nothing - AMD"
    intel_node=false
  else
    nic_lst=$(ifconfig | grep " flags" | egrep -v "^lo:|^enp94s0f0:" | gawk -F":" '{ print $1 }' | sort) ; echo $nic_lst
    for nic in $nic_lst
    do
      ethtool -G $nic rx 2047 tx 2047 rx-jumbo 8191
      echo "ethtool -G $nic rx 2047 tx 2047 rx-jumbo 8191" >> /etc/rc.local
      echo "ethtool -L $nic combined 74" >> /etc/rc.local
      chmod +x /etc/rc.local
    done
  fi
}




function tune_beegfs {
# Beegfs tuning
sed -i 's/connMaxInternodeNum.*=.*/connMaxInternodeNum          = 64/g'  /etc/beegfs/beegfs-client.conf
}

function tune_network_sysctl {

# network tuning
echo "net.ipv4.tcp_timestamps = 0" >> /etc/sysctl.conf
echo "net.ipv4.tcp_window_scaling = 1" >> /etc/sysctl.conf
echo "net.ipv4.tcp_adv_win_scale=1" >> /etc/sysctl.conf
echo "net.ipv4.tcp_low_latency=1" >> /etc/sysctl.conf
echo "net.ipv4.tcp_sack = 1" >> /etc/sysctl.conf


echo "net.core.wmem_max=16777216" >> /etc/sysctl.conf
echo "net.core.rmem_max=16777216" >> /etc/sysctl.conf
echo "net.core.wmem_default=16777216" >> /etc/sysctl.conf
echo "net.core.rmem_default=16777216" >> /etc/sysctl.conf
echo "net.core.optmem_max=16777216" >> /etc/sysctl.conf
echo "net.core.netdev_max_backlog=27000" >> /etc/sysctl.conf

echo "net.ipv4.tcp_rmem = 212992 87380 16777216" >> /etc/sysctl.conf
echo "net.ipv4.tcp_wmem = 212992 65536 16777216" >> /etc/sysctl.conf

/sbin/sysctl -p /etc/sysctl.conf

tuned-adm profile throughput-performance

}



# Call the functions
tune_nics
tune_network_sysctl
tune_beegfs

