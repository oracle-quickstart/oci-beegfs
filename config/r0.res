resource r0 {
	device /dev/drbd0;
	meta-disk internal;
    net {
        allow-two-primaries no;
        after-sb-0pri discard-zero-changes;
        after-sb-1pri discard-secondary;
        after-sb-2pri disconnect;
        rr-conflict disconnect;
    }
    on QUORUM {
        node-id 0;
        disk none;
        address QUORUM_IP:7789;
    }
    on NODE1 {
        node-id 1;
        disk /dev/sdb;
        address  NODE1_IP:7789;
    }
    on NODE2 {
        node-id 2;
        disk /dev/sdb;
        address  NODE2_IP:7789;
    }
    connection-mesh {
        hosts NODE1 NODE2 QUORUM;
    }
    handlers {
        quorum-lost "echo b > /proc/sysrq-trigger";
    }

}


