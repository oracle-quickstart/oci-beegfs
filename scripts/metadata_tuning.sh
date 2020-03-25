####!/bin/bash

set -x

echo 5 > /proc/sys/vm/dirty_background_ratio
echo 20 > /proc/sys/vm/dirty_ratio
echo 50 > /proc/sys/vm/vfs_cache_pressure
echo 262144 > /proc/sys/vm/min_free_kbytes
echo 1 > /proc/sys/vm/zone_reclaim_mode

echo always > /sys/kernel/mm/transparent_hugepage/enabled
echo always > /sys/kernel/mm/transparent_hugepage/defrag

devices=(sdb sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr sds sdt sdu sdv sdw sdx sdy sdz sdaa sdab sdac sdad sdae sdaf sdag nvme0n1 nvme1n1 nvme2n1 nvme3n1 nvme4n1 nvme5n1 nvme6n1 nvme7n1)
for dev in "${devices[@]}"
do
  echo deadline > /sys/block/${dev}/queue/scheduler
  echo 128 > /sys/block/${dev}/queue/nr_requests
  echo 128 > /sys/block/${dev}/queue/read_ahead_kb
  echo 256 > /sys/block/${dev}/queue/max_sectors_kb
done




#### For BeeGFS

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
