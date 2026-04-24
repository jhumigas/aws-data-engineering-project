# Step Functions Orchestration

Original Amazon States Language (ASL) reference for the ETL pipeline orchestrator.

## Pre-requisites
- **Step Functions Role** with Glue and Redshift Data API permissions.

## Folder Structure
```text
.
├── state_machine.json            <-- Raw ASL definition (Reference)
└── README.md
```

## Implementation
While this directory contains the reference definition, the active orchestration logic is managed via the **Terraform Step Functions module**, which implements a sequential flow optimized for referential integrity:
1. Parallel Dimension Processing (Customer/Product).
2. Redshift Merge (Stored Procedures).
3. Parallel Fact Processing (Orders/OrderDetails).
