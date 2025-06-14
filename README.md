# Ansible PostgreSQL Management

This project provides a structured Ansible setup for managing PostgreSQL databases across multiple projects and environments (e.g., production, testing). It supports both on-premise PostgreSQL instances (managed via SSH) and managed cloud PostgreSQL services (like AWS RDS).

## Prerequisites

*   Ansible (latest version recommended)
*   `community.postgresql` Ansible collection:
    ```sh
    ansible-galaxy collection install community.postgresql
    ```
*   `psycopg2-binary` Python library on the Ansible control node:
    ```sh
    pip install psycopg2-binary
    ```
*   SSH access configured for on-premise servers if you are managing them.
*   For AWS RDS or other managed services, ensure your Ansible control node has the necessary credentials (e.g., AWS credentials configured for Boto3) and network access to the database endpoints.

## Project Structure

```
pg_ansible_melih/
├── ansible.cfg                 # Ansible configuration file
├── README.md                   # This documentation
├── playbooks/                  # Contains Ansible playbooks
│   ├── install.yml             # Playbook for installing PostgreSQL (on-premise)
│   ├── manage.yml              # Playbook for managing DBs, users, schemas, etc.
│   └── ssh.yml                 # Playbook for SSH key distribution (on-premise)
├── projects/                   # Root directory for all managed projects
│   └── root/                   # Template project, copy this for new projects
│       ├── on_premise_vars.yml # Example variables for on-premise setups
│       ├── rds_vars.yml        # Example variables for RDS/managed setups
│       └── inventory/
│           ├── hosts                   # Inventory file (YAML format)
│           ├── group_vars/
│           │   ├── prod/
│           │   │   ├── vars.yml        # Non-sensitive variables for 'prod'
│           │   │   └── vault.yml       # Encrypted sensitive variables for 'prod'
│           │   └── test/
│           │       ├── vars.yml        # Non-sensitive variables for 'test'
│           │       └── vault.yml       # Encrypted sensitive variables for 'test'
│           └── host_vars/              # Optional: For host-specific overrides
│               └── host1/
│                   ├── vars.yml
│                   └── vault.yml
└── roles/                      # Contains Ansible roles
    ├── postgresql_managed/     # Role for managing cloud/managed PostgreSQL
    │   ├── defaults/main.yml
    │   └── tasks/
    │       ├── database.yml
    │       ├── main.yml
    │       ├── ping.yml
    │       └── schema.yml
    └── postgresql_on_premise/  # Role for managing on-premise PostgreSQL
        ├── defaults/main.yml
        ├── handlers/main.yml
        └── tasks/
            ├── alter_system.yml
            ├── database.yml
            ├── hba.yml
            ├── install.yml
            ├── main.yml
            ├── node.yml
            ├── ping.yml
            ├── restart.yml
            ├── schema.yml
            └── user.yml
        └── templates/
            ├── chrony.conf.j2
            └── pg_hba.conf.j2
```

## Core Concepts

### Project-Scoped Configuration
Each distinct deployment or client (e.g., "awsrds", "capitalone") is treated as a "project" within the `projects/` directory. All configuration, including inventory, variables, and vault secrets, is self-contained within its respective project folder.

### Environment Variables for Project Context
To target a specific project, set the following environment variables in your shell:
```sh
export PROJECT_NAME="your_project_name" # e.g., "awsrds" or "capitalone"
export ANSIBLE_INVENTORY="projects/${PROJECT_NAME}/inventory"
export ANSIBLE_VAULT_PASSWORD_FILE="projects/${PROJECT_NAME}/.vault_password"
```

### Inventory `hosts` File (YAML Format)
Located at `projects/${PROJECT_NAME}/inventory/hosts`, this file defines your PostgreSQL instances and their groupings.

**Key host variables:**
*   `ansible_host`: The IP address or FQDN of the PostgreSQL server or RDS endpoint.
*   `db_type`: Critical for role selection.
    *   `managed`: For RDS or similar services. Tasks run with `ansible_connection: local`.
    *   `onprem`: For self-hosted PostgreSQL. Tasks typically use SSH.
