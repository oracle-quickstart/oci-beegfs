

function install_beegfs {
  type=$1
  wget -O /etc/yum.repos.d/beegfs_rhel7.repo https://www.beegfs.io/release/latest-stable/dists/beegfs-rhel7.repo

  if [ "$type" = "mgmt" ]
  then
    yum install beegfs-mgmtd -y -q
  elif [ "$type" = "meta" ]
  then
    yum install beegfs-meta -y -q
  elif [ "$type" = "storage" ]
  then
    yum install beegfs-storage -y -q
  else
    # assume client nodes
    yum install beegfs-client beegfs-helperd beegfs-utils -y -q
  fi
}

