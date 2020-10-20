
yum -y install pcs pacemaker corosync
# disable all of them for the image.  Then once the DRBD is configured completely (after reboot) and all the below services are also configured, then enable them, so on each reboot, these services will be on already.
systemctl disable pcsd
systemctl disable pacemaker
systemctl disable corosync


# Stonith SBD fencing
yum install fence-agents-sbd -y
yum install sbd -y

# 3rd Quorum node related changes
yum install corosync-qdevice -y
