resource "aws_vpc" "main" {
  cidr_block = var.cidr
  tags={
    Name="main-vpc"
  }
}
resource "aws_subnet" "public" {
    vpc_id=aws_vpc.main.id
    cidr_block=var.public_cidr
    map_public_ip_on_launch = true
    availability_zone = "ap-south-1a"
    tags={
        Name="public-subnet"
    }

}
resource "aws_subnet" "private" {
    vpc_id = aws_vpc.main.id
    cidr_block = var.private_cidr
    availability_zone = "ap-south-1a"
  tags={
    name="private-subnet"
  }
}
resource "aws_internet_gateway""igw"{
    vpc_id=aws_vpc.main.id
}
resource "aws_eip" "nat"{
    domain="vpc"
}
# resource "aws_nat_gateway" "natgw"{
#     allocation_id = aws_eip.nat.id
#     subnet_id=aws_subnet.public.id
resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  depends_on = [aws_internet_gateway.igw]
}


resource "aws_route_table" "public_rt"{
    vpc_id=aws_vpc.main.id
    route{
        cidr_block="0.0.0.0/0"
        gateway_id=aws_internet_gateway.igw.id
    }
}
resource "aws_route_table_association" "public_rta"{
    subnet_id = aws_subnet.public.id
    route_table_id = aws_route_table.public_rt.id
}
resource "aws_route_table" "private_rt"{
    vpc_id=aws_vpc.miam.id
    route{
        cidr_block ="0.0.0.0/0"
        nat_gateway_id=aws_nat_gateway.natgw.id
    }
}
resource "aws_route_table_association" "private_rt" {
    subnet_id=aws_subnet.private.id
    route_table_id = aws_route_table.private_rt.id
  
}