*   `ansible_connection`:
    *   `local`: For `managed` db_type, as tasks execute on the Ansible control node.
    *   Typically omitted for `onprem` to use default SSH, or set explicitly (e.g., `ssh`).
*   `ansible_user`: SSH user for `onprem` instances.

**Example for an AWS RDS project (`projects/awsrds/inventory/hosts`):**
```yaml
---
prod:
  hosts:
    pgrdsp01:
      ansible_host: 172.28.5.61 # RDS Endpoint
      db_type: managed
      ansible_connection: local
    pgrdsp02:
      ansible_host: 172.28.5.62 # RDS Endpoint
      db_type: managed
      ansible_connection: local

test:
  hosts:
    pgrdst01:
      ansible_host: 172.28.5.71 # RDS Endpoint
      db_type: managed
      ansible_connection: local
    # ... other test hosts

all:
  children:
    prod:
    test:
```

**Example for an On-Premise project (`projects/capitalone/inventory/hosts`):**
```yaml
---
prod:
  hosts:
    pg01:
      ansible_host: 172.28.5.11
      db_type: onprem
      # ansible_user: your_ssh_user # Define if not using default
    pg02:
      ansible_host: 172.28.5.12
      db_type: onprem

test:
  hosts:
    pg03:
      ansible_host: 172.28.5.13
      db_type: onprem

# It's good practice to group by role/type if you have mixed db_types
# or other distinctions within prod/test.
# For this structure, 'postgresql' group might be redundant if all hosts are pg.
postgresql: # This group name is used in some example playbooks
  children:
    prod:
    test:
```

### Group Variables (`group_vars`)
Define common variables for host groups (like `prod` or `test`) within `projects/${PROJECT_NAME}/inventory/group_vars/`.

*   **Non-Sensitive (`vars.yml`)**: `projects/${PROJECT_NAME}/inventory/group_vars/<group>/vars.yml`
    ```yaml
    # Example: projects/awsrds/inventory/group_vars/prod/vars.yml
    pg_database: postgres       # Default DB for connection
    pg_port: 5432
    dba_user: postgres          # Master user for RDS or admin user for on-prem
    # Variables for database creation, schemas, etc.
    postgresql_databases:
      - name: my_app_db
        owner: "{{ dba_user }}" # or a specific app owner user
    postgresql_schemas:
      - name: app_schema
        login_db: my_app_db
        owner: "{{ dba_user }}"
    ```

*   **Sensitive (`vault.yml`)**: `projects/${PROJECT_NAME}/inventory/group_vars/<group>/vault.yml` (Encrypted)
    ```yaml
    # Example content (before encryption):
    # projects/awsrds/inventory/group_vars/prod/vault.yml
    dba_pass: "your_rds_master_password_or_onprem_admin_password"
    ```

### Host Variables (`host_vars`) - Optional
For host-specific overrides: `projects/${PROJECT_NAME}/inventory/host_vars/<hostname>/vars.yml` (and `vault.yml` for sensitive data).

## Secret Management with Ansible Vault

1.  **Vault Password File**: Each project requires a `.vault_password` file in its root (e.g., `projects/awsrds/.vault_password`).
    ```sh
    echo "your_strong_project_specific_vault_password" > "projects/${PROJECT_NAME}/.vault_password"
    chmod 600 "projects/${PROJECT_NAME}/.vault_password"
    ```
    **Important**: Add `projects/*/.vault_password` to your main `.gitignore` file.

2.  **Set `ANSIBLE_VAULT_PASSWORD_FILE`**: This environment variable must point to the project's vault password file. (See "Environment Variables for Project Context" section).

3.  **Encrypting/Editing Vault Files**:
    ```sh
    # Encrypt a new or modified vault file
    ansible-vault encrypt "${ANSIBLE_INVENTORY}/group_vars/prod/vault.yml"
    ansible-vault encrypt "${ANSIBLE_INVENTORY}/group_vars/test/vault.yml"

    # Edit an existing encrypted vault file
    ansible-vault edit "${ANSIBLE_INVENTORY}/group_vars/prod/vault.yml"
    ```

## Setting Up a New Project

