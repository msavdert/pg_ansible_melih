# Terraform for PostgreSQL Infrastructure

This section of the project provides Terraform configurations to provision PostgreSQL instances on various cloud providers. The goal is to create a repeatable and version-controlled infrastructure setup that can then be managed by the Ansible playbooks in the parent project.

## Structure

Each cloud provider will have its own subdirectory under `terraform/` which serves as a root template for new projects.

```
terraform/
├── aws/                  # Root template for AWS Terraform projects
│   ├── main.tf           # Main Terraform configuration for AWS
│   ├── variables.tf      # Input variables for AWS
│   ├── outputs.tf        # Outputs for AWS (e.g., DB endpoint)
│   └── .gitignore        # Terraform specific gitignore
├── azure/                # Root template for Azure Terraform projects
│   ├── main.tf           # Main Terraform configuration for Azure
│   ├── variables.tf      # Input variables for Azure
│   ├── outputs.tf        # Outputs for Azure
│   └── .gitignore        # Terraform specific gitignore
└── README.md             # This file
```

## General Workflow

1.  **Copy a Cloud Provider Template**: When starting a new infrastructure project for a specific cloud, copy the relevant template directory (e.g., `terraform/aws/`) to a new project-specific location, for example, `projects/<your_ansible_project_name>/terraform/aws/`.
    ```sh
    # Example for an Ansible project named 'myclient_db_project' needing AWS infra
    mkdir -p projects/myclient_db_project/terraform
    cp -r terraform/aws/ projects/myclient_db_project/terraform/aws
    cd projects/myclient_db_project/terraform/aws
    ```

2.  **Customize Variables**:
    *   Modify `variables.tf` to define or adjust default values.
    *   Create a `terraform.tfvars` file (and add it to `.gitignore`) to provide specific values for your deployment (e.g., instance sizes, region, resource names, VPC details).

3.  **Initialize Terraform**:
    ```sh
    terraform init
    ```

4.  **Plan and Apply**:
    ```sh
    terraform plan -out=tfplan
    terraform apply tfplan
    ```

5.  **Use Outputs**: The `outputs.tf` will define important information like the database endpoint, port, and any generated IDs. This information will be crucial for configuring your Ansible inventory (`projects/<your_ansible_project_name>/inventory/hosts`) to manage the provisioned PostgreSQL instance.

## AWS Specifics (Example - `terraform/aws/`)

The `terraform/aws/` template will typically include resources like:
*   `aws_db_instance` or `aws_rds_cluster` for RDS.
*   VPC, subnets, security groups if managing network infrastructure.
*   Parameter groups.

**Example `terraform.tfvars` for AWS:**
```hcl
# projects/<your_ansible_project_name>/terraform/aws/terraform.tfvars

region                = "us-east-1"
project_name          = "myclient-prod"
db_instance_class     = "db.t3.micro"
db_allocated_storage  = 20
db_engine_version     = "16.2" # Check for latest supported versions
db_name               = "myappdb"
db_username           = "adminuser"
# db_password will be prompted or use a secrets manager

# Networking - Example: IDs of existing VPC and subnets
# vpc_id                = "vpc-xxxxxxxxxxxxxxxxx"
# db_subnet_group_name  = "my-existing-db-subnet-group"
# vpc_security_group_ids = ["sg-xxxxxxxxxxxxxxxxx"]
```

## Azure Specifics (Example - `terraform/azure/`)

The `terraform/azure/` template will typically include resources like:
*   `azurerm_postgresql_flexible_server` or `azurerm_postgresql_server`.
*   Resource groups, virtual networks, subnets, and network security groups.

**Example `terraform.tfvars` for Azure:**
```hcl
# projects/<your_ansible_project_name>/terraform/azure/terraform.tfvars

location            = "East US"
project_name        = "myclient-dev"
resource_group_name = "myclient-dev-rg"
pg_server_name      = "myclient-dev-pgserver"
pg_sku_name         = "B_Standard_B1ms" # Basic tier, 1 vCore, 2 GiB RAM
pg_version          = "16" # Check for latest supported versions
pg_storage_mb       = 32768 # 32 GB
pg_admin_login      = "azureuser"
# pg_admin_password will be prompted or use a secrets manager

# Networking - Example: Using new VNet and Subnet
# virtual_network_name = "myclient-dev-vnet"
# subnet_name          = "myclient-dev-pgsubnet"
```

## Integrating with Ansible

After successfully provisioning your PostgreSQL instance with Terraform:
1.  Retrieve the necessary connection details from Terraform outputs (e.g., DB endpoint/hostname, port).
2.  Update your Ansible inventory file (`projects/<your_ansible_project_name>/inventory/hosts`) with this information.
    *   Set `ansible_host` to the Terraform output DB endpoint.
    *   Set `db_type: managed`.
    *   Set `ansible_connection: local`.
3.  Update your Ansible group variables (`vars.yml` and `vault.yml`) with database names, admin usernames, and passwords (the admin password might be the one set during Terraform provisioning or a new one you intend to set/rotate with Ansible).
4.  You can then use the Ansible playbooks (`playbooks/manage.yml`) to perform further database configuration, schema creation, user management, etc., on the Terraform-provisioned instance.

This approach separates infrastructure provisioning (Terraform) from configuration management (Ansible), allowing for a clean and modular setup.
