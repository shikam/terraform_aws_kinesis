provider "aws" {
  access_key = "<ENTER ACCESS KEY>"
  secret_key = "<ENTER SECRET KEY>"
  region     = "us-east-1"
}

//define the aws instance. the iam is linux hvm for us-east-1.
resource "aws_instance" "web" {
  ami           = "ami-0de53d8956e8dcf80"
  instance_type = "t2.micro"
  user_data = "${file("userdata.sh")}"
  key_name = "${aws_key_pair.default.id}"
  associate_public_ip_address = true
  subnet_id = "${aws_subnet.public-subnet.id}"
  iam_instance_profile = "${aws_iam_instance_profile.directeam_profile.name}"
  vpc_security_group_ids = [
    "${aws_security_group.sgweb.id}",
  ]
  tags {
    Name = "webserver"
  }
}

# Define SSH key pair for our instances
resource "aws_key_pair" "default" {
  key_name = "aws_directeam_ec2_key"
  public_key = "<ENTER PUBLIC KEY - GENERATE USING SSH-KEYGEN>"
}



# Define the security group for public subnet
resource "aws_security_group" "sgweb" {
  name = "vpc_sg_web"
  description = "Allow incoming HTTP connections & SSH access"
  //port for ssh
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks =  ["0.0.0.0/0"]
  }

  //port for POST request
  ingress {
    from_port = 5000
    to_port = 5000
    protocol = "tcp"
    cidr_blocks =  ["0.0.0.0/0"]
  }

  //return for outside network
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  vpc_id="${aws_vpc.main.id}"

  tags {
    Name = "Web Server SG"
  }
}

//define iam role for ec2
resource "aws_iam_role" "iam_directeam_role" {
  name = "directeam_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
      tag-key = "tag-value"
  }
}

//create profile for the iam
resource "aws_iam_instance_profile" "directeam_profile" {
  name = "directeam_profile"
  role = "${aws_iam_role.iam_directeam_role.name}"
}

//give the iam access to ec2 actions
resource "aws_iam_role_policy" "inline_policy" {
  name = "inline_policy"
  role = "${aws_iam_role.iam_directeam_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

//create vpc
resource "aws_vpc" "main" {
  cidr_block = "${var.vpc_cidr}"
  instance_tenancy = "default"
  enable_dns_hostnames = true
  tags {
    Name = "main"
  }
}

# Define the internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"

  tags {
    Name = "VPC IGW"
  }
}

# Define the route table
resource "aws_route_table" "web-public-rt" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags {
    Name = "Public Subnet RT"
  }
}


# Assosiate the route table to the Subnet
resource "aws_route_table_association" "web-public-rt" {
  subnet_id = "${aws_subnet.public-subnet.id}"
  route_table_id = "${aws_route_table.web-public-rt.id}"
}

resource "aws_subnet" "public-subnet" {
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "${var.public_subnet_cidr}"
  tags {
    Name = "subnet1"
  }
}

