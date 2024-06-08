#!/bin/bash

# Create SSH key pair
ssh-keygen -f ~/.ssh/minecraft_key
chmod 600 ~/.ssh/minecraft_key

terraform init
terraform apply

# Set up hosts file
EC2_PUBLIC_IP=$(terraform output -raw instance_public_ip)
EC2_PUBLIC_IP_FORMATTED=$(echo "$EC2_PUBLIC_IP" | sed 's/\./-/g')

cat <<EOF > inventory/hosts
[instances]
ec2-$EC2_PUBLIC_IP_FORMATTED.us-west-2.compute.amazonaws.com ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/minecraft_key
EOF

ansible-playbook playbooks/install_server.yml -i inventory/hosts -vvv