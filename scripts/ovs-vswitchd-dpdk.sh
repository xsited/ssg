# ovs-vswitchd --dpdk -c 0x1 -n 4 -- unix:$DB_SOCK --pidfile --detach
# ovs-vswitchd --dpdk -c 0x1 -n 4 --socket-mem 1024,0 -- unix:$DB_SOCK --pidfile --detach

#   To use ovs-vswitchd with DPDK, create a bridge with datapath_type
#   "netdev" in the configuration database.  For example:

#   `ovs-vsctl add-br br0 -- set bridge br0 datapath_type=netdev`

#   Now you can add dpdk devices. OVS expect DPDK device name start with dpdk
#   and end with portid. vswitchd should print (in the log file) the number
#   of dpdk devices found.

#   ```
#   ovs-vsctl add-port br0 dpdk0 -- set Interface dpdk0 type=dpdk
#   ovs-vsctl add-port br0 dpdk1 -- set Interface dpdk1 type=dpdk
#   ```

#   Once first DPDK port is added to vswitchd, it creates a Polling thread and
#   polls dpdk device in continuous loop. Therefore CPU utilization
#   for that thread is always 100%.

#   Note: creating bonds of DPDK interfaces is slightly different to creating
#   bonds of system interfaces.  For DPDK, the interface type must be explicitly
#   set, for example:

#   ```
#   ovs-vsctl add-bond br0 dpdkbond dpdk0 dpdk1 -- set Interface dpdk0 type=dpdk -- set Interface dpdk1 type=dpdk

killall ovs-vswitchd
ovs-vswitchd --dpdk -c 0x0FF8 -n 4 --socket-mem 2048,0 -- unix:/var/run/openvswitch/db.sock -vconsole:emer -vsyslog:err -vfile:info --mlockall --no-chdir --log-file=/var/log/openvswitch/ovs-vswitchd.log --pidfile=/var/run/openvswitch/ovs-vswitchd.pid --detach --monitor
