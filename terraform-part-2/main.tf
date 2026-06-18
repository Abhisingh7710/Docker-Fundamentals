# =================================================================
# 1. NETWORK SECURITY CONFIGURATION (FIREWALL MASKS)
# =================================================================

# Security Group for the Backend Python Flask Server
resource "aws_security_group" "backend_sg" {
  name        = "tute-backend-sg"
  description = "Allow administrative access and Flask API processing hooks"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH admin access"
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allows client-side browsers and the frontend instance to reach the API
    description = "Flask API port access link"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Unrestricted outbound execution loops"
  }
}

# Security Group for the Frontend Node.js Express Server
resource "aws_security_group" "frontend_sg" {
  name        = "tute-frontend-sg"
  description = "Allow administrative access and public web traffic links"

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
    description = "Express Web frontend entry dashboard hook"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Unrestricted outbound execution loops"
  }
}

# =================================================================
# 2. COMPUTE COMPONENT PROVISIONING (COMPUTATION NODES)
# =================================================================

# Node A: Dedicated Flask Backend Engine Instance
resource "aws_instance" "flask_backend_server" {
  ami                    = "ami-0522ab6e1ddcc7055" # Official Retail Mumbai Ubuntu 24.04 AMI
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.backend_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
              
              echo "==> Deploying Isolated Flask Production Core <=="
              apt-get update
              apt-get install -y python3-pip python3-venv git
              
              cd /home/ubuntu
              git clone https://github.com/Abhisingh7710/Docker-Fundamentals.git
              cd Docker-Fundamentals/backend
              
              # Build virtual environment mapping matrix and launch worker thread
              python3 -m venv venv
              source venv/bin/activate
              pip install -r requirements.txt
              nohup python3 app.py > flask.log 2>&1 &
              echo "==> Flask Microservice Operational <=="
              EOF

  tags = {
    Name = "Terraform-Distributed-Backend"
  }
}

# Node B: Dedicated Express Frontend Interface Instance
resource "aws_instance" "express_frontend_server" {
  ami                    = "ami-0522ab6e1ddcc7055" # Official Retail Mumbai Ubuntu 24.04 AMI
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.frontend_sg.id]

  # Dynamic Dependency Link: Waits for the backend server to secure an IP before writing environmental hooks
  user_data = <<-EOF
              #!/bin/bash
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
              
              echo "==> Deploying Isolated Express Interface Core <=="
              apt-get update
              curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
              apt-get install -y nodejs git
              
              cd /home/ubuntu
              git clone https://github.com/Abhisingh7710/Docker-Fundamentals.git
              cd Docker-Fundamentals/frontend
              
              # DYNAMIC ARCHITECTURE LINKAGE:
              # We inject the backend server's dynamic public routing endpoint directly into the runtime variable environment!
              export BACKEND_URL="http://${aws_instance.flask_backend_server.public_ip}:5000/api/submit"
              echo "export BACKEND_URL='http://${aws_instance.flask_backend_server.public_ip}:5000/api/submit'" >> /home/ubuntu/.bashrc
              
              # Install dependencies and start server core
              npm install
              nohup node server.js > node.log 2>&1 &
              echo "==> Express Frontend Interface Operational <=="
              EOF

  tags = {
    Name = "Terraform-Distributed-Frontend"
  }
}

# =================================================================
# 3. INTERFACE OUTPUT REFLECTIONS
# =================================================================

output "frontend_public_url" {
  value       = "http://${aws_instance.express_frontend_server.public_ip}:3000"
  description = "The direct web browser entrance endpoint link"
}

output "backend_api_url" {
  value       = "http://${aws_instance.flask_backend_server.public_ip}:5000"
  description = "The processing infrastructure pipeline endpoint link"
}