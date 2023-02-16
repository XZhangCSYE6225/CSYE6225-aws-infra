data "aws_availability_zones" "aval_zone" {
  state = "available"
}

resource "aws_subnet" "public_subnet" {
  count             = var.length
  vpc_id            = aws_vpc.xiao.id
  availability_zone = data.aws_availability_zones.aval_zone.names[count.index]
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)

  tags = {
    Name = "${var.vpc_name}-public-subnet-${count.index + 0}"
  }
}

resource "aws_subnet" "private_subnet" {
  count             = var.length
  vpc_id            = aws_vpc.xiao.id
  availability_zone = data.aws_availability_zones.aval_zone.names[count.index]
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 4)

  tags = {
    Name = "${var.vpc_name}-private-subnet-${count.index + 0}"
  }
}

resource "aws_route_table_association" "public_route_table_association" {
  count          = var.length
  subnet_id      = element(aws_subnet.public_subnet.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_route_table_association" {
  count          = var.length
  subnet_id      = element(aws_subnet.private_subnet.*.id, count.index)
  route_table_id = aws_route_table.private.id
}