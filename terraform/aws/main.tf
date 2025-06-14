terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket-name"
  #   key            = "aws-postgres/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   # dynamodb_table = "your-terraform-state-lock-table" # Optional for state locking
  # }
}

provider "aws" {
  region = var.region
}

# --- VPC --- Conditionally created
data "aws_availability_zones" "available" {
  count = length(var.availability_zones) == 0 ? 1 : 0 # Only query if var.availability_zones is not provided
  state = "available"
}

locals {
  # Use provided AZs or query available ones, ensuring we don't exceed the number of subnet CIDRs
  azs = length(var.availability_zones) > 0 ? slice(var.availability_zones, 0, min(length(var.availability_zones), length(var.public_subnet_cidrs), length(var.private_subnet_cidrs))) : slice(data.aws_availability_zones.available[0].names, 0, min(length(data.aws_availability_zones.available[0].names), length(var.public_subnet_cidrs), length(var.private_subnet_cidrs)))
}

resource "aws_vpc" "main" {
  count = var.create_vpc ? 1 : 0

  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-vpc"
    }
  )
}

# --- Internet Gateway for Public Subnets --- Conditionally created
resource "aws_internet_gateway" "gw" {
  count = var.create_vpc ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-igw"
    }
  )
}

# --- Public Subnets --- Conditionally created
resource "aws_subnet" "public" {
  count = var.create_vpc ? length(var.public_subnet_cidrs) : 0

  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index % length(local.azs)] # Cycle through AZs
  map_public_ip_on_launch = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-public-subnet-${count.index + 1}"
    }
  )
}

# --- Private Subnets (for RDS) --- Conditionally created
resource "aws_subnet" "private" {
  count = var.create_vpc ? length(var.private_subnet_cidrs) : 0

  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index % length(local.azs)] # Cycle through AZs
  map_public_ip_on_launch = false

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-private-subnet-${count.index + 1}"
    }
  )
}

# --- Route Table for Public Subnets --- Conditionally created
resource "aws_route_table" "public" {
  count = var.create_vpc ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw[0].id
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-public-rtb"
    }
  )
}

resource "aws_route_table_association" "public" {
  count = var.create_vpc ? length(aws_subnet.public) : 0

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# --- DB Subnet Group --- Uses created private subnets or provided ones
resource "aws_db_subnet_group" "default" {
  # Create if create_vpc is true OR if db_subnet_group_name is null and private_subnet_ids_for_db_group is provided
  count = var.create_vpc || (var.db_subnet_group_name == null && length(var.private_subnet_ids_for_db_group) > 0) ? 1 : 0

  name = var.db_subnet_group_name != null && !var.create_vpc ? var.db_subnet_group_name : "${var.project_name}-rds-sng"
  subnet_ids = var.create_vpc ? aws_subnet.private[*].id : var.private_subnet_ids_for_db_group

  tags = merge(
    var.common_tags,
    {
      Name = var.db_subnet_group_name != null && !var.create_vpc ? var.db_subnet_group_name : "${var.project_name}-rds-sng"
    }
  )
}

# --- Security Group for RDS --- Conditionally created or uses provided
resource "aws_security_group" "rds_sg" {
  count = var.create_vpc ? 1 : 0 # Create a new SG only if creating a new VPC

  name        = "${var.project_name}-rds-sg"
  description = "Allow PostgreSQL inbound traffic for RDS"
  vpc_id      = aws_vpc.main[0].id

  ingress {
    description     = "PostgreSQL from VPC"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    cidr_blocks     = [aws_vpc.main[0].cidr_block] # Allow from within the VPC
    # For more restrictive access, use specific security group IDs or IP ranges.
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-rds-sg"
    }
  )
}

# --- Random Password for DB ---
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

# --- RDS Instance --- Updated to use conditional VPC resources
resource "aws_rds_instance" "default" {
  identifier             = "${var.project_name}-rds-pg"
  allocated_storage      = var.db_allocated_storage
  engine                 = "postgres"
  engine_version         = var.db_engine_version
  instance_class         = var.db_instance_class
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password_override != "" ? var.db_password_override : random_password.db_password.result
  parameter_group_name   = var.db_parameter_group_name # No longer checking for empty string here, let AWS handle default if null
  db_subnet_group_name   = aws_db_subnet_group.default[0].name # Always use the created/referenced one
  vpc_security_group_ids = var.create_vpc ? [aws_security_group.rds_sg[0].id] : var.vpc_security_group_ids

  skip_final_snapshot    = var.skip_final_snapshot
  final_snapshot_identifier = "${var.project_name}-rds-pg-final-snapshot-${formatdate("YYYYMMDDHHmmss", timestamp())}"
  publicly_accessible  = var.publicly_accessible
  multi_az               = var.multi_az
  storage_type           = var.storage_type
  # iops                   = var.storage_type == "io1" ? var.iops : null # Only for io1 storage type
  # max_allocated_storage  = var.max_allocated_storage # For storage autoscaling

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-rds-pg"
      Project     = var.project_name
      Environment = var.environment
    }
  )

  # Deletion protection should ideally be true for production
  deletion_protection = var.deletion_protection
}

# Example: Create a new DB subnet group if one is not provided
# This resource is now handled above with conditional logic based on var.create_vpc
# resource "aws_db_subnet_group" "default" {
#   count = var.db_subnet_group_name == null && length(var.private_subnet_ids) > 0 ? 1 : 0
# 
#   name       = "${var.project_name}-rds-subnet-group"
#   subnet_ids = var.private_subnet_ids
# 
#   tags = merge(
#     var.common_tags,
#     {
#       Name = "${var.project_name}-rds-subnet-group"
#     }
#   )
# }

# Note: For a production setup, you would typically use existing VPC, subnets, and security groups,
# or create them as part of a more comprehensive Terraform configuration.
# This example assumes they might be provided as variables.
# If vpc_security_group_ids is empty, you might want to create a default one.
