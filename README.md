# Ansible PostgreSQL Management

This project provides a structured way to manage PostgreSQL databases for multiple projects and environments (production, testing) using Ansible. It supports both on-premise PostgreSQL instances and managed cloud services (e.g., AWS RDS, Azure PostgreSQL). Secrets are managed using project-specific Ansible Vault files.

## Project Structure

```
pg_ansible/
├── ansible.cfg
├── .gitignore
├── .vault_password  # Contains the password for Ansible Vault (ensure it's secured and gitignored if real)
├── inventory/
│   └── abc/             # Template project, copy this for new projects
│       ├── hosts.ini    # Inventory for all environments of the 'abc' project
│       ├── vault.yml    # Encrypted secrets for the 'abc' project
│       └── host_vars/   # Host-specific variables for 'abc'
│           └── pgdbt01.yml # Example for host 'pgdbt01'
├── playbooks/
│   ├── install_postgresql.yml # Playbook for installing/setting up PostgreSQL
│   └── manage_postgresql.yml  # Playbook for managing databases, users, permissions
├── roles/
│   ├── postgresql_on_premise/ # Role for managing on-premise PostgreSQL
│   │   ├── tasks/main.yml
│   │   ├── defaults/main.yml
│   │   └── vars/main.yml
│   └── postgresql_managed/    # Role for managing cloud PostgreSQL
│       ├── tasks/main.yml
│       ├── defaults/main.yml
│       └── vars/main.yml
└── README.md
```

## Prerequisites

*   Ansible installed.
*   `community.postgresql` Ansible collection: `ansible-galaxy collection install community.postgresql`
*   `psycopg2-binary` Python library on the Ansible control node: `pip install psycopg2-binary`
*   SSH access configured for on-premise servers if you are managing them.
*   Cloud provider CLI tools/SDKs if managing cloud PostgreSQL instances (e.g., AWS CLI, Azure CLI).

## Setup

1.  **Clone the Repository (or set up based on this structure).**
2.  **Configure Vault Password for Each Project:**
    *   Create a `.vault_password` file inside each project's inventory directory (e.g., `inventory/abc/.vault_password`).
    *   Put the Ansible Vault password for that specific project into this file.
    *   **Important:** For production, use a strong, unique password. Ensure this file is appropriately secured and added to `.gitignore` if it contains actual passwords and you intend to commit other parts of the inventory.
3.  **Install Ansible Collections:**
    ```bash
    ansible-galaxy collection install community.postgresql
    ```
4.  **Install Python Dependencies:**
    ```bash
    pip install psycopg2-binary
    ```

## Inventory Configuration

The inventory is structured per project. The `inventory/abc/` directory serves as a template.

### `inventory/<project_name>/hosts.ini`

This file defines your hosts and groups them by environment. The type of database (on-premise or managed) is specified using the `db_type` variable for each host.

**Example for `inventory/abc/hosts.ini`:**

```ini
# inventory/abc/hosts.ini
# Consolidated inventory for the ABC project

#-------------------------------------------------------------------------------
# Production Environment
#-------------------------------------------------------------------------------
[prod]
# Example on-premise server for Prod, replace with your actual server details
# pgdbt01 ansible_host=192.168.1.100 ansible_user=your_ssh_user ansible_private_key_file=~/.ssh/id_rsa_pg db_type=on_premise
# Example managed database for Prod
# rds_prod_main ansible_host=abc-prod-rds.xxxxxxxxxx.us-east-1.rds.amazonaws.com db_name=abc_prod_db db_type=managed

#-------------------------------------------------------------------------------
# Test Environment
#-------------------------------------------------------------------------------
[test]
# Example on-premise server for Test
# pgdbt02 ansible_host=192.168.1.101 ansible_user=your_ssh_user ansible_private_key_file=~/.ssh/id_rsa_pg db_type=on_premise
# Example managed database for Test
# rds_test_secondary ansible_host=abc-test-rds.yyyyyyyyyy.us-east-1.rds.amazonaws.com db_name=abc_test_db db_type=managed

#-------------------------------------------------------------------------------
# Common variables for the project (optional)
#-------------------------------------------------------------------------------
# [all:vars] # Use [all:vars] for variables applicable to all hosts in this inventory file.
# project_specific_var = "value_for_abc"
```

*   Replace placeholders with your actual hostnames, IP addresses, and cloud DB identifiers.
*   `ansible_host` is used for SSH connections to on-premise servers.
*   `db_instance_identifier`, `db_engine` (or similar like `db_name`) are examples for managed services; adapt as needed for your cloud provider.
*   `db_type` must be set to either `on_premise` or `managed`.

