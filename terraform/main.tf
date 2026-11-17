data "aws_caller_identity" "current" {}
data "aws_ssm_parameter" "ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}
locals {
  name = "devops-${var.environment}"
}
resource "aws_vpc" "app" {
  cidr_block           = "10.42.0.0/24"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = local.name }
}
resource "aws_subnet" "app" {
  vpc_id                  = aws_vpc.app.id
  cidr_block              = "10.42.0.0/26"
  map_public_ip_on_launch = true
  tags                    = { Name = local.name }
}
resource "aws_internet_gateway" "app" { vpc_id = aws_vpc.app.id }
resource "aws_route_table" "app" {
  vpc_id = aws_vpc.app.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.app.id
  }
}
resource "aws_route_table_association" "app" {
  subnet_id      = aws_subnet.app.id
  route_table_id = aws_route_table.app.id
}
resource "aws_security_group" "app" {
  name_prefix = "${local.name}-"
  description = "Approved app clients only; administration uses SSM, never SSH"
  vpc_id      = aws_vpc.app.id
}
resource "aws_vpc_security_group_ingress_rule" "app" {
  for_each          = toset(var.application_cidrs)
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = each.value
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
  description       = "Approved application clients"
}
resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "SSM, registry, CloudWatch and HTTPS OS package repositories"
}
resource "aws_cloudwatch_log_group" "app" {
  name              = "/devops-assessment/${var.environment}/app"
  retention_in_days = var.log_retention_days
}
resource "aws_ecr_repository" "app" {
  name                 = "devops-assessment-${var.environment}"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "AES256" }
  # Deliberately false: cleanup must explicitly remove assessment images after approval.
  force_delete = false
}
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name
  policy = jsonencode({ rules = [{ rulePriority = 1, description = "Retain twenty releases", selection = {
    tagStatus = "any", countType = "imageCountMoreThan", countNumber = 20
  }, action = { type = "expire" } }] })
}
data "aws_iam_policy_document" "instance_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "instance" {
  name_prefix        = "${local.name}-instance-"
  assume_role_policy = data.aws_iam_policy_document.instance_trust.json
}
data "aws_iam_policy_document" "instance" {
  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
    resources = ["${aws_cloudwatch_log_group.app.arn}:*"]
  }
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    actions   = ["ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage"]
    resources = [aws_ecr_repository.app.arn]
  }
  statement {
    actions = ["ssm:UpdateInstanceInformation", "ssmmessages:CreateControlChannel", "ssmmessages:CreateDataChannel",
    "ssmmessages:OpenControlChannel", "ssmmessages:OpenDataChannel"]
    resources = ["*"]
  }
}
resource "aws_iam_role_policy" "instance" {
  role   = aws_iam_role.instance.id
  policy = data.aws_iam_policy_document.instance.json
}
resource "aws_iam_instance_profile" "app" { role = aws_iam_role.instance.name }
resource "aws_instance" "app" {
  ami                         = data.aws_ssm_parameter.ami.value
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.app.id
  vpc_security_group_ids      = [aws_security_group.app.id]
  iam_instance_profile        = aws_iam_instance_profile.app.name
  associate_public_ip_address = true
  user_data_replace_on_change = true
  metadata_options {
    http_tokens                 = "required"
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
  }
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true
    delete_on_termination = true
  }
  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    environment    = var.environment
    region         = var.aws_region
    log_group      = aws_cloudwatch_log_group.app.name
    initial_image  = var.initial_image
    deploy_script  = base64encode(file("${path.module}/../scripts/deploy.sh"))
    health_script  = base64encode(file("${path.module}/../system_health.sh"))
    health_service = base64encode(file("${path.module}/../scripts/system-health.service"))
    health_timer   = base64encode(file("${path.module}/../scripts/system-health.timer"))
  })
  tags       = { Name = local.name, DeploymentTarget = "devops-assessment" }
  depends_on = [aws_iam_role_policy.instance, aws_route_table_association.app]
}
