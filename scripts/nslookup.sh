find_cluster_nodes () {
  # Make a list of nodes in the cluster
  echo "Doing nslookup for other nodes of same type..."
  ct=1
  if [ $nodeCount -gt 0 ]; then
    while [ $ct -le $nodeCount ]; do
      nslk=`nslookup $nodeHostnamePrefix${ct}.$domainName`
      ns_ck=`echo -e $?`
      if [ $ns_ck = 0 ]; then
        hname=`nslookup $nodeHostnamePrefix${ct}.$domainName | grep Name | gawk '{print $2}'`
        ct=$((ct+1));
      else
        # sleep 10 seconds and check again - infinite loop
        echo "Sleeping for 10 secs and check again for $nodeHostnamePrefix${ct}.$domainName"
        sleep 10
      fi
    done;
    echo "Found ${nodeCount} nodes";
  else
    echo "no nodes to lookup"
    exit 1;
  fi
}

# find all nodes of the same type : management, meta, storage.
nodeCount=$server_node_count
nodeHostnamePrefix=$server_hostname_prefix
domainName=$storage_subnet_domain_name
find_cluster_nodes

