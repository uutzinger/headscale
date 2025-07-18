# Headscale

Installation of headscale on home lab network. This installation is considered moderately difficult by AI agents but making exit nodes and subnet routing working is difficult.

This installation is based on the following physical devices
- gl.inet openwrt type Router/Wirless Access Point 
- Proxmox server

The installation uses
- proxmox
    - headscale Virtual Machine / ubuntu server
        - Docker
            -Caddy reverse proxy
            -Cloudflare-ddns for public domain name IP updates
            -Headscale (0.26.1)
            -Headplane (0.6.0) as headscale admin GUI
    - tailscale Virtual Machine for exit node / ubuntu server
        - tailscale (1.84.1) installed on ubuntu (no docker)

It is recommended to separate tailscale exit node from headscale VM.

It is helpful to have a public domain name. One can obtain them easily at Cloudflare for as little ot $7/year (e.g. yourlastname.us). For the domain you will want an entry for headscale.yourlastname.us. You can also install mail forwarding for example yourfirstname@lastname.us You need to be U.S. resident for domain `us` and registration requires publishing your phonen number. Alternative is to use duckdns.org.

<!-- TOC start (generated with https://github.com/derlin/bitdowntoc) -->

## Table of Content

- [Headscale](#headscale)
   * [Router](#router)
   * [Proxmox Server](#proxmox-server)
   * [Headscale Virtual Machine](#headscale-virtual-machine)
      + [Portainer](#portainer)
         - [Headscale Stack](#headscale-stack)
   * [Tailscale VM](#tailscale-vm)
   * [Tailscale client node on laptop or desktop Ubuntu](#tailscale-client-node-on-laptop-or-desktop-ubuntu)

<!-- TOC end -->

<!-- TOC --><a name="headscale"></a>
## Router

On a gl.inet or openwrt router/WAP the portforwarding and firewall settings are stored in `/etc/config/firewall`
You can reach the router with `ssh root@ROUTER_IP`.

**Abbreviations**

`ROUTER_IP=192.168.16.0`

**Entries in the firewall file**
These settings also visible in the LUuCI interface but not the regular web GUI.

Bascially your need to:
 - enable masquerading from WAN to LAN interface
 - LAN to WAN allow in,out,forward
 - portforward from WAN 80,443,3478,41641,51820 to LAN

```
# On Firewall -> General Settings Tab
config defaults
	option input 'ACCEPT'
	option output 'ACCEPT'
	option forward 'REJECT'
	option synflood_protect '1'

config zone
	option name 'lan'
	list network 'lan'
	option input 'ACCEPT'
	option output 'ACCEPT'
	option forward 'ACCEPT'

config zone
	option name 'wan'
	list network 'wan'
	list network 'wan6'
	list network 'wwan'
	option output 'ACCEPT'
	option forward 'REJECT'
	option mtu_fix '1'
	option input 'DROP'
	option masq '1'
	option masq6 '1'

config forwarding
	option src 'lan'
	option dest 'wan'
	option enabled '1'

# On Firewall -> Port Forwards Tab
config redirect
	option proto 'tcp'
	option src_dport '80'
	option dest_ip '192.168.16.20'
	option src 'wan'
	option dest 'lan'
	option dest_port '80'
	option idx '1'
	option target 'DNAT'
	option enabled '1'
	option name 'GL-Caddy: HTTP for Let'\''s Encrypt'

config redirect
	option proto 'tcp'
	option src_dport '443'
	option dest_ip '192.168.16.20'
	option src 'wan'
	option dest 'lan'
	option dest_port '443'
	option target 'DNAT'
	option enabled '1'
	option name 'GL-Caddy: HTTPS for reverse proxy'

config redirect
	option proto 'udp'
	option src_dport '3478'
	option dest_ip '192.168.16.20'
	option dest_port '3478'
	option src 'wan'
	option dest 'lan'
	option target 'DNAT'
	option enabled '1'
	option name 'GL-Talescale: STUN for NAT traversal'

config redirect
	option proto 'udp'
	option src_dport '41641'
	option dest_port '41641'
	option src 'wan'
	option dest 'lan'
	option dest_ip '192.168.16.20'
	option target 'DNAT'
	option enabled '1'
	option name 'GL-Headscale: DERP for Tailscale'

config redirect
	option proto 'udp'
	option src_dport '51820'
	option dest_port '51820'
	option src 'wan'
	option dest 'lan'
	option dest_ip '192.168.16.20'
	option target 'DNAT'
	option enabled '1'
	option name 'GL-Wireguard: UDP'
```

## Proxmox Server

Install proxmox by booting of proxmox ISO or flashdrive.

You will not want firewall setup on proxmox but you can on the operating system once installed in the VMs.

```
Data Center -> Firewall -> Option No
Data Center -> Node -> Firewall -> Option No
Data Center -> Node -> Headscale VM -> Firewall -> Option No
Data Center -> Node -> Talescale VM -> Firewall -> Option No
```

**Headscale VM**
Machine: q35, QEMU Agent: on, VirtIOSCSI: 16GB, IOThread: On, Cores:2, CPU Type: Host, Numa: On, Memory: 2.5GB, Network: VirtIO, Multiqueue: 2

Multiqueue should not be larger than number of cores.
Memory should have Ballooning Device enabled

**Tailscale VM**
Machine: q35, QEMU Agent: on, VirtIOSCSI: 8GB, IOThread: On, Cores:2, CPU Type: Host, Numa: On, Memory: 1.5GB, Network: VirtIO, Multiqueue: 2

## Headscale Virtual Machine

**Prepare the Ubuntu Server**
Install regular Ubuntu server with no extra packages. Once it is running:

```
sudo apt update

# 1. Install OpenSSH
sudo apt install -y openssh-server
sudo systemctl enable ssh
sudo systemctl start ssh

# 2. Remove any old versions (optional)
sudo apt remove -y docker docker-engine docker.io containerd runc

# 3. Install required packages
sudo apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# 4. Add Docker’s official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# 5. Add Docker's repository
echo \
  "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 6. Install Docker Engine
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo usermod -aG docker $USER
newgrp docker

# 7. Install QEMU guest
sudo apt update
sudo apt install -y qemu-guest-agent
sudo systemctl enable qemu-guest-agent
sudo systemctl start qemu-guest-agent
```

### Portainer
Lets create separate portainer docker container.
Once its running we can install the other containers from within portainer.

```
docker run -d \
--name portainer \
--restart unless-stopped \
-p 9000:9000 \
-p 9443:9443 \
-v /var/run/docker.sock:/var/run/docker.sock \
-v portainer_data:/data portainer/portainer-ce:latest
```

#### Headscale Stack

In the user's home directy we should create the following folders and configuration files in them.

**Directories**
headscale-stack/
headscale-stack/caddy/Caddyfile
headscale-stack/caddy/data/

headscale-stack/headscale/
headscale-stack/headscale/lib
headscale-stack/headscale/run
headscale-stack/headscale/config/config.yaml

headscale-stack/headplane
headscale-stack/headplane/lib
headscale-stack/headplane/config/config.yaml

As shown in the folder `headscale-stack` in this repo
- [Caddy File](./caddy/Caddyfile)
- [Head Scale Config](./headscale/config/config.yaml) [edit server_url]
- [Head Plane Config](./headplane/config/config.yaml) [edit cookie_secret and public_url]

In portainer we will create a stack and call it `headscale`.

**Environment variables**

`CLOUDFLARE_API_KEY=<API key from your cloudflaire account>`
`CLOUDFLARE_ZONE=something.us`
`CLOUDFLARE_SUBDOMAIN=headscale`
`HEADSCALE_STACK_PATH=/home/utzinger/headscale-stack`
`HEADSCALE_IP=192.168.16.20`


**Stack Configuration File**
```
services:
  headscale:
    image: headscale/headscale:0.26.1
    container_name: headscale
    volumes:
      - '${HEADSCALE_STACK_PATH}/headscale/lib:/var/lib/headscale'
      - '${HEADSCALE_STACK_PATH}/headscale/run:/var/run/headscale'
      - '${HEADSCALE_STACK_PATH}/headscale/config:/etc/headscale'
    ports:
      - "8080:8080"
      - "41641:41641/udp"
      - "3478:3478/udp"
    command: serve
    labels:
      # This is needed for Headplane to find it and signal it
      me.tale.headplane.target: headscale
    restart: unless-stopped

  headplane:
    image: ghcr.io/tale/headplane:0.6.0
    container_name: headplane
    ports:
      - "3000:3000"
    volumes:
      - '${HEADSCALE_STACK_PATH}/headplane/config:/etc/headplane'
      - '${HEADSCALE_STACK_PATH}/headplane/lib:/var/lib/headplane'
      - '/var/run/docker.sock:/var/run/docker.sock:ro'
      - '${HEADSCALE_STACK_PATH}/headscale/config:/etc/headscale'
    depends_on:
      - headscale
    restart: unless-stopped

  caddy:
    image: caddy:latest
    container_name: caddy
    ports:
      - "${HEADSCALE_IP}:80:80"
      - "${HEADSCALE_IP}:443:443"
    volumes:
      - '${HEADSCALE_STACK_PATH}/caddy/Caddyfile:/etc/caddy/Caddyfile'
      - '${HEADSCALE_STACK_PATH}/caddy/data:/data'
      - '${HEADSCALE_STACK_PATH}/headscale/lib:/var/lib/headscale:ro'
    restart: unless-stopped

  ddns:
    image: oznu/cloudflare-ddns
    container_name: cloudflare-ddns
    restart: unless-stopped
    environment:
      - API_KEY=${CLOUDFLARE_API_KEY}
      - ZONE=${CLOUDFLARE_ZONE}
      - SUBDOMAIN=${CLOUDFLARE_SUBDOMAIN}
      - PROXIED=false
```

- [create authkey](./headscale/create_authkey.sh) [edit user ID/number]
- [check headscale](./headscale/check_headscale.sh)

## Tailscale VM

We will want an exit node for the home LAN.

Install minimal unbunut server.
Install packages as shown above in Headscale server. You might need to install a few more packages as minimal server might be missing curl, jq etc.

- [install Tailscale](./tailscale_exitnode/install_tailscale.sh) [edit advertise routes, enter authkey when prompted, create with script above]
- [remove Tailscale](./tailscale_exitnode/remove_tailscale.sh)
- [setup Tailscale VM network](./tailscale_exitnode/tailscale_exitnode_setup.sh)
- [check Tailscale network](./tailscale_exitnode/check_tailscale.sh)

An exit node will need packet forwarding and masquerading and firewall should allow access as attempted in the provided script.

Unfortuantely seeing the machines in the tailscale network does not mean routing or exit node function will work. Its very time consuming to determine the configuration errors.

## Tailscale client node on laptop or desktop Ubuntu

- [install Tailscale](./tailscale_client/install_tailscale_laptop.sh) [edit advertise routes]
- [remove Tailscale](./tailscale_client/remove_tailscale_laptop.sh)
- [setup Tailscale VM network](./tailscale_client/tailscale_laptop_setup.sh)
- [check Tailscale network](./tailscale_client/check_tailscale.sh)
