# Launch an EC2 Instance with Wireguard

This [Cloudformation](https://aws.amazon.com/cloudformation/) creates a personal [Wireguard](https://www.wireguard.com/) VPN server in AWS. It assumes a cursory understanding of AWS, Cloudformation and EC2 with existing SSH key.

**Note** that this is just one setup that I found quick and easy to work with, it is not production level deployment, will need to know a thing or two about server maintenance & wireguard. On the other hand, it's likely as simplified (architecturewise) & cheap as it can get to run a Wireguard server on AWS (please let me know if you disagree / have feedback on this! :)

## Cloud resources

This template will create roughly the following resources to run the Wireguard server:

* an elastic IP to use with your VPN (and be stable over server deploys)
* networking infrastructure (a new VPC, subnets, security groups, internet gateway, ...)
* an EFS network drive to store the server configuration in
* an EC2 instance running the server itself

## Usage

Deploy the template to your AWS, with some parameters added. The deployment can be done like this using the [AWS CLI](https://aws.amazon.com/cli/):


```shell
aws cloudformation deploy \
    --stack-name <stackname> \
    --template-file wireguard.yml \
    --parameter-overrides SshKey=<sshkey-name> VpnAmiId=<ami-id>
```

Here you have to add your SSH key, which was already created or imported into AWS. (If no such key yet, you can do that in EC2 / Network & Security / Key Pairs. You will also likely need to define an Ubuntu 20.04 Amazon Machine Image (AMI) ID. For example:

For example

```shell
aws cloudformation deploy \
    --stack-name wireguard \
    --template-file wireguard.yml \
    --parameter-overrides SshKey=default VpnAmiId=ami-06fd8a495a537da8b
```

You can see your resources created in CloudFormation. Once your instance up and running, grab the elastic IP address now attached to it, and log in:

```shell
ssh -i "<sshkey-path>" -o "UserKnownHostsFile=/dev/null" ubuntu@<elasitic-ip>
```

for example:

```shell
ssh -i "~/.ssh/aws/default.pem" -o "UserKnownHostsFile=/dev/null" ubuntu@1.2.3.4
```

Depending whether the server setup as finished yet or not, you might want to check the logs (in `/var/log/cloud-init-output.log`), or just wait a bit. Once the setup has completed, the Wireguard server should be set up and running, and can check that with the command line tool:

```shell
ubuntu@ip-A-B-C-D:~$ sudo wg
interface: wg0
  public key: ZLXKOMWY0KMcmWM2GOHjFYxCCileo7nzMU5qf4A2Ngo=
  private key: (hidden)
  listening port: 51820
```

To set up a client, the easiest is doing everything on the server first, and then passing on all the information to the client.

```shell
sudo wg set wg0 peer <publickey> allowed-ips <clientip>/32
```

To fill in the relevant details first pick a client IP to be used with this client (within the subnet set by `ServerTunnelSubnet` variable in the template), say `10.20.10.10` (a different IP for each client).

Then generate a pair of public and private keys on the server (a different pair for each client):

```shell
wg genkey | tee privatekey | wg pubkey > publickey
```

and create a new peer in the server configuration with these values, say:

```shell
sudo wg set wg0 peer $(cat publickey) allowed-ips 10.20.10.10/32
```

After this you should be able to see the client listed in the server's status:

```
ubuntu@ip-A-B-C-D:~$ sudo wg
  public key: ZLXKOMWY0KMcmWM2GOHjFYxCCileo7nzMU5qf4A2Ngo=
  private key: (hidden)
  listening port: 51820

peer: XD/0m56n4dzaTWWhD12nhp8uo5sMKqXlUk1BiVIGehk=
  allowed ips: 10.20.10.10/32
```

Then create a client connection file with content like this:

```ini
[Interface]
PrivateKey = <publickey>
Address = <clientip>/32
DNS = 1.1.1.1, 8.8.8.8, 8.8.4.4

[Peer]
PublicKey = <serverpublickey>
AllowedIPs = 0.0.0.0/0
Endpoint = <elasticip>:<wireguardport>
```

For example:

```ini
[Interface]
PrivateKey = sHVNBQQIiQ65pPZGuwCjcIIhr1EkGDqUnR1M5lPMeHM=
Address = 10.20.10.10/32
DNS = 1.1.1.1, 8.8.8.8, 8.8.4.4

[Peer]
PublicKey = KlIdKco2QXj/2Qy66wAPSAle/KgJOTGuLv4eS5da9gg=
AllowedIPs = 0.0.0.0/0
Endpoint = 34.253.53.124:51820
```

On the client [install Wireguard](https://www.wireguard.com/install/) and import the above connection file. Once the client is connected, on the server you should see handshake and traffic information, such as:

```shell
ubuntu@ip-A-B-C-D:~$ sudo wg
interface: wg0
  public key: ZLXKOMWY0KMcmWM2GOHjFYxCCileo7nzMU5qf4A2Ngo=
  private key: (hidden)
  listening port: 51820

peer: XD/0m56n4dzaTWWhD12nhp8uo5sMKqXlUk1BiVIGehk=
  endpoint: XX.XX.XX.XX:36429
  allowed ips: 10.20.10.10/32
  latest handshake: 8 seconds ago
  transfer: 148 B received, 92 B sent
```

The client should be then routing all traffic through the VPN. You can check this for example by going to [https://ipinfo.tw/](https://ipinfo.tw/) or any other page to check your current public IP address. It should show the elastic IP attached to your W

### Links

Inspirations for this deployment code, much thanks for them 🙇‍♂️:

* https://github.com/tripleonard/wireguard-cloudformation
* https://github.com/rupertbg/aws-wireguard-linux