1.  **Define Project Name and Set Environment Variables**:
    ```sh
    export PROJECT_NAME="newproject" # Choose a descriptive name
    export ANSIBLE_INVENTORY="projects/${PROJECT_NAME}/inventory"
    export ANSIBLE_VAULT_PASSWORD_FILE="projects/${PROJECT_NAME}/.vault_password"
    ```

2.  **Copy Template Project**:
    ```sh
    cp -r projects/root/ "projects/${PROJECT_NAME}"
    ```
    This copies the `on_premise_vars.yml` and `rds_vars.yml` examples, and the inventory structure. You will customize these.

3.  **Create and Secure Vault Password File**:
    ```sh
    echo "a_very_strong_password_for_${PROJECT_NAME}" > "${ANSIBLE_VAULT_PASSWORD_FILE}"
    chmod 600 "${ANSIBLE_VAULT_PASSWORD_FILE}"
    echo "Created vault password file: ${ANSIBLE_VAULT_PASSWORD_FILE}"
    ```

4.  **Customize Inventory (`projects/${PROJECT_NAME}/inventory/hosts`)**:
    ```sh
    vi "${ANSIBLE_INVENTORY}/hosts"
    ```
    Populate with your actual server details, ensuring `db_type` and `ansible_connection` are set correctly.

5.  **Customize Group Variables**:
    *   Adapt `projects/${PROJECT_NAME}/on_premise_vars.yml` or `projects/${PROJECT_NAME}/rds_vars.yml` as a reference for your actual `vars.yml` and `vault.yml` files.
    *   Edit `vars.yml` for `prod` and `test` groups:
        ```sh
        vi "${ANSIBLE_INVENTORY}/group_vars/prod/vars.yml"
        vi "${ANSIBLE_INVENTORY}/group_vars/test/vars.yml"
        ```
    *   Edit and encrypt `vault.yml` for `prod` and `test` groups:
        ```sh
        ansible-vault edit "${ANSIBLE_INVENTORY}/group_vars/prod/vault.yml" # Add sensitive data
        # Repeat for test: ansible-vault edit "${ANSIBLE_INVENTORY}/group_vars/test/vault.yml"
        # Ensure they are encrypted if newly created/edited without encryption initially
        ansible-vault encrypt "${ANSIBLE_INVENTORY}/group_vars/prod/vault.yml"
        ansible-vault encrypt "${ANSIBLE_INVENTORY}/group_vars/test/vault.yml"
        ```

## Common Operations and Playbook Usage

Always ensure your `PROJECT_NAME`, `ANSIBLE_INVENTORY`, and `ANSIBLE_VAULT_PASSWORD_FILE` environment variables are correctly set for the target project before running playbooks.

### 1. On-Premise PostgreSQL Specific Operations (`db_type: onprem`)

#### a. SSH Key Setup (First-time for new on-premise hosts)
This playbook helps distribute an SSH key for passwordless Ansible access.
```sh
# Generate a new SSH key pair for the project if you don't have one
ssh-keygen -b 2048 -t rsa -f "projects/${PROJECT_NAME}/sshkey_${PROJECT_NAME}" -N ""

# Distribute the public key (prompts for root password of target servers)
ansible-playbook -k -u root -e "ansible_user=root public_key_file=projects/${PROJECT_NAME}/sshkey_${PROJECT_NAME}.pub" playbooks/ssh.yml -l <your_onprem_group_or_host>
# After this, Ansible should connect as the user specified in inventory (or default) using the key.
```
Update your inventory for on-premise hosts to use the new key and appropriate `ansible_user`.
```yaml
# projects/${PROJECT_NAME}/inventory/hosts example snippet
# ...
    pg01:
      ansible_host: 172.28.5.11
      db_type: onprem
      ansible_user: your_ansible_user # User for whom the SSH key was authorized
      ansible_private_key_file: "projects/${PROJECT_NAME}/sshkey_${PROJECT_NAME}"
# ...
```

#### b. Install PostgreSQL
Uses the `playbooks/install.yml` playbook, which leverages the `postgresql_on_premise` role.
```sh
# Install PostgreSQL (e.g., on all hosts in 'test' group with db_type: onprem)
ansible-playbook playbooks/install.yml -l test
# To target a specific version, define 'postgresql_version' in your vars.yml
# Example: projects/capitalone/inventory/group_vars/test/vars.yml
# postgresql_version: "17"
```
**Verify Installation:**
```sh
# Example for 'capitalone' project, assuming pg01, pg02, pg03 are Docker containers
for i in pg01 pg02 pg03; do
  docker exec -it -u postgres $i psql -c "SELECT version();"
done
```