### `inventory/<project_name>/host_vars/<hostname>.yml`

Define host-specific variables here. For example, `inventory/abc/host_vars/pgdbt01.yml`:

```yaml
# inventory/abc/host_vars/pgdbt01.yml
ansible_user: your_ssh_user
ansible_private_key_file: /path/to/your/ssh/key.pem
# Add any other specific vars for this host
# postgresql_version: "14" # If specific to this host
```

For managed database instances, you might not need many host_vars if connection details are handled via `group_vars` (within the project inventory, e.g. `inventory/abc/group_vars/prod.yml`) and the project's `vault.yml`.

### `inventory/<project_name>/vault.yml` (Project-Specific Secrets)

This file stores encrypted secrets for a specific project (e.g., database user passwords for the `abc` project).

**Example content (before encryption):** `inventory/abc/vault.yml`
```yaml
# inventory/abc/vault.yml
pg_users:
  - name: app_user
    password: "VERY_STRONG_PASSWORD_FOR_APP"
  - name: readonly_user
    password: "STRONG_READONLY_PASSWORD"

# Admin password for managed instances, if applicable for this project
# vault_pg_admin_password: "MANAGED_INSTANCE_ADMIN_PASSWORD"

# Example of how you might store user details if using the project_vars structure
# vault_app_user_name: "actual_app_user_for_project"
# vault_app_user_password: "ENCRYPTED_PASSWORD_HASH_OR_PLAIN_TEXT_TO_BE_HASHED_BY_MODULE"
# vault_readonly_user_name: "actual_readonly_user_for_project"
# vault_readonly_user_password: "ENCRYPTED_PASSWORD_HASH_OR_PLAIN_TEXT_FOR_READONLY"
```
Encrypt this file using the project-specific vault password file:
`ansible-vault encrypt inventory/abc/vault.yml --vault-password-file inventory/abc/.vault_password`

## Roles

### `postgresql_on_premise`
Manages PostgreSQL instances on servers where you have SSH access.
*   **Tasks:** Pinging the server, ensuring PostgreSQL service is running (installation part), creating databases, users, and managing permissions (management part).
*   **Variables:** Defined in `roles/postgresql_on_premise/defaults/main.yml` and `roles/postgresql_on_premise/vars/main.yml`. Can be overridden in inventory `host_vars` or project-level `group_vars` (e.g. `inventory/abc/group_vars/prod.yml`).

**Key variables for `postgresql_on_premise` (defaults/main.yml):**
```yaml
# roles/postgresql_on_premise/defaults/main.yml
pg_port: 5432
# pg_databases, pg_users, pg_permissions are now expected to be passed via project_vars
# in the manage_postgresql.yml playbook, or directly if install_postgresql.yml is adapted.

# postgresql_version: "13" # Specify if needed for specific setups
# postgresql_data_dir: "/var/lib/postgresql/{{ postgresql_version }}/main" # Adjust if non-standard
# postgresql_service_name: "postgresql" # Varies by OS/distribution
```

### `postgresql_managed`
Manages PostgreSQL instances provided by cloud services (e.g., AWS RDS, Azure Database for PostgreSQL).
*   **Tasks:** Pinging the instance (if applicable, often just connection test), creating databases, users, and managing permissions via the PostgreSQL protocol. Instance creation/deletion is assumed to be out of scope for these roles.
*   **Variables:** Defined in `roles/postgresql_managed/defaults/main.yml` and `roles/postgresql_managed/vars/main.yml`.

**Key variables for `postgresql_managed` (defaults/main.yml):**
```yaml
# roles/postgresql_managed/defaults/main.yml
pg_port: 5432
pg_admin_user: postgres # Or the admin user for your managed service
pg_admin_password: "{{ vault_pg_admin_password }}" # Should be in project's vault.yml
# pg_databases, pg_users, pg_permissions are now expected to be passed via project_vars
# ssl_mode: "require" # Example, set based on your managed service requirements
```
You'll need to ensure `vault_pg_admin_password` (or a similar variable for the admin password of the managed instance) is defined in the project's `vault.yml` file (e.g., `inventory/abc/vault.yml`).

## Playbooks

Generic playbooks are located in the `playbooks/` directory. They load secrets from `{{ inventory_dir }}/vault.yml`.

### `playbooks/install_postgresql.yml`
This playbook is used for initial setup or installation of PostgreSQL on on-premise servers. For managed services, this playbook might only ensure connectivity.

