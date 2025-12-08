terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# AMI Ubuntu 24.04 LTS
data "aws_ami" "ubuntu_2404" {
  owners      = ["099720109477"] # Canonical
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# Obtener información de la VPC por defecto
data "aws_vpc" "default" {
  default = true
}

# Obtener subnet por defecto donde existe el rango 172.31.16.x
data "aws_subnets" "default_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Group
resource "aws_security_group" "ec2_sg" {
  name   = "allow_ssh"
  vpc_id = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
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

# Instancia EC2 con IP fija 172.31.16.49
resource "aws_instance" "ubuntu" {
  ami           = data.aws_ami.ubuntu_2404.id
  instance_type = "t3.micro"

  subnet_id         = data.aws_subnets.default_subnets.ids[0] 
  private_ip        = "172.31.16.49"                           
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  key_name = "PRACTICA-REDES"

  tags = {
    Name = "PT-BD"
  }
}
