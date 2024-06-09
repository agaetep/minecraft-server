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
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDxXRxybIXOGPAh1UyD3QvDONpDgDXB8KIdjUnnXFASHoUlopGJ2duo9zmSWOhryG4QKC6X3kItyKj2N7g8tQziZqhPFbAZkGC/zcjIeJV5uWEitvOp6PKrscNAqxlfRDwMhajBvILEYEeRMD+iSh7Dc0zdPinFOZRqqTbnAhaIc4ZMKbQE58psK+ymaytvzm/CeLYUkieg0b3JNqen9hAyjkCNspBCthj2NQ/ZpjZ0u4Jz+ioguHAbRoyZY3Yms5zzCQQKLkMQ16xtps9T4PvsGP75pBlYO0ym0eFwJelToDD0RWagLwQpX68gcsZe5qDX4i626yQQArYFdUYcJZrNfpkCxLHrp0RgdOP7qC83Gb8K5L4bg1mLzpP/FPCdLIvvJ6NgX9Vu5gtYxr3cBFmqxOVaS7NEOqHzJ9z9cNthOaLHRnQj3ynIEKKaWAZn2a9P4az02/2Z47XCTBZ4w04BEORb13sFnff+gywzzSf/QYpjoXb3T8KwfHBzeFixxxc= antoniagaete@Antonias-MacBook-Pro-2.local"
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
