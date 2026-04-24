# Terraform Modules

Modularized infrastructure components for each service in the end-to-end data engineering pipeline.

## Pre-requisites
- **Terraform** environment initialized.

## Folder Structure
```text
.
├── dms                           <-- Replication instance and endpoints
├── glue                          <-- Spark jobs, Catalog, and JDBC connections
├── iam                           <-- Shared service roles and policies
├── lambda                        <-- Data generator and build packaging
├── rds                           <-- Source database (Binary Logging enabled)
├── redshift                      <-- RA3 warehouse and SCD logic initialization
├── s3                            <-- Data Lake storage with prefix-level security
├── step_functions                <-- Orchestration state machine
├── vpc                           <-- Network foundation and PrivateLink endpoints
└── README.md
```

## Modular Design
Each module is designed for independent testing and follows the **Principle of Least Privilege**, with security groups and IAM roles tightly scoped to their respective services.
