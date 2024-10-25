terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region                   = "eu-central-1"
  shared_config_files      = ["~/.aws/config"]
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "vscode"
}


resource "aws_vpc" "dev-vpc" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true

  tags = {
    environment = "dev"
  }
}

resource "aws_subnet" "dev-public-subnet" {
  vpc_id            = aws_vpc.dev-vpc.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "eu-central-1a"

  tags = {
    environment = "dev-public"
  }
}

resource "aws_internet_gateway" "dev-internet-gateway" {
  vpc_id = aws_vpc.dev-vpc.id

  tags = {
    environment = "dev"
  }
}

resource "aws_route_table" "dev-route-table" {
  vpc_id = aws_vpc.dev-vpc.id

  tags = {
    environment = "dev"
  }
}

resource "aws_route" "default-internet-route" {
  route_table_id         = aws_route_table.dev-route-table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.dev-internet-gateway.id
}

resource "aws_security_group" "dev-sg" {
  name        = "dev-sg"
  description = "dev security group"
  vpc_id      = aws_vpc.dev-vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${var.ownIP}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "dev-auth" {
  key_name   = "dev-key"
  public_key = file("~/.ssh/aws-dev-key.pub")
}

resource "aws_instance" "dev-vm" {
  instance_type          = "t2.micro"
  ami                    = data.aws_ami.server-ami.id
  key_name               = aws_key_pair.dev-auth.key_name
  vpc_security_group_ids = [aws_security_group.dev-sg.id]
  subnet_id              = aws_subnet.dev-public-subnet.id
  user_data = file("userdata.tpl")

  tags = {
    name = "dev-vm"
  }

  root_block_device {
    volume_size = 16
  }

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-config.tpl", {
      hostname = self.public_ip
      user = "ubuntu"
      identityfile = "~/.ssh/aws-dev-key"
    })
    interpreter = var.host_os != "windows" ? ["bash", "-c"] : ["Powershell", "-Command"]
  }
}