
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

function tune_sysctl() {
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
}


# Disable locate/mlocate/updatedb
# http://www.beegfs.com/wiki/ClientTuning#hn_59ca4f8bbb_3
# Storage nodes.  The OST's are mounted at /data/ostX.
sed -i 's|/mnt|/mnt /data|g'  /etc/updatedb.conf


# These can cause degradation of performance.  So measure before and after and only apply if it improves performance.  
#echo 5 > /proc/sys/vm/dirty_background_ratio
#echo 20 > /proc/sys/vm/dirty_ratio
#echo 50 > /proc/sys/vm/vfs_cache_pressure
#echo 262144 > /proc/sys/vm/min_free_kbytes
#echo 1 > /proc/sys/vm/zone_reclaim_mode

echo always > /sys/kernel/mm/transparent_hugepage/enabled
echo always > /sys/kernel/mm/transparent_hugepage/defrag

devices=(sdb sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu sdv sdw sdx sdy sdz sdaa sdab sdac sdad sdae sdaf sdag nvme0n1 nvme1n1 nvme2n1 nvme3n1 nvme4n1 nvme5n1 nvme6n1 nvme7n1)
for dev in "${devices[@]}"
do
  echo deadline > /sys/block/${dev}/queue/scheduler
  echo 4096 > /sys/block/${dev}/queue/nr_requests
  echo 4096 > /sys/block/${dev}/queue/read_ahead_kb
  echo 256 > /sys/block/${dev}/queue/max_sectors_kb
done



# Call the functions
tune_nics
tune_sysctl

tuned-adm profile throughput-performance


# Concurrency Tuning - Worker Threads
# Storage servers, metadata servers and clients allow you to control the number of worker threads by setting the value of tuneNumWorkers (in /etc/beegfs/beegfs-X.conf). In general, a higher number of workers allows for more parallelism (e.g. a server will work on more client requests in parallel). But a higher number of workers also results in more concurrent disk access, so especially on the storage servers, the ideal number of workers may depend on the number of disks that you are using.
sed -i 's/tuneNumWorkers.*=.*/tuneNumWorkers               = 64/g' /etc/beegfs/beegfs-storage.conf
