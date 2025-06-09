# Ansible PostgreSQL Management

This project provides a structured Ansible setup for managing PostgreSQL databases across multiple projects and environments (e.g., production, testing). It supports both on-premise PostgreSQL instances (managed via SSH) and managed cloud PostgreSQL services.

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

## Project Structure

```
pg_ansible/
├── ansible.cfg                 # Ansible configuration file
├── README.md                   # This documentation
├── reinit.sh                   # Utility script (user-defined)
├── playbooks/                  # Contains Ansible playbooks
│   ├── install_postgresql.yml  # Playbook for installing PostgreSQL (primarily on-premise)
│   ├── manage_postgresql.yml   # Playbook for managing DBs, users, permissions
│   └── ssh.yml                 # Playbook for SSH related tasks (e.g., connectivity)
├── projects/                   # Root directory for all managed projects
│   └── root/                   # Template project, copy this for new projects
│       ├── .vault_password     # Placeholder for project's vault password (in actual projects)
│       └── inventory/
│           ├── hosts                   # Inventory file (YAML format)
│           ├── group_vars/
│           │   ├── prod/
│           │   │   ├── vars.yml        # Non-sensitive variables for the 'prod' group
│           │   │   └── vault.yml       # Encrypted sensitive variables for 'prod'
│           │   └── test/
│           │       ├── vars.yml        # Non-sensitive variables for the 'test' group
│           │       └── vault.yml       # Encrypted sensitive variables for 'test'
│           └── host_vars/              # Optional: For host-specific overrides
│               └── host1.example.com/  # Example host
│                   ├── vars.yml        # Non-sensitive variables for this host
│                   └── vault.yml       # Encrypted sensitive variables for this host
└── roles/                      # Contains Ansible roles
    ├── postgresql_managed/     # Role for managing cloud PostgreSQL instances
    │   ├── defaults/main.yml
    │   ├── tasks/main.yml
    │   ├── tasks/ping.yml      # Task for pinging/checking managed DB connectivity
    │   └── vars/main.yml
    └── postgresql_on_premise/  # Role for managing on-premise PostgreSQL
        ├── defaults/main.yml
        ├── tasks/main.yml
        └── vars/main.yml
```

## Core Concepts

### Project-Scoped Inventory and Vault
Each project (e.g., `abc`, `xyz`) resides under the `projects/` directory. The configuration, including inventory and vault secrets, is self-contained within that project's directory.

### Environment Variables for Context
Ansible operations are scoped to a specific project by setting two environment variables:
*   `ANSIBLE_INVENTORY`: Points to the project's inventory directory (e.g., `projects/abc/inventory`).
*   `ANSIBLE_VAULT_PASSWORD_FILE`: Points to the project's vault password file (e.g., `projects/abc/.vault_password`).

### Inventory `hosts` File (YAML Format)
The `hosts` file within each project's inventory directory defines hosts and their group memberships using YAML.

**Example `projects/<project_name>/inventory/hosts`:**
```yaml
---
prod:
  hosts:
    pgrdsp01: # Hostname as it will be known to Ansible
      ansible_host: 172.28.5.61       # Connection target (IP or FQDN)
      db_type: managed               # 'managed' or 'on_premise'
      ansible_connection: local      # For managed DBs, tasks run on control node
    # Add other prod hosts here
  # vars: # Optional: Variables common to all hosts in 'prod' group

test:
  hosts:
    pgrdst01:
      ansible_host: 172.28.5.71
      db_type: managed
      ansible_connection: local
    pgonpremt01:
      ansible_host: 192.168.1.100
      db_type: on_premise
      ansible_user: your_ssh_user   # For on-premise SSH
      # ansible_private_key_file: /path/to/key # Optional for on-premise
  # vars: # Optional: Variables common to all hosts in 'test' group

# Optional: Define parent groups if needed for broader targeting
# all:
#   children:
#     prod:
#     test:
#     # You can also define groups by type if useful
#     managed_servers:
#       hosts:
#         pgrdsp01: # an empty hash is needed if no vars are defined here
#         pgrdst01:
#     on_premise_servers:
#       hosts:
#         pgonpremt01:
```
*   `db_type`: Used by playbooks to determine which role (`postgresql_managed` or `postgresql_on_premise`) to apply.
*   `ansible_connection: local`: Typically used for `managed` database types, as tasks run on the Ansible control node to interact with cloud APIs or database endpoints.
*   For `on_premise` hosts, you'd typically set `ansible_user` and potentially `ansible_private_key_file` or rely on SSH agent/config.

