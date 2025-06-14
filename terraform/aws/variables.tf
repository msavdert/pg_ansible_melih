variable "region" {
  description = "AWS region to deploy resources."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "A name for the project, used to prefix resource names."
  type        = string
  default     = "pg-project"
}

variable "environment" {
  description = "Deployment environment (e.g., dev, test, prod)."
  type        = string
  default     = "dev"
}

variable "common_tags" {
  description = "Common tags to apply to all resources."
  type        = map(string)
  default     = {}
}

# VPC Configuration Variables
variable "create_vpc" {
  description = "Whether to create a new VPC. If false, existing VPC resources must be specified."
  type        = bool
  default     = true
}

variable "vpc_cidr_block" {
  description = "CIDR block for the new VPC. Used if create_vpc is true."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets. Used if create_vpc is true."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"] # Example for two AZs
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets (for RDS). Used if create_vpc is true."
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"] # Example for two AZs
}

variable "availability_zones" {
  description = "List of Availability Zones to use for subnets. Should match the number of subnet CIDRs. e.g. [\"us-west-2a\", \"us-west-2b\"]"
  type        = list(string)
  default     = [] # If empty, data source will be used to pick AZs based on region.
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC."
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in the VPC."
  type        = bool
  default     = true
}

# RDS Specific Variables
variable "db_instance_class" {
  description = "The instance type of the RDS instance."
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "The allocated storage in gigabytes."
  type        = number
  default     = 20
}

variable "db_engine_version" {
  description = "The PostgreSQL engine version."
  type        = string
  default     = "16" # Ensure this is a valid and supported version
}

variable "db_name" {
  description = "The name of the initial database to create (optional)."
  type        = string
  default     = "postgresdb" # PostgreSQL default is often 'postgres' or null to not create one initially
}

variable "db_username" {
  description = "The master username for the RDS instance."
  type        = string
  default     = "pgadmin"
}

variable "db_password_override" {
  description = "Override for the master password. If empty, a random one is generated. Sensitive."
  type        = string
  default     = ""
  sensitive   = true
}

variable "db_parameter_group_name" {
  description = "Name of the DB parameter group to associate. If empty, uses default."
  type        = string
  default     = "" # e.g., "default.postgres16"
}

variable "db_subnet_group_name" {
  description = "Name of the DB subnet group. Required if deploying in VPC and not creating a new one with private_subnet_ids."
  type        = string
  default     = null # e.g., "my-custom-db-subnet-group"
}

variable "vpc_security_group_ids" {
  description = "List of VPC security group IDs. Used if create_vpc is false or if you want to attach additional SGs."
  type        = list(string)
  default     = [] # e.g., [\"sg-xxxxxxxxxxxxxxxxx\"]
}

variable "private_subnet_ids_for_db_group" {
  description = "List of existing private subnet IDs to create a new DB subnet group if db_subnet_group_name is not provided and create_vpc is false."
  type        = list(string)
  default     = [] # e.g., [\"subnet-xxxxxxxxxxxxxxxxx\", \"subnet-yyyyyyyyyyyyyyyyy\"]
}

variable "skip_final_snapshot" {
  description = "Determines whether a final DB snapshot is created before the DB instance is deleted."
  type        = bool
  default     = true # Set to false for production
}

variable "publicly_accessible" {
  description = "Bool to control if instance is publicly accessible."
  type        = bool
  default     = false # Recommended to be false for production
}

variable "multi_az" {
  description = "Specifies if the RDS instance is multi-AZ."
  type        = bool
  default     = false # Consider true for production
}

variable "storage_type" {
  description = "Storage type for RDS. gp2, gp3, io1 etc."
  type        = string
  default     = "gp3"
}

variable "iops" {
  description = "The amount of Provisioned IOPS (input/output operations per second) to be initially allocated for the DB instance. Only applies to io1 storage type."
  type        = number
  default     = null # e.g., 1000
}

variable "max_allocated_storage" {
  description = "The upper limit to which Amazon RDS can automatically scale the storage of the DB instance."
  type        = number
  default     = null # e.g., 1000 (GB)
}

variable "deletion_protection" {
  description = "If the DB instance should have deletion protection enabled."
  type        = bool
  default     = false # Set to true for production
}
