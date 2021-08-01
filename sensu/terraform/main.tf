terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"

    }
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "david"
}

resource "aws_instance" "sensu-master" {
  ami             = "ami-0131900387d5c4c19"
  instance_type   = "t2.large"
  security_groups = ["${aws_security_group.sensu-master-sg.name}"]
  key_name        = "mysensu"
  provisioner "local-exec" {
    command = "echo 'backend-url:\n  - \"ws://${self.public_ip}:8081\"' >> backend.yaml"
  }
  tags = {
    Name = "sensu-master"
  }
}

resource "aws_instance" "sensu-node" {
  ami             = "ami-02e571c0e8307f226"
  instance_type   = "t2.large"
  security_groups = ["${aws_security_group.sensu-node-sg.name}"]
  key_name        = "mysensu"

  provisioner "file" {
    source      = "backend.yaml"
    destination = "/tmp/backend.yaml"

    connection {
      type        = "ssh"
      host        = self.public_ip
      user        = "ubuntu"
      private_key = file("${path.module}/mysensu.pem")
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo rm /etc/sensu/agent.yml",
      "sudo cp /tmp/backend.yaml /etc/sensu/agent.yml"
    ]

     connection {
      type        = "ssh"
      host        = self.public_ip
      user        = "ubuntu"
      private_key = file("${path.module}/mysensu.pem")
    }
  }

  user_data=<<-EOF
            #!/bin/sh
            echo "starting the sensu-agent" >> /tmp/track.txt
            sudo systemctl start sensu-agent
            sudo systemctl enable sensu-agent
            sleep 60
            sudo systemctl restart sensu-agent
            echo "restarted the sensu-agent" >> /tmp/track.txt
            EOF

  depends_on = [aws_instance.sensu-master]

  tags = {
    Name = "sensu-node"
  }
}


resource "aws_security_group" "sensu-master-sg" {
  name        = "sensu-master-sg"
  description = "sensu-master Security Group"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_security_group" "sensu-node-sg" {
  name        = "sensu-node-sg"
  description = "sensu-node Security Group"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3031
    to_port     = 3031
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8125
    to_port     = 8125
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}