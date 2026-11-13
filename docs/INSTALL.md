# Install Keramat Tomato on another VPS

## Supported installation environment

The installer accepts Debian and Ubuntu systems using apt.
Debian 13 is a target platform; verify the Xray and HAProxy setup separately.

## Install on a new VPS

Connect to the target server:

    ssh root@IP_VPS_BAHARU

Download and inspect the installer:

    apt-get update
    apt-get install -y curl ca-certificates
    curl -fsSL https://raw.githubusercontent.com/hassinz27/keramat-tomato/main/install.sh -o install.sh
    less install.sh

Run it:

    bash install.sh

Open the panel:

    keramat

The installer refuses to overwrite an existing `/opt/keramat-vpn` directory.
It creates a new installation only.

## Required server components

This installer deploys the Keramat management files only. It does not install
or configure Xray, HAProxy, a domain, TLS certificates, firewall rules or ports.

Before using VLESS account creation, prepare an Xray installation and config
with these VLESS inbounds:

| Port | Network |
|---:|---|
| 443 | TCP |
| 10000 | TCP |
| 10001 | WS |
| 10005 | gRPC |
| 10009 | HTTPUpgrade |
| 10010 | XHTTP |

The current account module expects these six inbounds. Domain metadata is
read from `/etc/xray/domain`.

The connection profiles currently use:
- TCP non-TLS: 443
- WS non-TLS: 80
- TLS transports: 8443

Port 443 TLS is a separate migration target, not configured by this installer.

## Current limitations

- SSH/SSH WS, VMess, Trojan and OpenVPN/ZiVPN account modules are not complete.
- `lib/routing.py` is not yet included in this repository, so Routing Manager
  is not complete.
- Quota and IP-limit fields are stored as account metadata; enforcement is
  not installed by this script.
- Do not run this installer on a production VPS that already has
  `/opt/keramat-vpn`. It is intended for a separate new VPS.

## Security

Never put real customer UUIDs, passwords, private keys, TLS certificates,
tokens or production databases in this public repository.
