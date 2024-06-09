# CS 312 Course Project Part 2

This repository sets up a Java Minecraft Server using an AWS EC2 instance. 
The instance is created and configured using Terraform.
Once it is created, Ansible playbooks are used to install the Minecraft server and run it.

# Requirements
- AWS and AWS credentials: The EC2 instance is configured using Terraform, which needs to be supplied with your AWS credentials to connect
- Terraform: [Install Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) according to the machine you are using
- Ansible: [Install Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) with pip or pipx

# How Does It Work?
## Terraform
Terraform is used to set up the EC2 instance through AWS. The bulk of the setup is in `main.tf`:

### `main.tf`
Setting up Terraform requires setting up AWS resources, the first of which point to AWS itself, and the user's AWS. Here, the region in which the instance will be created is defined, as well as the file where your AWS credentials live.
```
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region                   = "us-west-2"
  shared_credentials_files = ["aws_credentials"]
}
```

The SSH key is then added to the workflow, so that the instance can be created and accessed with it. The `key_name` variable should be the name of the SSH key file you are using, and `public_key` is simply the contents of your `key_name.pub` file.
```
resource "aws_key_pair" "ssh-key" {
  key_name   = "minecraft_key"
  public_key = "ssh-rsa..."
}
```

Next a security group is configured with two ingress rules and anywhere egress. The two ingress rules are necessary for SSH, on port 22, and the Minecraft server's port, 25565 (the default for Java Minecraft servers). Both are TCP protocols.
```
resource "aws_security_group" "minecraft-server" {
  name = "minecraft-server"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 25565
    to_port     = 25565
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

Finally, the instance is actualized with an Ubuntu ami image, and a `t2.medium` size to be able to store the server. The SSH key and security group created above are added.
```
resource "aws_instance" "app_server" {
  ami                    = "ami-0cf2b4e024cdb6960"
  instance_type          = "t2.medium"
  key_name               = aws_key_pair.ssh-key.key_name
  vpc_security_group_ids = [aws_security_group.minecraft-server.id]

  tags = {
    Name = "MinecraftServer"
  }
}
```

### `outputs.tf`
The other Terraform file is a small one, used to grab the public IP of the AWS instance that `main.tf` creates, and saves it into the variable `instance_public_ip`.
```
output "instance_public_ip" {
    value = aws_instance.app_server.public_ip
}
```

## Ansible Playbooks

Ansible is leveraged to automate the set up and creation of the Minecraft server, but what the playbooks do is quite simple.

### `install_server.yml`
Java is needed to run the Minecraft server's .jar file, so that should first be installed with `apt`. Because we must first check if `apt` is up to date, `become: true` elevates privileges to update `apt` and install Java.
```
- name: Update and upgrade apt
    become: true
    apt:
    update_cache: true
    upgrade: true

- name: Install java
    become: true
    apt:
    name: default-jre
    state: present
```

A server directory is then created with the name `minecraft_server`, and the server is downloaded into it with `wget`.
```
- name: Create server directory
    file: 
    path: minecraft_server
    state: directory

- name: Download server
    get_url:
    url: https://piston-data.mojang.com/v1/objects/145ff0858209bcfc164859ba735d4199aafa1eea/server.jar
    dest: minecraft_server
```

The download places a `server.jar` file into the directory, which must be extracted with the Java package installed earlier. 
```
- name: Extract server
    command: java -Xmx1024M -Xms1024M -jar server.jar nogui
    args:
    chdir: minecraft_server
```

### `run_server.yml`
The second playbook creates a `systemd` service that automatically starts the server when the instance starts. A Jinja2 template in `templates/minecraft.service.j2` provides the systemd information, which is just running the same command used to extract the server earlier.
```
- name: Create auto start service file for server
    become: true
    template:
    src: ../templates/minecraft.service.j2
    dest: /etc/systemd/system/minecraft.service
```

Then, the `systemd` service that was just created is started.
```
- name: Start minecraft server service
    become: true
    systemd:
    name: minecraft
    state: started
```

## Bash Scripts
There are two bash scripts, one for each Ansible playbook.

### `setup.sh`
This script extracts the public IP of the newly created instance from Terraform's output. The `inventory/hosts` file is updated to include this IP, so that the playbooks can connect to the instance.
```bash
#!/bin/bash

EC2_PUBLIC_IP=$(terraform output -raw instance_public_ip)
EC2_PUBLIC_IP_FORMATTED=$(echo "$EC2_PUBLIC_IP" | sed 's/\./-/g')

cat <<EOF > inventory/hosts
[instances]
ec2-$EC2_PUBLIC_IP_FORMATTED.us-west-2.compute.amazonaws.com ansible_user=ubuntu ansible_ssh_private_key_file=./minecraft_key
EOF

ansible-playbook playbooks/install_server.yml -i inventory/hosts
```

### `run.sh`
This script simply runs the `run_server` playbook. It is not necessary as it is one command that you can run yourself, but simplifies the process.
```bash
#!/bin/bash

ansible-playbook playbooks/run_server.yml -i inventory/hosts
```

# Executing the Scripts
Create and SSH key pair with the name `minecraft_key` *in the current directory* to access the instance. Paste the contents of the public key `minecraft_key.pub` into the `main.tf` file under the `aws_key_pair` resource, so the instance is aware of this key.
```bash
$ ssh-keygen -f minecraft_key
```

Make sure the scripts have executable permissions.

```bash
$ chmod +x ./setup.sh
```

```bash
$ chmod +x ./run.sh
```

Paste your AWS credentials into the `aws_credentials` file. Then initialize Terraform to begin working with it.

```bash
$ terraform init
```

Run the `main.tf` file by applying the changes.
```bash
$ terraform apply
```

Use the `setup.sh` script to run the `install_server` playbook. You may need to wait a few minutes before running this until the instance is done setting up.
```bash
$ ./setup.sh
```

Once the `server.jar` file is first extracted, the server cannot run until the EULA is accepted. To do this, log on to the instance to accept the EULA.

Find the instance IP using the `outputs.tf` file.
```bash
$ terraform output
```

SSH into the instance using the SSH key and IP address of the instance. Since this is an Ubuntu image, the user is `ubuntu`.
```bash
$ ssh -i minecraft_key ubuntu@<PUBLIC_IP>
```

In the instance, move into the `minecraft_server` directory the `install_server` playbook created.
```bash
$ cd minecraft_server
```

Open the EULA, and change the value from `false` to `true`.
```bash
vim eula.txt
```

Exit out of the instance, and run the `run.sh` script to set up auto restart and run the server.
```bash
$ ./run.sh
```

To connect to the Minecraft server, log in to Minecraft and select multiplayer. Add a server. The server address should be the public IP, with port 25565: `PUBLIC_IP:25565`.