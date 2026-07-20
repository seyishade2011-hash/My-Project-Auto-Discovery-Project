# create a resource vpc
resource "aws_vpc" "vpc" {
  cidr_block = var.cidr_block
  tags = {
    Name = var.name
  }
}

# create a resource public subnets
resource "aws_subnet" "pub_subnet1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.pub_subnet1_cidr
  availability_zone       = var.pub_subnet1_az
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name}-pub_subnet1"
  }
}

resource "aws_subnet" "pub_subnet2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.pub_subnet2_cidr
  availability_zone       = var.pub_subnet2_az
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name}-pub_subnet2"
  }
}

# create a resource private subnets
resource "aws_subnet" "priv_subnet1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.priv_subnet1_cidr
  availability_zone = var.priv_subnet1_az

  tags = {
    Name = "${var.name}-priv_subnet1"
  }
}

resource "aws_subnet" "priv_subnet2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.priv_subnet2_cidr
  availability_zone = var.priv_subnet2_az

  tags = {
    Name = "${var.name}-priv_subnet2"
  }
}

# create a resource internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.name}-igw"
  }
}

# create a resource eip for nat gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags = {
    Name = "${var.name}-nat_eip"
  }
}

# create a resource nat gateway
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.pub_subnet1.id
  tags = {
    Name = "${var.name}-nat_gw"
  }
  depends_on = [aws_eip.nat_eip, aws_internet_gateway.igw] # ensure that the eip is created before the nat gateway
}

# create a resource public route table
resource "aws_route_table" "pub_rt" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.name}-pub_rt"
  }
}

# create a resource private route table
resource "aws_route_table" "priv_rt" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.name}-priv_rt"
  }
}

# create a resource route for public route table
resource "aws_route" "pub_route" {
  route_table_id         = aws_route_table.pub_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# create a resource route for private route table
resource "aws_route" "priv_route" {
  route_table_id         = aws_route_table.priv_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw.id
}

# create a resource route table association for public subnets
resource "aws_route_table_association" "pub_subnet1_assoc" {
  subnet_id      = aws_subnet.pub_subnet1.id
  route_table_id = aws_route_table.pub_rt.id
}

resource "aws_route_table_association" "pub_subnet2_assoc" {
  subnet_id      = aws_subnet.pub_subnet2.id
  route_table_id = aws_route_table.pub_rt.id
}

# create a resource route table association for private subnets
resource "aws_route_table_association" "priv_subnet1_assoc" {
  subnet_id      = aws_subnet.priv_subnet1.id
  route_table_id = aws_route_table.priv_rt.id
}

resource "aws_route_table_association" "priv_subnet2_assoc" {
  subnet_id      = aws_subnet.priv_subnet2.id
  route_table_id = aws_route_table.priv_rt.id
}

# create a resource key pair rsa key of 4096 bits        
resource "tls_private_key" "key_pair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# create a resource private key file
resource "local_file" "private_key" {
  content         = tls_private_key.key_pair.private_key_pem
  filename        = "${path.module}/key_pair.pem"
  file_permission = "0600"
}

# create a resource public key file
resource "aws_key_pair" "key_pair" {
  key_name   = "${var.name}-key_pair"
  public_key = tls_private_key.key_pair.public_key_openssh
}