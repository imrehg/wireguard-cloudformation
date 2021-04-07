#!/bin/bash

###
# Create required files
###
cat <<END >/tmp/wireguard-setup.sh
#!/bin/bash -ex
cd /etc/wireguard
umask 077
wg genkey | tee privatekey | wg pubkey > publickey
PRIVATEKEY=\$(cat privatekey)
rm privatekey publickey
cat <<EOF > "/etc/wireguard/wg0.conf"
[Interface]
PrivateKey = \$PRIVATEKEY
Address = 10.20.10.1/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o ens4 -j MASQUERADE;
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o ens4 -j MASQUERADE;
SaveConfig = true
EOF
END
chmod +x /tmp/wireguard-setup.sh

cat <<END >/tmp/wg.conf
net.ipv4.conf.all.forwarding = 1
net.ipv6.conf.all.forwarding = 1
END
sudo mv /tmp/wg.conf /etc/sysctl.d/wg.conf

cat <<END >/tmp/etc-wireguard.mount
[Unit]
Description = Mount remote Wireguard config store
[Mount]
What=REPLACE_VPN_FILESTORE_IP:/config_share_vpn
Where=/etc/wireguard
Type=nfs
Options=rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2
# Uncomment the below if your server is real slow
# TimeoutSec=600
[Install]
WantedBy=multi-user.target
END
sudo cp /tmp/etc-wireguard.mount /etc/systemd/system/etc-wireguard.mount

###
# Software update
###
sudo apt-get update
sudo apt-gret -qy upgrade

sudo apt-get -qy --no-install-recommends install \
    nfs-common \
    wireguard

###
# System startup
###
sudo sysctl --system
sudo systemctl enable etc-wireguard.mount
sudo systemctl start etc-wireguard.mount
if [ ! -f "/etc/wireguard/wg0.conf" ]; then sudo bash /tmp/wireguard-setup.sh ; fi
sudo ufw allow 22/tcp
sudo ufw allow 51820/udp
sudo ufw --force enable
sed -i "s/^\(After\|Wants\)=.*/& etc-wireguard.mount/" /lib/systemd/system/wg-quick@.service
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0