### Group Variables (`group_vars`)
Environment-specific (and other group-specific) variables are defined under `projects/<project_name>/inventory/group_vars/`.

*   **Non-Sensitive Variables**: `projects/<project_name>/inventory/group_vars/<group_name>/vars.yml`
    *   Example for `projects/abc/inventory/group_vars/prod/vars.yml`:
        ```yaml
        # pg_ansible/projects/abc/inventory/group_vars/prod/vars.yml
        pg_database: postgres         # Default database to connect to for some operations
        pg_port: 5432               # PostgreSQL port
        dba_user: postgres_admin    # Admin user for performing database operations
        # Add other non-sensitive prod variables here
        ```

*   **Sensitive Variables (Vaulted)**: `projects/<project_name>/inventory/group_vars/<group_name>/vault.yml`
    *   This file **must** be encrypted using Ansible Vault.
    *   Example for `projects/abc/inventory/group_vars/prod/vault.yml` (before encryption):
        ```yaml
        # pg_ansible/projects/abc/inventory/group_vars/prod/vault.yml
        dba_pass: "prod_admin_password_secret"
        # Add other sensitive prod variables here (e.g., API keys)
        ```

### Host Variables (`host_vars`) - Optional
For variables specific to a single host that override group variables.
*   Non-Sensitive: `projects/<project_name>/inventory/host_vars/<hostname>/vars.yml`
*   Sensitive (Vaulted): `projects/<project_name>/inventory/host_vars/<hostname>/vault.yml`

## Secret Management with Ansible Vault

1.  **Vault Password File**: Each project should have its own `.vault_password` file in its root directory (e.g., `projects/abc/.vault_password`). This file contains the password used to encrypt and decrypt the project's `vault.yml` files.
    *   **Security**: This file should be secured and **never** committed to version control if it contains a real password. Add `projects/*/.vault_password` to your `.gitignore` file.
    *   Create it: `echo "your_strong_vault_password" > projects/abc/.vault_password`
    *   Set permissions: `chmod 600 projects/abc/.vault_password`

2.  **Environment Variable**: Before running playbooks, set `ANSIBLE_VAULT_PASSWORD_FILE` to point to this file.
    ```sh
    export ANSIBLE_VAULT_PASSWORD_FILE=projects/abc/.vault_password
    ```

3.  **Encrypting Vault Files**:
    ```sh
    ansible-vault encrypt projects/abc/inventory/group_vars/prod/vault.yml
    ansible-vault encrypt projects/abc/inventory/group_vars/test/vault.yml
    # Also encrypt any host_vars/<hostname>/vault.yml files
    ```

4.  **Editing Vault Files**:
    ```sh
    ansible-vault edit projects/abc/inventory/group_vars/prod/vault.yml
    ```

5.  **Viewing Vault Files**:
    ```sh
    ansible-vault view projects/abc/inventory/group_vars/prod/vault.yml
    ```

6.  **Rekeying Vault Files** (changing the vault password):
    ```sh
    ansible-vault rekey projects/abc/inventory/group_vars/prod/vault.yml
    ```
    You will be prompted for the old and new vault passwords. Ensure your `projects/abc/.vault_password` file is updated with the new password.

## Adding a New Project (e.g., `my_new_project`)

1.  **Set Up Environment Variables (for the new project context)**:
    It's good practice to define these for your current shell session when working on a specific project.
    ```sh
    export NEW_PROJECT_NAME="my_new_project"
    export ANSIBLE_INVENTORY="projects/${NEW_PROJECT_NAME}/inventory"
    export ANSIBLE_VAULT_PASSWORD_FILE="projects/${NEW_PROJECT_NAME}/.vault_password"
    ```

2.  **Copy the Template Project**:
    The `projects/root/` directory serves as a template.
    ```sh
    cp -r projects/root/ "projects/${NEW_PROJECT_NAME}"
    ```

