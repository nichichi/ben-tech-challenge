terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

# NETWORK RESOURCES
# 
resource "aws_vpc" "network" {
  cidr_block = var.cidr
}

resource "aws_internet_gateway" "network" {
  vpc_id = aws_vpc.network.id
}

resource "aws_subnet" "public1" {
  vpc_id = aws_vpc.network.id
  cidr_block = var.public1Cidr
  availability_zone = var.availabilityZoneA
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public2" {
  vpc_id = aws_vpc.network.id
  cidr_block = var.public2Cidr
  availability_zone = var.availabilityZoneB
  map_public_ip_on_launch = true
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.network.id
}

resource "aws_route" "public" {
  route_table_id = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.network.id
}

resource "aws_route_table_association" "public1" {
  subnet_id = aws_subnet.public1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public2" {
  subnet_id = aws_subnet.public2.id
  route_table_id = aws_route_table.public.id
}

# # Uncomment lines 54-94 to build private subnets and nat gateway
# resource "aws_subnet" "private1" {
#   vpc_id = aws_vpc.network.id
#   cidr_block = var.private1Cidr
#   availability_zone = var.availabilityZoneA
# }

# resource "aws_subnet" "private2" {
#   vpc_id = aws_vpc.network.id
#   cidr_block = var.private2Cidr
#   availability_zone = var.availabilityZoneB
# }
#
# resource "aws_nat_gateway" "natgw" {
#   allocation_id = aws_eip.natgw.id
#   subnet_id     = aws_subnet.public1.id
#   depends_on = [aws_internet_gateway.network]
# }

# resource "aws_eip" "natgw" {
#   vpc = true
# }

# resource "aws_route_table" "private" {
#   vpc_id = aws_vpc.network.id
# }

# resource "aws_route" "private" {
#   route_table_id = aws_route_table.private.id
#   destination_cidr_block = "0.0.0.0/0"
#   nat_gateway_id = aws_nat_gateway.natgw.id
# }

# resource "aws_route_table_association" "private1" {
#   subnet_id = aws_subnet.private1.id
#   route_table_id = aws_route_table.private.id
# }

# resource "aws_route_table_association" "private2" {
#   subnet_id = aws_subnet.private2.id
#   route_table_id = aws_route_table.private.id
# }


# SECURITY GROUPS
#
resource "aws_security_group" "alb" {
  name = "${var.appname}-${var.environment}-sg-alb"
  description = "Allow HTTP inbound traffic"
  vpc_id = aws_vpc.network.id
}

resource "aws_security_group_rule" "alb-ingress" {
  type = "ingress"
  protocol = "tcp"
  from_port = var.albPort
  to_port = var.albPort
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb-egress" {
  type = "egress"
  protocol = "tcp"
  from_port = var.containerPort
  to_port = var.containerPort
  security_group_id = aws_security_group.alb.id
  source_security_group_id = aws_security_group.ecs.id
}

resource "aws_security_group" "ecs" {
  name = "${var.appname}-${var.environment}-sg-ecs"
  description = "Allow HTTP inbound traffic"
  vpc_id = aws_vpc.network.id
}

resource "aws_security_group_rule" "ecs-ingress" {
  type = "ingress"
  protocol = "tcp"
  from_port = var.containerPort
  to_port = var.containerPort
  security_group_id = aws_security_group.ecs.id
  source_security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "ecs-egress" {
  type = "egress"
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ecs.id
}

# ECS RESOURCES
#
resource "aws_ecs_cluster" "ecs" {
  name = "${var.appname}-${var.environment}-ecs-cluster"
}


data "template_file" "main" {
  template = "${file("${path.module}/task_definition.json")}"

  vars = {
    image = var.dockerRepo
    appname = var.appname
    environment = var.environment
    cpu = var.cpu
    memory = var.memory
    port = var.containerPort
  }
}


resource "aws_ecs_task_definition" "ecs" {
  family = "health-api"
  container_definitions = data.template_file.main.rendered
  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"
  cpu = var.cpu
  memory = var.memory
  execution_role_arn = aws_iam_role.ecs.arn
}

resource aws_iam_role ecs {
  name = "ecsTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.ecs.json
}

data "aws_iam_policy_document" ecs {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_ecs_service" "ecs"{
  name = "healthapi"
  cluster = aws_ecs_cluster.ecs.id
  task_definition = aws_ecs_task_definition.ecs.arn
  desired_count = 1
  launch_type = "FARGATE"
  
  network_configuration {
    security_groups  = [aws_security_group.ecs.id]
    subnets = [aws_subnet.public1.id,aws_subnet.public2.id] #For private subnets use [aws_subnet.private1.id,aws_subnet.private2.id]
    assign_public_ip = var.publicIp
  }
  
  load_balancer {
    target_group_arn = aws_alb_target_group.alb.arn
    container_name = "${var.appname}-${var.environment}-ecs-health-api"
    container_port = var.containerPort
  }
  
}

# LOAD BALANCER RESOURCES
#
resource "aws_lb" "alb" {
  name = "${var.appname}-${var.environment}-alb"
  load_balancer_type = "application"
  security_groups = [aws_security_group.alb.id]
  subnets = [aws_subnet.public1.id,aws_subnet.public2.id]
}

resource "aws_alb_target_group" "alb" {
  name = "${var.appname}-${var.environment}-alb-tg"
  port        = var.containerPort
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.network.id
  
  health_check {
    healthy_threshold = "5"
    interval = "30"
    protocol = "HTTP"
    matcher = "200"
    path = "/health"
    unhealthy_threshold = "3"
    timeout = 25
  }
}

resource "aws_alb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = var.albPort
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.alb.arn
  }
}