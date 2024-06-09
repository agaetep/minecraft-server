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

resource "aws_key_pair" "ssh-key" {
  key_name   = "minecraft_key"
  public_key = "ssh-rsa..."
}

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

resource "aws_instance" "app_server" {
  ami                    = "ami-0cf2b4e024cdb6960"
  instance_type          = "t2.medium"
  key_name               = aws_key_pair.ssh-key.key_name
  vpc_security_group_ids = [aws_security_group.minecraft-server.id]

  tags = {
    Name = "MinecraftServer"
  }
}
