Connect to your router using `ssh root@routerip`

```
opkg update
```

Configure the following port forwarding (replace <your headscale ip> with the LAN ip of  your headscale server):

```
# HEADSCALE - HTTPS
uci -q delete firewall.headscale_https
uci set firewall.headscale_https="redirect"
uci set firewall.headscale_https.src="wan"
uci set firewall.headscale_https.src_dport="443"
uci set firewall.headscale_https.dest="lan"
uci set firewall.headscale_https.dest_ip="<your headscale server ip>"
uci set firewall.headscale_https.dest_port="443"
uci set firewall.headscale_https.proto="tcp"
uci set firewall.headscale_https.target="DNAT"

# HEADSCALE - HTTP
uci -q delete firewall.headscale_http
uci set firewall.headscale_http="redirect"
uci set firewall.headscale_http.src="wan"
uci set firewall.headscale_http.src_dport="80"
uci set firewall.headscale_http.dest="lan"
uci set firewall.headscale_http.dest_ip="<your headscale server ip>"
uci set firewall.headscale_http.dest_port="80"
uci set firewall.headscale_http.proto="tcp"
uci set firewall.headscale_http.target="DNAT"

# STUN
uci -q delete firewall.headscale_stun
uci set firewall.headscale_stun="redirect"
uci set firewall.headscale_stun.src="wan"
uci set firewall.headscale_stun.src_dport="3478"
uci set firewall.headscale_stun.dest="lan"
uci set firewall.headscale_stun.dest_ip="<your headscale server ip>"
uci set firewall.headscale_stun.dest_port="3478"
uci set firewall.headscale_stun.proto="udp"
uci set firewall.headscale_stun.target="DNAT"

# DERP
uci -q delete firewall.headscale_derp
uci set firewall.headscale_derp="redirect"
uci set firewall.headscale_derp.src="wan"
uci set firewall.headscale_derp.src_dport="41641"
uci set firewall.headscale_derp.dest="lan"
uci set firewall.headscale_derp.dest_ip="<your headscale server ip>"
uci set firewall.headscale_derp.dest_port="41641"
uci set firewall.headscale_derp.proto="udp"
uci set firewall.headscale_derp.target="DNAT"

# HEADPLANE (optional)
uci -q delete firewall.headplane
uci set firewall.headplane="redirect"
uci set firewall.headplane.src="wan"
uci set firewall.headplane.src_dport="50443"
uci set firewall.headplane.dest="lan"
uci set firewall.headplane.dest_ip="<your headscale server ip>"
uci set firewall.headplane.dest_port="50443"
uci set firewall.headplane.proto="tcp"
uci set firewall.headplane.target="DNAT"

# Commit and apply
uci commit firewall
/etc/init.d/firewall restart
```

Software and Hardware Acceleration. It will only be used if the NIC supports it:

```
uci set firewall.@defaults[0].flow_offloading='1'
uci set firewall.@defaults[0].flow_offloading_hw='1'
uci commit firewall
/etc/init.d/firewall restart
```

Optional: once the WAN is plugged into your network:

```
uci set firewall.headscale_https.reflection='1'
uci set firewall.headscale_http.reflection='1'
uci set firewall.headplane.reflection='1'
uci commit firewall
/etc/init.d/firewall restart
```

Optional package installations:

```
opkg install banip luci-app-banip
opkg install luci-app-adblock
opkg install luci-app-nlbwmon netperf
```

If you have x86 based router:

```
wget https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-x86_64.tgz
tar -xvzf ookla-speedtest-1.2.0-linux-x86_64.tgz
cp speedtest /usr/bin/
chmod +x /usr/bin/speedtest
```
```
wget https://dl.influxdata.com/telegraf/releases/telegraf-1.35.2_linux_amd64.tar.gz
tar -xvzf telegraf-1.35.2_linux_amd64.tar.gz
cd telegraf-1.35.2
cp usr/bin/telegraf /usr/bin/
chmod +x /usr/bin/telegraf
```

Edit telegraf config > /etc/telegraf.conf

to be completed