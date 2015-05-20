sudo ovs-vsctl set-manager ptcp:6640
sudo ovsctl show
sudo ovsdb-client get-schema tcp:192.168.10.114:6640 --pretty
sudo ovsdb-client dump tcp:192.168.10.114:6640