#### c. Alter System Configurations (`postgresql.conf`)
Uses the `pg_alter_system` tag within `playbooks/manage.yml`.
Define parameters in `vars.yml` under `postgresql_alter_system_params`.
```yaml
# Example: projects/capitalone/inventory/group_vars/prod/vars.yml
# postgresql_alter_system_params:
#   max_connections: 130
#   shared_buffers: '240MB'
#   listen_addresses: '*'
```
Run the playbook:
```sh
ansible-playbook playbooks/manage.yml --tags pg_alter_system -l prod
```
**Note**: A PostgreSQL restart is usually required for these changes to take effect.

#### d. Restart PostgreSQL
Uses the `pg_restart` tag within `playbooks/manage.yml`.
```sh
ansible-playbook playbooks/manage.yml --tags pg_restart -l prod
# Force restart if needed (e.g., if checks prevent it)
ansible-playbook playbooks/manage.yml --tags pg_restart -e "postgresql_allow_restart=true" -l prod
```

#### e. Manage Users
Uses the `pg_user` (or more specific like `pg_user_create`) tag within `playbooks/manage.yml`.
Define users in `vars.yml` under `postgresql_users`.
```yaml
# Example: projects/capitalone/inventory/group_vars/prod/vars.yml
# postgresql_users:
#   - name: "{{ dba_user }}" # dba_user from vars.yml
#     password: "{{ dba_pass }}" # dba_pass from vault.yml
#     role_attr_flags: "SUPERUSER"
#     comment: "DBA user"
#     expires: "infinity"
#     conn_limit: 10
```
Run the playbook:
```sh
ansible-playbook playbooks/manage.yml --tags pg_user -l prod
# Or ansible-playbook playbooks/manage.yml --tags pg_user_create -l prod
```

#### f. Manage HBA Entries (`pg_hba.conf`)
Uses the `pg_hba` tag within `playbooks/manage.yml`.
Define entries in `vars.yml` under `postgresql_hba_entries`.
```yaml
# Example: projects/capitalone/inventory/group_vars/prod/vars.yml
# postgresql_hba_entries:
#   - { type: host, database: all, user: "{{ dba_user }}", address: '172.28.5.10/32', auth_method: "{{ postgresql_default_auth_method | default('scram-sha-256') }}" }
```
Run the playbook:
```sh
ansible-playbook playbooks/manage.yml --tags pg_hba -l prod
```

### 2. Managed PostgreSQL (e.g., AWS RDS) Specific Operations (`db_type: managed`)

These operations typically use the `postgresql_managed` role via `playbooks/manage.yml`.

#### a. Ping/Check Connectivity
Uses the `pg_ping` tag.
```sh
ansible-playbook playbooks/manage.yml --tags pg_ping
# Limit to a specific group if needed
ansible-playbook playbooks/manage.yml --tags pg_ping -l prod
```

#### b. Manage Databases
Uses the `pg_database` tag (or `pg_db` in older versions/your notes).
Define databases in `vars.yml` under `postgresql_databases`.
```yaml
# Example: projects/awsrds/inventory/group_vars/prod/vars.yml
# postgresql_databases:
#   - name: testdb
#     owner: "{{ dba_user }}" # Or a specific application owner
#   - name: testmelih
#     owner: "{{ dba_user }}"
```
Run the playbook:
```sh
ansible-playbook playbooks/manage.yml --tags pg_database -l prod
```

#### c. Manage Schemas
Uses the `pg_schema` tag.
Define schemas in `vars.yml` under `postgresql_schemas`.
```yaml
# Example: projects/awsrds/inventory/group_vars/prod/vars.yml
# postgresql_schemas:
#   - name: testdb_schema
#     login_db: testdb # Database where this schema should be created
#     owner: "{{ dba_user }}"
#   - name: testmelih_schema
#     login_db: testmelih
#     owner: "{{ dba_user }}"
```
Run the playbook:
```sh
ansible-playbook playbooks/manage.yml --tags pg_schema -l prod
```

