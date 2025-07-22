# Headscale, Tailscale, Headplane

Installation of a network mesh using headscale and tailscale for a home lab network.

This installation is considered moderately difficult by AI agents but making exit nodes and subnet routing working when there are issues can become very difficult and time consuming.

This installation is based on the following physical devices
- OpenWRT type Router 
- Proxmox server for virtual machines

The installation uses
- **proxmox**
    - headscale Virtual Machine / **Ubuntu server**
        - Docker
            -**Caddy** reverse proxy
            -**Cloudflare-ddns** for public domain name IP updates
            -**Headscale** (0.26.1)
            -**Headplane** (0.6.0) as headscale admin GUI
    - tailscale Virtual Machine for exit node / ubuntu server
        - **tailscale** (1.84.1) installed on ubuntu

It is recommended to separate tailscale exit node from the headscale VM and its unnecessary to run tailscale in docker.

## Table of Content

<!-- TOC start (generated with https://github.com/derlin/bitdowntoc) -->

- [Headscale, Tailscale, Headplane](#headscale-tailscale-headplane)
   * [Table of Content](#table-of-content)
   * [Domain Name](#domain-name)
   * [Router](#router)
   * [Proxmox Server](#proxmox-server)
      + [Create two Virtual Machines](#create-two-virtual-machines)
         - [**Headscale VM**](#headscale-vm)
         - [**Tailscale VM**](#tailscale-vm)
   * [Headscale Virtual Machine](#headscale-virtual-machine)
      + [Ubuntu Server: Post Installation  ](#ubuntu-server-post-installation)
         - [Static IP](#static-ip)
         - [Portainer](#portainer)
         - [Headscale Stack](#headscale-stack)
            * [Directories](#directories)
            * [Portainer Headscale Stack](#portainer-headscale-stack)
            * [Portainer/Docker Logfiles](#portainerdocker-logfiles)
      + [Debugging](#debugging)
   * [Tailscale VM](#tailscale-vm-1)
      + [Optional: Create Exit Node post boot network update service](#optional-create-exit-node-post-boot-network-update-service)
   * [Tailscale client node on laptop or desktop Ubuntu](#tailscale-client-node-on-laptop-or-desktop-ubuntu)
   * [Tailscale Android Phone](#tailscale-android-phone)

<!-- TOC end -->

<!-- TOC --><a name="headscale-tailscale-headplane"></a>
## Domain Name

You need a **public domain name**. One can obtain them easily at Cloudflare for as little ot $7/year (e.g. yourlastname.us). Alternative free approach is to use duckdns.org.

For the domain name you will want an entry such as headscale.`yourlastname.us`. For the`us` domain you need to be an U.S. resident and registration requires publishing your phone number (spam call protection suggested).

- [Cloudflare Dashboard](https://dash.cloudflare.com)

After purchasing a domain, create a DNS entry in your domain with type `A`, and `DNS only`.

Cloudflare Zero Trust only provides HTTP/HTTPS tunnel and not all the ports you need for headscale. Its not used here.

## Router

Bascially you need to:
 - Enable masquerading from WAN to LAN interface (default)
 - LAN to WAN allow in,out,forward (default)
 - Forward headscale ports from WAN to LAN
 - Enable full cone NAT
 - Enable Software & Hardware acceleration if available.

You might also want:
 - Disable DNS Rebind Protection (Main GUI->Network->DNS)
 - Disable Local Services Only(LuCi->Network->DHCP&DNS->General)
 - Disable SYN flood protection (temporarily) (LuCi->Network->Firewall->General)
 - Disable SIP ALG (Main GUI->Network->NAT Settings)

Read [Router Configuration](./Router.md) for the commands needed for openwrt to set this up.

## Proxmox Server

Install proxmox by booting of proxmox ISO or flashdrive proxmox installation media.

You will not want the firewalls on proxmox but you can install it on the operating system once the virtual machines works.

There are 3 levels of firewalls in proxmox!

In the proxmox GUI:
```
Data Center -> Firewall -> Option No
Data Center -> Node -> Firewall -> Option No
Data Center -> Node -> Headscale VM -> Firewall -> Option No
Data Center -> Node -> Talescale VM -> Firewall -> Option No
```

In the proxmox node shell check `pve-firewall status` It should say disabled

### Create two Virtual Machines

You will need to have Ubuntu Server iso downloaded and available in the proxmox node local ISO images storage.
Use LTS version and Ubuntu server.

#### **Headscale VM**
Machine: q35, QEMU Agent: on, VirtIOSCSI: 16GB, IOThread: On, Cores:2, CPU Type: Host, Numa: On, Memory: 2.5GB, Network: VirtIO, Multiqueue: 2

Multiqueue should not be larger than number of cores.
Memory should have Ballooning Device enabled

#### **Tailscale VM**
Machine: q35, QEMU Agent: on, VirtIOSCSI: 8GB, IOThread: On, Cores:2, CPU Type: Host, Numa: On, Memory: 1.5GB, Network: VirtIO, Multiqueue: 2

## Headscale Virtual Machine

### Ubuntu Server: Post Installation  

Install a regular Ubuntu server with no extra packages. Once it is running add some packages and software in the proxmox shell for the VM. Once SSH works you can ssh into the server:

[Install basic pacakges](./ubuntu_server_bassic_packages.sh)

#### Static IP
Inside the VM assign a static IP to your interface.

- determine interface name: `ip a`
- `ls /etc/netplan`
- `sudo nano /etc/netplan/something-config.yaml`
- e.g. 
```
network:
    ...
    ens18:
      dhcp4: false
      addresses:
        - 192.168.16.20/24
      nameservers:
        addresses:
          - 1.1.1.1
          - 8.8.8.8
      routes:
        - to: 0.0.0.0/0
          via: 192.168.16.1
```
- `sudo netplan apply`

#### Portainer

Lets create portainer docker container in the server. Once its running we can install the other containers from within portainer.

```
docker network create headscale_net

docker run -d \
--name portainer \
--restart unless-stopped \
--network headscale_net \
-p 9000:9000 \
-p 9443:9443 \
-v /var/run/docker.sock:/var/run/docker.sock \
-v portainer_data:/data portainer/portainer-ce:latest
```

Connect to portainer with the op of the headscale VM `https://<headscale ip>:9443`. Create the necessary first time installation.

#### Headscale Stack

We will create a docker stack and expose the config files.

In the user's home directory we should create the following folders:

##### Directories

mkdir -p ~/headscale-stack/caddy/{data,config}
mkdir -p ~/headscale-stack/headscale/{lib,run,config}
mkdir -p ~/headscale-stack/headplane/{config,lib}
mkdir -p ~/headscale-stack/cloudflared

The necessary files are:
- Caddy File: (./caddy/Caddyfile)
- Head Scale Config: (./headscale/config/config.yaml) 
- Head Plane Config: (./headplane/config/config.yaml) [edit cookie_secret and public_url]

The **Caddyfile** should contain:
```
headscale.utzinger.us {
	reverse_proxy headscale:8080
}
```

The **Headscale config** default file is obtained from https://github.com/juanfont/headscale. 

It's the `config-example.yaml` and it needs to go to `headscale/config/config.yaml`

You need to change the following:
- server_url: `https://<your full public hostname>`
- *_addr from `127.0.0.1` to `0.0.0.0`
- `derp:serve:enabled: true`
- `ephemeral_node_inactivity_timeout:` longer than 30minutes, a machine with ephemeral key be removed from the network if its turned off after that amount of time.
- `policy:mode:database` so you can edit in headplane
- `dns:base_domain: <domain of your choice>` but not the public domain.

The **Headplane config** default file is obtained from https://github.com/tale/headplane/:

You need to change the following:
- `server:cookie_secret: "<any 32 characters, no more or less>"`
- `headscale:url: "http://headscale:8080"`
- `headscale:public_url: "https://<your public hostname>"`
- `integration:docker:enabled: true`
- `oidc:` all commented out with "#"

Once the headscale stack is running you need to create access control list for headscale. That you best done in headplane: `<http://yourheadscal VM ip>:3000/admin` got to "Access Control" and enter:
```
{
  "acls": [
    {
      "action": "accept",
      "src": ["*"],
      "dst": ["*:*"]
    }
  ]
}
```

##### Portainer Headscale Stack

In portainer we will create a stack and call it `headscale`.

**Environment variables**

`HEADSCALE_STACK_PATH=/home/utzinger/headscale-stack`
`CLOUDFLARE_API_KEY=<key you obtain from cloudflare>`
`CLOUDFLARE_ZONE=<the domain you purchased> `
`CLOUDFLARE_SUBDOMAIN=headscale or similar`

Enter the [Stack Configuration File](./portainer-docker.yaml) into the editor.

##### Portainer/Docker Logfiles
When you devoid the stack and the containers run you need to address any issues you find the log files.

Connect to Portainer in your browser then Containers>Quick Action>Logs.

All container need to be attached to `headscale_default` network which you can check in protainer by clicking on the container.

### Debugging

docker run --rm -it --network headscale_default busybox ping headscale

## Tailscale VM

We will want an exit node for the home LAN. We will use:
- minimal unbunut server.
- install packages as shown above in Headscale server (ubuntu_server_basic_packages.sh). You might need to install a few more packages as minimal server might be missing curl, jq etc.

- [install Tailscale exit node](./install_tailscale_exitnode.shnstall_tailscale.sh) 
  - edit advertise routes
  - enter authkey when prompted
  - create auth key with script `create_authkey.sh`

- Go to headplane and click on the new machine
  - Enable exit node
  - Enable routers

- [check Tailscale installation](./tailscale_exitnode/check_tailscale.sh)

An exit node will need packet forwarding and masquerading and firewall should allow access as attempted in the provided script.

If you have issue with persitent network configuration install the service described below.

### Optional: Create Exit Node post boot network update service

If your network settings are not persistent on the exit node you can create a system service: `nano /etc/systemd/system/tailscale-exitnode-setup.service`

Its content should be:

```
[Unit]
Description=Tailscale Exit Node Boot Fixes
After=network.target tailscaled.service
Requires=network.target

[Service]
Type=oneshot
RemainAfterExit=true
ExecStart=/home/uutzinger/tailscale_exitnode_postboot.sh

[Install]
WantedBy=multi-user.target
uutzinger@tailscale:~$ 
```

and the script `tailscale_exitnode_postboot.sh` should be present at correct location (see this repo).

## Tailscale client node on laptop or desktop Ubuntu

- [install Tailscale](./install_tailscale_node.sh) [edit advertise routes]
- [check Tailscale network](./check_tailscale.sh)

If you are using gnome browse the gnome shell extension and search for tailscale. Install the tailscale dock.

## Tailscale Android Phone

From playstore install tailscale.

Under `Settings:Accounts` use the three dots to `Use a different server` and enter your headscale public hostname. It will give you command to add the phone to your network.

Since headscale runs in docker you need to ssh to the headscale VM and enter `docker exec headscale <Command that was displayed>` or you open Headplane and at the machine with `Machines>Add Device>Register Machine Key`