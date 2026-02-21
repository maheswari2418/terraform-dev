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
resource "aws_security_group" "public-sg" {
    name="public-sg"
    description = "Allow SSh and HTTP"
    vpc_id=aws_vpc.main.id
    ingress{
        from_port=22
        to_port=22
        protocol="tcp"
        cidr_blocks=["0.0.0.0/0"]
    }
    ingress{
        from_port=80
        to_port=80
        protocol="tcp"
        cidr_blocks=["0.0.0.0/0"]
    }
    egress{
        from_port="0"
        to_port="0"
        protocol="-1"
        cidr_blocks=["0.0.0.0/0"]
    }
    tags={
        Name="public-sg"
    }
  
}
resource "aws_security_group" "private-sg"{
    name="private-sg"
    description="Allow only SSH from public-sg"
    vpc_id=aws_vpc.main.id
    ingress{
        from_port=22
        to_port=22
        protocol="tcp"
        security_groups=[aws_security_group.public-sg.id]
    }
    egress{
        from_port = "0"
        to_port = "0"
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}
resource "aws_instance" "public-ec2" {
    ami="ami-0c2b8ca1dad447f8"
    instance_type = "t3.micro"
    subnet_id=aws_subnet.public.id
    security_groups = [aws_security_group.public-sg.id]
    associate_public_ip_address = true
    key_name = "my-key"
    user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y nginx
              systemctl start nginx
              systemctl enable nginx
              echo "<h1>Server created using Terraform</h1>" > /usr/share/nginx/html/index.html
              EOF

    tags={
        Name="public-ec2"

    } 
}
resource "aws_instance" "private-ec2" {
    ami="ami-0c2b8ca1dad447f8"
    instance_type = "t3.micro"
    subnet_id=aws_subnet.private.id
    security_groups = [aws_security_group.private-sg.id]
    associate_public_ip_address = false
    key_name = "my-key"
    tags={
        Name="private-ec2"

    }
  
}
resource "aws_lb" "tg" {
    name               = "my-tg"
    internal           = false
    load_balancer_type = "application"
    security_groups    = [aws_security_group.public-sg.id]
    subnets            = [aws_subnet.public.id]
    
    tags = {
        Name = "my-tg"
    }
}

resource "aws_lb_target_group" "tg" {
    name       = "my-tg"
    port       = 80
    protocol   = "HTTP"
    vpc_id     = aws_vpc.main.id

    health_check {
        path = "/"
        port = "traffic-port"
    }
}
resource "aws_lb_target_group_attachment" "tg1" {
    target_group_arn = aws_lb.tg.arn
    target_id        = aws_instance.public-ec2.id
    port             = 80
  
}
resource "aws_lb_target_group_attachment" "tg2" {
    target_group_arn = aws_lb.tg.arn
    target_id        = aws_instance.private-ec2.id
    port             = 80
  
}