#### d. Backup (Dump) Database
The `postgresql_databases` variable supports a `state: dump` for creating backups.
```yaml
# Example: projects/awsrds/inventory/group_vars/all/vars.yml (or specific group)
# postgresql_databases:
#   - name: exampledb # The database to dump
#     state: dump
#     target: "/tmp/{{ ansible_host }}-exampledb.sql" # Output file on control node
#   # For compressed backup:
#   - name: anotherdb
#     state: dump
#     target: "/tmp/{{ ansible_host }}-anotherdb.sql.gz"
```
Run the playbook (ensure the tag matches your `database.yml` task in `postgresql_managed` role, likely `pg_database` or `pg_db`):
```sh
ansible-playbook playbooks/manage.yml --tags pg_database -l <target_rds_host_or_group>
```
Verify backup files in the specified `target` path on your Ansible control machine.

#### e. Restore Database
The `postgresql_databases` variable supports `state: restore`.
```yaml
# Example: projects/awsrds/inventory/host_vars/pgrdsp01/vars.yml
# postgresql_databases:
#   - name: exampledb-restore # New database name to restore into
#     state: restore
#     target: "/tmp/172.28.5.61-exampledb.sql.gz" # Path to backup file on control node
#     owner: "{{ dba_user }}" # Owner of the new restored database
```
Run the playbook:
```sh
ansible-playbook playbooks/manage.yml --tags pg_database -l pgrdsp01
```

### 3. Common Operations (Applicable to both `onprem` and `managed` where relevant)

The tasks for creating databases and schemas are generally similar for both `db_type` and are handled by `playbooks/manage.yml` using the `pg_database` and `pg_schema` tags respectively. The roles (`postgresql_on_premise` and `postgresql_managed`) contain the specific implementations.

## Roles

*   **`postgresql_managed`**: For cloud-based/managed PostgreSQL. Tasks include:
    *   `ping.yml`: Connectivity check.
    *   `database.yml`: Create, drop, dump, restore databases.
    *   `schema.yml`: Create, drop schemas.
    *   (User management can also be added here if distinct from on-premise needs)
*   **`postgresql_on_premise`**: For self-hosted PostgreSQL. Tasks include:
    *   `install.yml`: Install PostgreSQL packages.
    *   `node.yml`: Node preparation (e.g., time, packages - if used from a common role).
    *   `hba.yml`: Manage `pg_hba.conf`.
    *   `alter_system.yml`: Manage `postgresql.conf` settings.
    *   `user.yml`: Manage users and roles.
    *   `database.yml`: Manage databases.
    *   `schema.yml`: Manage schemas.
    *   `restart.yml`: Restart PostgreSQL service.
    *   `ping.yml`: Connectivity check.

## Infrastructure Provisioning with Terraform

This project also includes capabilities for provisioning PostgreSQL infrastructure on cloud providers using Terraform. These Terraform configurations are located in the `terraform/` directory and are designed to be used as templates for creating new project-specific infrastructure.

For detailed information on how to use Terraform for provisioning, please refer to the [Terraform specific README](./terraform/README.md).

The general idea is to:
1. Use a Terraform template (e.g., from `terraform/aws/` or `terraform/azure/`) to create your PostgreSQL instance.
2. Use the outputs from Terraform (like database endpoint, port) to configure your Ansible inventory for that project.
3. Use the Ansible playbooks in this project to perform fine-grained configuration management, database setup, user creation, etc., on the Terraform-provisioned instances.

## Important Considerations

*   **Idempotency**: Playbooks are designed to be idempotent.
*   **Security**:
    *   Protect `.vault_password` files and never commit them.
    *   Use strong, unique passwords.
*   **Testing**: Test in non-production environments first.
*   **Variable Precedence**: Ansible's standard variable precedence applies.
*   **Role `defaults/main.yml` vs. `vars.yml`**: Role defaults provide base values. Inventory `vars.yml` (group or host) override these. The `on_premise_vars.yml` and `rds_vars.yml` in `projects/root` are comprehensive examples to draw from when creating your actual inventory vars.
