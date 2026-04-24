# Application Database (RDS MySQL)

Database migration scripts and orchestration logic for the source RDS MySQL instance.

## Pre-requisites
- **Docker** installed locally.
- **RDS Instance** provisioned and accessible.

## Folder Structure
```text
.
├── migration                     <-- SQL migration scripts (Flyway)
│   └── V1__Initial_Schema.sql    <-- Core Table DDLs
└── migrate.sh                    <-- Docker-based Flyway runner
```

## Usage
Migrations are typically applied using the project root control plane:
```bash
make setup-rds
```
This command performs two critical actions:
1. **Flyway Migrations**: Applies the core schema DDLs from the `migration/` folder.
2. **CDC Configuration**: Executes the following command to enable Change Data Capture:
   ```sql
   CALL mysql.rds_set_configuration('binlog retention hours', 24);
   ```
   *Why*: AWS RDS for MySQL normally purges binary logs as soon as possible. This command forces RDS to retain them for 24 hours, giving AWS DMS enough time to read and replicate the changes to S3.

### Manual Setup
To manually run migrations and configuration without the Makefile:

**1. Run Flyway** (Requires Docker):
```bash
# Usage: bash migrate.sh <rds-endpoint> <db-user>
# Ensure FLYWAY_PASSWORD is set in your environment
export FLYWAY_PASSWORD=<your-password>
bash migrate.sh <rds-endpoint> admin
```

**2. Configure CDC** (Any SQL Client):
Connect to the RDS instance and execute:
```sql
CALL mysql.rds_set_configuration('binlog retention hours', 24);
```
