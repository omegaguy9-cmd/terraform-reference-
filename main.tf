provider "aws" {
  region = "us-east-1"
}

data "aws_vpc" "default" {
  default = true
}

resource "tls_private_key" "instance_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "example" {
  key_name   = "example-ec2-key"
  public_key = tls_private_key.instance_key.public_key_openssh
}

resource "aws_security_group" "web_sg" {
  name        = "example-web-sg"
  description = "Allow SSH and HTTP inbound traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "example-web-security-group"
  }
}

resource "aws_instance" "example" {
  ami                    = "ami-0c55b159cbfafe1f0"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.example.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  tags = {
    Name = "example-ec2-instance"
  }

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ec2-user"
    private_key = tls_private_key.instance_key.private_key_pem
    timeout     = "2m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum install -y httpd",
      "sudo systemctl enable httpd",
      "sudo systemctl start httpd",
      "echo '<h1>Provisioned via Terraform</h1>' | sudo tee /var/www/html/index.html"
    ]
  }

  provisioner "local-exec" {
    command = "echo ${self.public_ip} > instance_public_ip.txt"
  }
}