```yaml
# playbooks/install_postgresql.yml
---
- name: "Install PostgreSQL on On-Premise Servers"
  hosts: all # Relies on --limit to target specific hosts/groups
  gather_facts: yes
  vars_files:
    - "{{ inventory_dir }}/vault.yml" # Loads project-specific vault

  roles:
    - role: postgresql_on_premise
      when: db_type == 'on_premise' # Apply only to on-premise hosts
  tasks:
    - name: Ping all targeted hosts
      ansible.builtin.ping:
```

### `playbooks/manage_postgresql.yml`
This playbook is used for ongoing management tasks like creating databases, users, and permissions. It uses the `db_type` variable to decide which role to apply.

```yaml
# playbooks/manage_postgresql.yml
---
- name: Manage PostgreSQL databases, users, and permissions
  hosts: all # Target hosts via -l flag and inventory groups (e.g., prod, test)
  become: yes # May be needed for on-premise depending on pg_hba.conf
  vars_files:
    - "{{ inventory_dir }}/vault.yml" # Loads project-specific vault
  roles:
    - role: postgresql_on_premise
      vars:
        pg_databases: "{{ project_vars.databases | default([]) }}"
        pg_users: "{{ project_vars.users | default([]) }}"
        pg_permissions: "{{ project_vars.permissions | default([]) }}"
      when: db_type == 'on_premise'

    - role: postgresql_managed
      vars:
        pg_databases: "{{ project_vars.databases | default([]) }}"
        pg_users: "{{ project_vars.users | default([]) }}"
        pg_permissions: "{{ project_vars.permissions | default([]) }}"
        # pg_admin_user and pg_admin_password should be defined in role defaults
        # or overridden in inventory (e.g., group_vars/prod.yml for the project)
        # and sourced from the project's vault.yml
      when: db_type == 'managed'
  tasks:
    - name: Placeholder task to show playbook ran
      ansible.builtin.debug:
        msg: "Finished managing PostgreSQL on {{ inventory_hostname }} (type: {{ db_type }})"

```
**Note on `project_vars`**: The `manage_postgresql.yml` playbook expects database, user, and permission definitions to come from a variable named `project_vars`. This variable should be defined in your inventory, typically in a group_vars file specific to the project and environment. For example, `inventory/abc/group_vars/prod.yml` (you'd need to create this file and directory structure if you want to use it like this):

Create `inventory/abc/group_vars/prod.yml` and `inventory/abc/group_vars/test.yml`:
```yaml
# Example: inventory/abc/group_vars/prod.yml
project_vars:
  databases:
    - name: "app_prod_db"
    - name: "reporting_prod_db"
  users:
    # Reference names/passwords from inventory/abc/vault.yml
    - name: "{{ vault_app_user_name | default('app_user') }}"
      password: "{{ vault_app_user_password }}"
      encrypted: yes # Assuming password from vault is already a hash if needed by postgresql_user module
    - name: "{{ vault_readonly_user_name | default('readonly_user') }}"
      password: "{{ vault_readonly_user_password }}"
      encrypted: yes
  permissions:
    - db: "app_prod_db"
      user: "{{ vault_app_user_name | default('app_user') }}"
      priv: "ALL"
    - db: "reporting_prod_db"
      user: "{{ vault_readonly_user_name | default('readonly_user') }}"
      priv: "SELECT"
    - db: "app_prod_db" # Grant connect to app user
      user: "{{ vault_app_user_name | default('app_user') }}"
      priv: "CONNECT"
    - db: "reporting_prod_db" # Grant connect to readonly user
      user: "{{ vault_readonly_user_name | default('readonly_user') }}"
      priv: "CONNECT"

# And in inventory/abc/vault.yml, you'd have corresponding entries like:
# vault_app_user_name: "actual_app_user_for_abc" (optional, if different from default)
# vault_app_user_password: "ENCRYPTED_PASSWORD_HASH_OR_PLAIN_TEXT_TO_BE_HASHED_BY_MODULE"
# vault_readonly_user_name: "actual_readonly_user_for_abc" (optional)
# vault_readonly_user_password: "ENCRYPTED_PASSWORD_HASH_OR_PLAIN_TEXT_FOR_READONLY"
```

## Running Playbooks

1.  **Vault Password File:**
    *   When running `ansible-playbook`, you now need to specify the path to the project's vault password file using the `--vault-password-file` argument.

2.  **Targeting Specific Projects and Environments:**

    Use the `-i` flag to specify the project's inventory directory and `-l` to limit to specific hosts or groups (e.g., `prod`, `test`, or a specific hostname).

    **Example: Manage 'abc' project's production databases:**
    ```bash
    ansible-playbook playbooks/manage_postgresql.yml \
        -i inventory/abc/ \
        -l prod \
        --vault-password-file inventory/abc/.vault_password
    ```

    **Example: Manage 'abc' project's test databases:**
    ```bash
    ansible-playbook playbooks/manage_postgresql.yml \
        -i inventory/abc/ \
        -l test \
        --vault-password-file inventory/abc/.vault_password
    ```

    **Example: Install PostgreSQL on a specific on-premise server in 'abc' project's test environment:**
    Assume `pgdbt02` is in `inventory/abc/hosts.ini` under the `[test]` group with `db_type=on_premise`.
    ```bash
    ansible-playbook playbooks/install_postgresql.yml \
        -i inventory/abc/ \
        -l pgdbt02 \
        --vault-password-file inventory/abc/.vault_password \
        --become
    ```
    (Add `--become` if sudo/root privileges are needed for installation tasks).

## Adding a New Project (e.g., 'newproj')

1.  **Copy the Template:**
    Duplicate the `inventory/abc/` directory and rename it to `inventory/newproj/`.
    ```bash
    cp -r inventory/abc/ inventory/newproj/
    ```

2.  **Customize Inventory (`inventory/newproj/hosts.ini`):**
    *   Open `inventory/newproj/hosts.ini`.
    *   Update hostnames, IP addresses, `db_type`, and any specific variables for `newproj`. The group names (`prod`, `test`) can remain the same as they are now scoped by the inventory directory.

3.  **Create and Customize Vault Password File (`inventory/newproj/.vault_password`):**
    *   Create a new file `inventory/newproj/.vault_password`.
    *   Add the vault password for `newproj` into this file.
    *   Ensure it's secured and gitignored appropriately.

4.  **Customize Vault (`inventory/newproj/vault.yml`):**
    *   If the previous `inventory/abc/vault.yml` was encrypted, you'll need to decrypt it first to copy and modify, or start fresh.
        *   To decrypt (if needed, make a backup first): `ansible-vault decrypt inventory/abc/vault.yml --vault-password-file inventory/abc/.vault_password`
    *   Copy `inventory/abc/vault.yml` to `inventory/newproj/vault.yml` (if you decrypted it) or create a new `inventory/newproj/vault.yml`.
    *   Update the secrets within `inventory/newproj/vault.yml` for the `newproj` project.
    *   Encrypt the new vault file using its own password file:
        `ansible-vault encrypt inventory/newproj/vault.yml --vault-password-file inventory/newproj/.vault_password`

5.  **Customize Host Variables (`inventory/newproj/host_vars/`):**
    *   Rename or create new YAML files in `inventory/newproj/host_vars/` corresponding to the hostnames defined in `inventory/newproj/hosts.ini`.
    *   Update the variables within these files.

6.  **Run Playbooks for the New Project:**
    Use the same `ansible-playbook` commands as above, but change the inventory path and the vault password file path:
    ```bash
    ansible-playbook playbooks/manage_postgresql.yml \
        -i inventory/newproj/ \
        -l prod \
        --vault-password-file inventory/newproj/.vault_password
    ```

## Secret Management with Ansible Vault

*   **Project-Specific Secrets:** `inventory/<project_name>/vault.yml` stores secrets like database user passwords for that specific project.
*   **Vault Password File:** Each project has its own `.vault_password` file located in its inventory directory (e.g., `inventory/abc/.vault_password`). This file must be specified using `--vault-password-file` when running `ansible-playbook` or `ansible-vault` commands.
*   **Encryption:**
    *   Encrypt: `ansible-vault encrypt inventory/<project_name>/vault.yml --vault-password-file inventory/<project_name>/.vault_password`
    *   Decrypt: `ansible-vault decrypt inventory/<project_name>/vault.yml --vault-password-file inventory/<project_name>/.vault_password`
    *   Edit: `ansible-vault edit inventory/<project_name>/vault.yml --vault-password-file inventory/<project_name>/.vault_password`
*   **Security:** **Ensure each `.vault_password` file is secured and not committed to version control if it contains a real password.** For CI/CD, consider using environment variables or other secure methods to provide the vault password for the specific project being targeted.

## Important Considerations

*   Idempotency: Roles and playbooks should be written to be idempotent.
*   Security: Regularly rotate passwords, limit permissions, secure `.vault_password` files, and configure `pg_hba.conf` securely.
*   Error Handling & Testing: Implement robust error handling and test thoroughly.
*   Cloud Provider Specifics: Adapt roles for specific cloud provider commands if managing infrastructure beyond DB users/permissions.
*   **`ansible.cfg`**: The global `vault_password_file` setting in `ansible.cfg` has been removed. You must now use the `--vault-password-file` command-line option.

This `README.md` reflects the changes to vault password management.
