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
This command triggers the Flyway migrations and configures the necessary binlog retention for CDC replication.