3.  **Create and Secure Vault Password File**:
    ```sh
    echo "your_new_project_strong_password" > "${ANSIBLE_VAULT_PASSWORD_FILE}"
    chmod 600 "${ANSIBLE_VAULT_PASSWORD_FILE}"
    echo "Created and secured vault password file at: ${ANSIBLE_VAULT_PASSWORD_FILE}"
    ```
    *Remember to add `projects/*/.vault_password` to your main `.gitignore`.*

4.  **Customize Inventory (`projects/${NEW_PROJECT_NAME}/inventory/hosts`)**:
    Edit this file to define your hosts, groups, and connection parameters for the new project. Refer to the YAML example above.
    ```sh
    # Example: Open with your preferred editor
    vi "${ANSIBLE_INVENTORY}/hosts"
    ```

5.  **Customize Group Variables**:
    *   **Production Non-Sensitive Variables**: Edit `projects/${NEW_PROJECT_NAME}/inventory/group_vars/prod/vars.yml`
        ```sh
        vi "${ANSIBLE_INVENTORY}/group_vars/prod/vars.yml"
        # Example content:
        # pg_database: mynewproject_prod_db
        # pg_port: 5432
        # dba_user: mynewproject_admin
        ```
    *   **Production Sensitive Variables (Vault)**: Edit `projects/${NEW_PROJECT_NAME}/inventory/group_vars/prod/vault.yml` (this will create it if it doesn't exist from the template, or edit the template's content).
        ```sh
        # Edit (will be decrypted temporarily if already encrypted, or create new)
        ansible-vault edit "${ANSIBLE_INVENTORY}/group_vars/prod/vault.yml"
        # Example content (before encryption):
        # dba_pass: "prod_password_for_mynewproject"
        ```
        If the file was newly created or modified, ensure it's encrypted:
        ```sh
        ansible-vault encrypt "${ANSIBLE_INVENTORY}/group_vars/prod/vault.yml"
        ```
    *   Repeat for `test` environment variables (`vars.yml` and `vault.yml`).

6.  **Customize Host Variables (Optional)**:
    If you need host-specific overrides, create and edit files in `projects/${NEW_PROJECT_NAME}/inventory/host_vars/`.

## Running Playbooks

1.  **Set Environment Variables**:
    Ensure `ANSIBLE_INVENTORY` and `ANSIBLE_VAULT_PASSWORD_FILE` are set for the project you want to target.
    ```sh
    # Example for 'abc' project
    export ANSIBLE_INVENTORY=projects/abc/inventory
    export ANSIBLE_VAULT_PASSWORD_FILE=projects/abc/.vault_password
    ```

2.  **Execute Playbook**:
    ```sh
    # Example: Run the pg_ping tag from manage_postgresql.yml for project 'abc'
    ansible-playbook playbooks/manage_postgresql.yml --tags pg_ping

    # Example: Run all tasks in manage_postgresql.yml for 'abc' project, targeting only 'prod' group
    ansible-playbook playbooks/manage_postgresql.yml -l prod

    # Example: Install PostgreSQL on 'on_premise' servers in 'test' group for 'abc' project
    ansible-playbook playbooks/install_postgresql.yml -l test_on_premise_servers # Assuming you define such a group
    ```
    *   Use the `-l <limit>` flag to target specific hosts or groups defined in your inventory.
    *   Use `--tags <tag_name>` or `--skip-tags <tag_name>` to control task execution.

## Roles

*   **`postgresql_managed`**: Contains tasks for interacting with managed PostgreSQL services (e.g., AWS RDS, Azure PostgreSQL). Assumes the instance is already provisioned. Tasks typically include database creation, user management, permission granting, and connectivity checks (`ping.yml`).
*   **`postgresql_on_premise`**: Contains tasks for installing, configuring, and managing PostgreSQL on servers where you have SSH access.

## Important Considerations

*   **Idempotency**: Playbooks and roles should be written to be idempotent, meaning they can be run multiple times with the same outcome.
*   **Security**:
    *   Protect your `.vault_password` files.
    *   Use strong, unique passwords for database users and vault encryption.
    *   Regularly review and update vaulted secrets.
*   **Testing**: Thoroughly test playbooks in non-production environments before applying them to production.
*   **Variable Precedence**: Be aware of Ansible's variable precedence rules (e.g., host_vars override group_vars).
