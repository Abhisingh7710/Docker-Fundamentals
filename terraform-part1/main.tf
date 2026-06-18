# 1. Create a Custom Security Group for Network Traffic Management
resource "aws_security_group" "monolith_sg" {
  name        = "tute-monolith-sg"
  description = "Allow inbound configurations for SSH, Express, and Flask services"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH admin access"
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Express Node Web frontend access"
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Flask Python Backend API access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Unrestricted outbound link access"
  }
}

# 2. Provision the Single EC2 Monolith Instance
resource "aws_instance" "monolith_server" {
  # Directly using the official Canonical Ubuntu 24.04 LTS AMI ID for us-east-1
  ami                    = "ami-0522ab6e1ddcc7055"
  instance_type          = var.instance_type
  # key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.monolith_sg.id]

  # Automated User Data Configuration Management Script
  user_data = <<-EOF
              #!/bin/bash
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
              
              echo "==> Starting Automated Provisioning Pipeline <=="
              apt-get update
              
              # Install Node.js 18 runtime, Python pip, venv, and Git tools
              curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
              apt-get install -y nodejs python3-pip python3-venv git
              
              # Clone repository into the default server path
              cd /home/ubuntu
              git clone https://github.com/Abhisingh7710/Docker-Fundamentals.git
              cd Docker-Fundamentals
              
              # Dynamically determine the machine's external IP to map routing parameters
              PUBLIC_IP=$(curl -s ifconfig.me)
              export BACKEND_URL="http://$PUBLIC_IP:5000/api/submit"
              echo "export BACKEND_URL='http://$PUBLIC_IP:5000/api/submit'" >> /home/ubuntu/.bashrc
              
              # Build Backend Service dependencies and launch Flask background worker
              cd backend
              python3 -m venv venv
              source venv/bin/activate
              pip install -r requirements.txt
              nohup python3 app.py > flask.log 2>&1 &
              deactivate
              cd ..
              
              # Build Frontend dependencies and launch Express server background worker
              cd frontend
              npm install
              nohup node server.js > node.log 2>&1 &
              
              echo "==> Architecture Deployment Matrix Completed Successfully <=="
              EOF

  tags = {
    Name = "Terraform-Monolith-Server"
  }
}

# 3. Return the public entry endpoint tracking variable upon execution
output "instance_public_ip" {
  value       = aws_instance.monolith_server.public_ip
  description = "The dynamic public IPv4 address assigned by AWS"
}