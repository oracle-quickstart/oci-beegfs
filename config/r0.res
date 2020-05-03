resource r0 {
	disk /dev/sdb;
	device /dev/drbd0;
	meta-disk internal;
        on mgs-server-1 {
        	address  NODE1_IP:7789;
        }
        on mgs-server-2 {
        	address  NODE2_IP:7789;
        }
}
