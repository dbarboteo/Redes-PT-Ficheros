# Generar clave SSH automáticamente
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Crear key pair en AWS
resource "aws_key_pair" "terraform_key" {
  key_name   = "terraform-key-${formatdate("YYYYMMDD-hhmm", timestamp())}"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# Guardar la clave privada localmente
resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/terraform-key.pem"
  file_permission = "0400"
}

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
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

# Elastic IP para FTP (se crea primero, sin asignar)
resource "aws_eip" "ftp_eip" {
  domain = "vpc"

  tags = {
    Name = "PT-FTP-EIP"
  }
}

# Instancia BD
resource "aws_instance" "ubuntu_bd" {
  ami                    = data.aws_ami.ubuntu_2404.id
  instance_type          = "t2.micro"
  subnet_id              = data.aws_subnets.default_subnets.ids[0]
  vpc_security_group_ids = [aws_security_group.sg_bd.id]
  key_name               = aws_key_pair.terraform_key.key_name

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
  key_name               = aws_key_pair.terraform_key.key_name

  user_data = templatefile("${path.module}/scripts/ftp.sh", {
    ftp_public_ip = aws_eip.ftp_eip.public_ip
    bd_private_ip = aws_instance.ubuntu_bd.private_ip
  })
  
  user_data_replace_on_change = true

  tags = {
    Name = "PT-FTP"
  }
  
  lifecycle {
    ignore_changes = [user_data]
  }
}

# Asociación de la Elastic IP a la instancia
resource "aws_eip_association" "ftp_eip_assoc" {
  instance_id   = aws_instance.ubuntu_ftp.id
  allocation_id = aws_eip.ftp_eip.id
}

# Outputs
output "bd_public_ip" {
  value = aws_instance.ubuntu_bd.public_ip
}

output "bd_private_ip" {
  value = aws_instance.ubuntu_bd.private_ip
}

output "ftp_public_ip" {
  value = aws_eip.ftp_eip.public_ip
}

output "ftp_private_ip" {
  value = aws_instance.ubuntu_ftp.private_ip
}

output "ftp_elastic_ip" {
  value = aws_eip.ftp_eip.public_ip
}

output "subnet_id_used" {
  value = aws_instance.ubuntu_bd.subnet_id
}

output "ssh_private_key_path" {
  value = local_file.private_key.filename
  description = "Ruta al archivo de clave privada SSH"
}

output "ssh_connection_bd" {
  value = "ssh -i ${local_file.private_key.filename} ubuntu@${aws_instance.ubuntu_bd.public_ip}"
  description = "Comando para conectar a la instancia BD"
}

output "ssh_connection_ftp" {
  value = "ssh -i ${local_file.private_key.filename} ubuntu@${aws_eip.ftp_eip.public_ip}"
  description = "Comando para conectar a la instancia FTP"
}