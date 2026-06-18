# =================================================================
# 1. NETWORKING ARCHITECTURE GRID (VPC LAYER)
# =================================================================

resource "aws_vpc" "production_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "${var.environment}-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.production_vpc.id
  tags   = { Name = "${var.environment}-igw" }
}

# Distributed Availability Zone Subnets for High Availability
resource "aws_subnet" "public_az1" {
  vpc_id            = aws_vpc.production_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags              = { Name = "${var.environment}-public-az1" }
}

resource "aws_subnet" "public_az2" {
  vpc_id            = aws_vpc.production_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}b"
  map_public_ip_on_launch = true
  tags              = { Name = "${var.environment}-public-az2" }
}

# Routing Infrastructure Mapping
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.production_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.environment}-public-rt" }
}

resource "aws_route_table_association" "az1_assoc" {
  subnet_id      = aws_subnet.public_az1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "az2_assoc" {
  subnet_id      = aws_subnet.public_az2.id
  route_table_id = aws_route_table.public_rt.id
}

# =================================================================
# 2. CONTAINER REGISTRY CLUSTERS (ECR LAYER)
# =================================================================

resource "aws_ecr_repository" "frontend" {
  name                 = "express-frontend-prod"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # Allows clean teardown during terraform destroy
  image_scanning_configuration { scan_on_push = false }
}

resource "aws_ecr_repository" "backend" {
  name                 = "flask-backend-prod"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  image_scanning_configuration { scan_on_push = false }
}

# =================================================================
# 3. FIREWALL / ROUTING POLICY ASSIGNMENTS (SECURITY GROUPS)
# =================================================================

resource "aws_security_group" "alb_sg" {
  name        = "tute-alb-security-group"
  description = "Manage inbound public web traffic loops"
  vpc_id      = aws_vpc.production_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
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

resource "aws_security_group" "ecs_tasks_sg" {
  name        = "tute-ecs-tasks-security-group"
  description = "Isolate container port mapping pathways"
  vpc_id      = aws_vpc.production_vpc.id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.alb_sg.id] # Only accessible via the Load Balancer
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# =================================================================
# 4. LOAD BALANCING INFRASTRUCTURE (ALB LAYER)
# =================================================================

resource "aws_lb" "external_alb" {
  name               = "tute-production-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_az1.id, aws_subnet.public_az2.id]
}

# Target Groups for routing traffic to specific containers
resource "aws_lb_target_group" "frontend_tg" {
  name        = "frontend-target-link"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.production_vpc.id
  target_type = "ip" # Required for ECS Fargate network modes

  health_check {
    path                = "/"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }
}

resource "aws_lb_target_group" "backend_tg" {
  name        = "backend-target-link"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.production_vpc.id
  target_type = "ip"

  health_check {
    path                = "/api/submit" # Maps to your Flask backend validation endpoint
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-404" # Accommodates dynamic proxy variations
  }
}

# ALB Listener Routing Matrices
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.external_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_tg.arn # Defaults to loading the UI
  }
}

# Pattern-based routing rules to split frontend and backend traffic on Port 80
resource "aws_lb_listener_rule" "api_routing" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"] # Routes any request containing '/api/' directly to Flask
    }
  }
}

# =================================================================
# 5. ORCHESTRATION ENGINE (ECS FARGATE LAYER)
# =================================================================

resource "aws_ecs_cluster" "cluster" {
  name = "tute-microservices-cluster"
}

# Execution Role enabling Fargate to pull runtime images from ECR
resource "aws_iam_role" "ecs_execution_role" {
  name = "tute_ecs_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_attach" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task Definitions: Blueprints for launching your application containers
resource "aws_ecs_task_definition" "frontend_task" {
  family                   = "frontend-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([{
    name      = "frontend-container"
    image     = "${aws_ecr_repository.frontend.repository_url}:latest"
    essential = true
    portMappings = [{
      containerPort = 3000
      hostPort      = 3000
    }]
    environment = [
      { name = "BACKEND_URL", value = "http://${aws_lb.external_alb.dns_name}/api/submit" }
    ]
  }])
}

resource "aws_ecs_task_definition" "backend_task" {
  family                   = "backend-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([{
    name      = "backend-container"
    image     = "${aws_ecr_repository.backend.repository_url}:latest"
    essential = true
    portMappings = [{
      containerPort = 5000
      hostPort      = 5000
    }]
  }])
}

# ECS Services: Launches and maintains running task instances inside our subnets
resource "aws_ecs_service" "frontend_service" {
  name            = "frontend-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.frontend_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_az1.id, aws_subnet.public_az2.id]
    security_groups  = [aws_security_group.ecs_tasks_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend_tg.arn
    container_name   = "frontend-container"
    container_port   = 3000
  }
}

resource "aws_ecs_service" "backend_service" {
  name            = "backend-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.backend_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_az1.id, aws_subnet.public_az2.id]
    security_groups  = [aws_security_group.ecs_tasks_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend_tg.arn
    container_name   = "backend-container"
    container_port   = 5000
  }
}

# =================================================================
# AUTOMATED CLOUD BUILD WORKER (TEMPORARY)
# =================================================================

# 1. IAM Instance Profile giving the worker direct rights to push to ECR
resource "aws_iam_role" "worker_role" {
  name = "tute_worker_ecr_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "worker_ecr_attach" {
  role       = aws_iam_role.worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

resource "aws_iam_instance_profile" "worker_profile" {
  name = "tute_worker_instance_profile"
  role = aws_iam_role.worker_role.name
}

# 2. The Build Server that pulls your Git repo, builds the images, and pushes to ECR
resource "aws_instance" "build_worker" {
  ami                  = "ami-0522ab6e1ddcc7055" # Verified Mumbai Ubuntu AMI
  instance_type        = "t2.micro"
  subnet_id            = aws_subnet.public_az1.id
  vpc_security_group_ids = [aws_security_group.ecs_tasks_sg.id]
  iam_instance_profile = aws_iam_instance_profile.worker_profile.name

  user_data = <<-EOF
              #!/bin/bash
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
              
              apt-get update
              apt-get install -y docker.io git awscli
              systemctl start docker
              
              # Clone repository
              cd /home/ubuntu
              git clone https://github.com/Abhisingh7710/Docker-Fundamentals.git
              cd Docker-Fundamentals
              
              # Native, unblocked AWS login inside the cloud infrastructure
              aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin ${aws_ecr_repository.backend.repository_url}
              
              # Build and push backend
              cd backend
              docker build -t flask-backend-prod .
              docker tag flask-backend-prod:latest ${aws_ecr_repository.backend.repository_url}:latest
              docker push ${aws_ecr_repository.backend.repository_url}:latest
              
              # Build and push frontend
              cd ../frontend
              docker build -t express-frontend-prod .
              docker tag express-frontend-prod:latest ${aws_ecr_repository.frontend.repository_url}:latest
              docker push ${aws_ecr_repository.frontend.repository_url}:latest
              
              echo "==> Cloud Build Worker Complete <=="
              EOF

  tags = { Name = "Tute-Cloud-Build-Worker" }
}