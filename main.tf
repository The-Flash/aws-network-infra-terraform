terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "ami_id" {
  type = string
  default = "ami-05e411cf591b5c9f6"
  description = "AMI ID. defaults Amazon LInux"
}

provider "aws" {
    region = "us-east-1"
    shared_config_files = ["~/.aws/credentials"]
}

# Create VPC
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Production"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id
}

# Create a NAT Gateway
resource "aws_eip" "nat-gateway-eip" {
  domain = "vpc"

  tags = {
    Name = "EIP For Nat Gateway"
  }
}

resource "aws_nat_gateway" "nat-gateway" {
  # This will be configured within a public subnet
  # Deployed in public subnet 2
  allocation_id = aws_eip.nat-gateway-eip.id
  subnet_id = aws_subnet.public-subnet-2.id

  depends_on = [aws_eip.nat-gateway-eip]

  tags = {
    Name = "Public NAT Gateway"
  }
}

# Create Public Route Table
resource "aws_route_table" "public-route-table-1" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Public Route Table 1"
  }
}

resource "aws_route_table" "private-route-table-1" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat-gateway.id
  }

  tags = {
    Name = "Private Route Table 1"
    Description = "Contains mapping for Nat Gateway. Associated to a private subnet"
  }
}

# Create 2 Public Subnets
resource "aws_subnet" "public-subnet-1" {
  vpc_id = aws_vpc.prod-vpc.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Public Subnet 1"
  }
}

resource "aws_subnet" "public-subnet-2" {
  vpc_id = aws_vpc.prod-vpc.id    
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "Public Subnet 2"
  }
}

# Associate subnets with Route Table
resource "aws_route_table_association" "rta-1" {
  subnet_id = aws_subnet.public-subnet-1.id
  route_table_id = aws_route_table.public-route-table-1.id
}

resource "aws_route_table_association" "rta-2" {
  subnet_id = aws_subnet.public-subnet-2.id
  route_table_id = aws_route_table.public-route-table-1.id
}

resource "aws_route_table_association" "private-rta-1" {
  subnet_id = aws_subnet.private-subnet-1.id
  route_table_id = aws_route_table.private-route-table-1.id
}

# Create 2 Private subnets
resource "aws_subnet" "private-subnet-1" {
  vpc_id = aws_vpc.prod-vpc.id    
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Private Subnet 1"
  }
}

resource "aws_subnet" "private-subnet-2" {
  vpc_id = aws_vpc.prod-vpc.id    
  cidr_block = "10.0.3.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "Private Subnet 2"
  }
}

resource "aws_security_group" "sg-1" {
  vpc_id = aws_vpc.prod-vpc.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Security Group for Public Web Server 1"
  }
}

resource "aws_eip" "public-web-server-eip" {
  domain = "vpc"
  instance = aws_instance.public-web-server-1.id
  depends_on = [aws_internet_gateway.gw]

  tags = {
    Name = "Elastic IP for Public Web server 1"
  }
}

resource "aws_instance" "public-web-server-1" {
    ami = var.ami_id
    instance_type = "t2.micro"
    subnet_id = aws_subnet.public-subnet-1.id
    key_name = "server-key-pair-1"
    vpc_security_group_ids = [aws_security_group.sg-1.id]
    tags = {
      Name=  "Public Web Server"
    }
}

resource "aws_security_group" "private-sg-1" {
  vpc_id = aws_vpc.prod-vpc.id

  ingress {
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Security Group for Private Web Server 1"
  }
}

resource "aws_eip" "private-server-eip" {
  domain = "vpc"
  instance = aws_instance.private-web-server-1.id
  depends_on = [aws_internet_gateway.gw]

  tags = {
    Name = "Elastic IP for Private Server"
  }
}

resource "aws_instance" "private-web-server-1" {
    ami = var.ami_id
    instance_type = "t2.micro"
    subnet_id = aws_subnet.private-subnet-1.id
    key_name = "server-key-pair-2"
    vpc_security_group_ids = [aws_security_group.private-sg-1.id]
    tags = {
      Name=  "Private Web Server"
    }
}


