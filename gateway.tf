resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.duck-vpc.id
}


resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.duck-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Prod"
  }
}

# ASSOCIATE SUBNET WITH ROUTE TABLE

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.primary-subnet.id
  route_table_id = aws_route_table.prod-route-table.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.standby-subnet.id
  route_table_id = aws_route_table.prod-route-table.id
}

