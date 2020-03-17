

# Disable locate/mlocate/updatedb
# http://www.beegfs.com/wiki/ClientTuning#hn_59ca4f8bbb_3
# Client nodes
sed -i 's|/mnt|/mnt /mnt/beegfs|g'  /etc/updatedb.conf
sed -i 's|fuse.ceph|fuse.ceph beegfs|g'  /etc/updatedb.conf


