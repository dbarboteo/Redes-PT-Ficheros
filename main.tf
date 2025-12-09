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

# Obtener la AMI más reciente de Ubuntu 24.04 LTS
data "aws_ami" "ubuntu_2404" {
  owners      = ["099720109477"] # Canonical
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# Obtener información de la VPC por defecto
data "aws_vpc" "default" {
  default = true
}

# Obtener subnets de la VPC por defecto
data "aws_subnets" "default_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Group para Base de Datos (BD)
resource "aws_security_group" "sg_bd" {
  name   = "sg_bd"
  vpc_id = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "MySQL internal"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["172.31.0.0/16"] # permite acceso desde la misma VPC
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group para FTP
resource "aws_security_group" "sg_ftp" {
  name   = "sg_ftp"
  vpc_id = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "FTP"
    from_port   = 21
    to_port     = 21
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Puertos pasivos"
    from_port = 3000
    to_port = 3100
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Instancia BD
resource "aws_instance" "ubuntu_bd" {
  ami                    = data.aws_ami.ubuntu_2404.id
  instance_type          = "t2.micro"
  subnet_id              = data.aws_subnets.default_subnets.ids[0]
  vpc_security_group_ids = [aws_security_group.sg_bd.id]
  key_name               = "PRACTICA-REDES"
  private_ip             = "172.31.92.246"

  user_data = file("${path.module}/scripts/mysql.sh")

  tags = {
    Name = "PT-BD"
  }
}

# Instancia FTP
resource "aws_instance" "ubuntu_ftp" {
  ami                    = data.aws_ami.ubuntu_2404.id
  instance_type          = "t2.micro"
  subnet_id              = data.aws_subnets.default_subnets.ids[0]
  vpc_security_group_ids = [aws_security_group.sg_ftp.id]
  key_name               = "PRACTICA-REDES"
  private_ip             = "172.31.92.247"

  user_data = file("${path.module}/scripts/ftp.sh")

  tags = {
    Name = "PT-FTP"
  }
}

# Outputs
output "bd_public_ip" {
  value = aws_instance.ubuntu_bd.public_ip
}

output "bd_private_ip" {
  value = aws_instance.ubuntu_bd.private_ip
}

output "ftp_public_ip" {
  value = aws_instance.ubuntu_ftp.public_ip
}

output "ftp_private_ip" {
  value = aws_instance.ubuntu_ftp.private_ip
}

output "subnet_id_used" {
  value = aws_instance.ubuntu_bd.subnet_id
}
