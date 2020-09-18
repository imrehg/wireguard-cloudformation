Launch EC2 Instance with Wireguard
==================================

This [Cloudformation](https://aws.amazon.com/cloudformation/) creates a personal [Wireguard](https://www.wireguard.com/) VPN server in AWS. I assume a cursory understanding of AWS, Cloudformation and EC2 with existing ssh key.

You will need the following:

* Launch the `wireguard-eip-master.json` template first. It will export the elastic IP used by the `wireguard-master.json`template (so you can conveniently use the same public IP).
* Your VPC's default security group ID

Of Note:

* The default AMI is Amazon Linux 2
* This sets up the server as a DNS resolver with unbound to prevent [DNS leaking](http://dnsleak.com/)

Steps:

* After the cloudformation is deployed and server has rebooted as required ssh into it and start wireguard
    ```
    wg-quick up wg0
    ```
* Then get the client config and paste it into your client's configuration
    ```
    sudo cat /tmp/wg0-client.conf
    ```

Todo:

* Parameterize some of the unbound configuration and IP addresses.



aws cloudformation create-stack --stack-name wireguardtest --template-body "$(cat wireguard-eip-master.yml)"


date +"%Y-%m-%d-%H-%M-%S"

aws cloudformation create-change-set --stack-name wireguardtest --change-set-name "cs-$(date +"%Y-%m-%d-%H-%M-%S")" --template-body "$(cat wireguard-eip-master.yml)" 

aws cloudformation create-change-set --stack-name wireguardtest --change-set-name "cs-$(date +"%Y-%m-%d-%H-%M-%S")" --template-body "$(cat wireguard-master.yml)" --parameters ParameterKey=VpnSecurityGroupID,ParameterValue=sg-4725cb35 ParameterKey=SshKey,ParameterValue=key-09e181872fda45908 ParameterKey=VpnAmiId,ParameterValue=ami-06fd8a495a537da8b 

aws cloudformation deploy --stack-name wireguardtest --template-file wireguard-master.yml --parameters ParameterKey=VpnSecurityGroupID,ParameterValue=sg-4725cb35 ParameterKey=SshKey,ParameterValue=key-09e181872fda45908 ParameterKey=VpnAmiId,ParameterValue=ami-06fd8a495a537da8b


https://www.linode.com/docs/networking/vpn/set-up-wireguard-vpn-on-ubuntu/


Install

sudo add-apt-repository ppa:wireguard/wireguard
<!-- sudo apt install wireguard -->



https://www.flockport.com/guides/build-wireguard-networks


sudo mount -t nfs -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 10.55.10.21:/  /tmp/remote

sudo mount -t nfs -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 10.55.10.200:/  /tmp/remote

Autoscaling group for debug instance? But how about elastic IP?

### Internal

https://faculty-internal.slack.com/archives/GJ0NNPN75/p1600420604005500

#### Questions

Why autoscaling? Does it really use a lot of resources?
Should store data in EFS? Or S3? Should it store anything?
How's best to add ssh keys the best way with templates? Secrets storage? Or pulling in public keys from somewhere? Or have any other kind of interface to change wireguard settings?
Ubuntu or Amazon Linux or Debian or something else?


Protocol to exchange keys without sharing public information?

How to deploy to an existing subnet? Does it need any default securitygroup as well?
