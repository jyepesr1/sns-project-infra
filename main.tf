terraform {
  required_version = ">= 0.12"
  backend "s3" {
    bucket  = "sns-project-terraform-backend"
    encrypt = false
    key     = "terraform.tfstate"    
    region  = "us-east-1"  
  }
}

provider "aws" {
  region = var.region_name
}

resource "aws_vpc" "main_vpc" {
  cidr_block           = "172.31.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "igw"
  }
}

resource "aws_subnet" "public_1" {
  availability_zone       = "us-east-1a"
  cidr_block              = "172.31.0.0/24"
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.main_vpc.id

  tags = {
    Name = "Public-1"
    Zone = "Public"
  }
}

resource "aws_subnet" "public_2" {
  availability_zone       = "us-east-1b"
  cidr_block              = "172.31.1.0/24"
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.main_vpc.id

  tags = {
    Name = "Public-2"
    Zone = "Public"
  }
}

resource "aws_subnet" "private_1" {
  availability_zone       = "us-east-1a"
  cidr_block              = "172.31.2.0/24"
  vpc_id                  = aws_vpc.main_vpc.id
  map_public_ip_on_launch = false

  tags = {
    Name = "Private-1"
    Zone = "Private"
  }
}

resource "aws_route_table" "rtb_public" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "rta_subnet_public-1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.rtb_public.id
}

resource "aws_route_table_association" "rta_subnet_public-2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.rtb_public.id
}

resource "aws_security_group" "sg_ssh" {
  name        = "allow_public_ssh"
  description = "Allow incoming ssh connections from Anywhere"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
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

  tags = {
    Name        = "allow_public_ssh"
    responsible = "johan_yepes"
    project     = "sns-project"
  }
}

resource "aws_security_group" "sg_ssh_from_bastion" {
  name        = "allow_ssh_from_bastion"
  description = "Allow incoming SSH connections from bastion host"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_ssh.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "allow_ssh_from_bastion"
    responsible = "johan_yepes"
    project     = "sns-project"
  }
}

# Create a key pair which we are going to use to SSH on our EC2
resource "aws_key_pair" "ec2key" {
  key_name   = "johan_yepes_key"
  public_key = file(var.public_key_path)
}

# Create new ec2 instance of t2.micro type
resource "aws_instance" "bastion" {
  ami                    = var.instance_ami # CentOS 7 AMI (free tier)
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.sg_ssh.id]
  key_name               = aws_key_pair.ec2key.key_name
  #user_data              = base64encode(data.template_file.template_bastion.rendered)
  #iam_instance_profile   = aws_iam_instance_profile.s3_access_from_ec2_profile.name

  tags = {
    responsible = "johan_yepes"
    project     = "sns-project"
    Name        = "Bastion"
  }

  volume_tags = {
    responsible = "johan_yepes"
    project     = "sns-project"
    Name        = "Bastion"
  }
}

resource "aws_eip" "eip" {
  vpc        = true
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public_1.id
  depends_on    = [aws_internet_gateway.igw]

  tags = {
    Name        = "NAT Gateway"
    responsible = "johan_yepes"
    project     = "sns-project"
  }
}

resource "aws_route_table" "rtb_private" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name        = "rtb_private_subnet"
    responsible = "johan_yepes"
    project     = "sns-project"
  }
}

resource "aws_route_table_association" "rtb_assoc_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.rtb_private.id
}

