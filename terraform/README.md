# Infrastructure as Code (Terraform)

Terraform configuration files and modules used to provision and manage the project's cloud infrastructure.

## Pre-requisites
- **Terraform 1.0+** installed locally.
- **AWS CLI** configured with appropriate credentials.

## Folder Structure
```text
.
├── modules                       <-- Reusable service-specific components
├── docs                          <-- Archived TF-specific documentation
├── main.tf                       <-- Root orchestrator for module calls
├── variables.tf                  <-- Global project inputs and defaults
├── outputs.tf                    <-- Exported resource attributes
├── provider.tf                   <-- AWS provider configuration
└── README.md
```

## Usage
Infrastructure lifecycle is managed through the root control plane:
```bash
make tf-init    # Initialize providers
make tf-plan    # Preview changes
make tf-apply   # Deploy infrastructure
```
The code is extensively documented with inline comments explaining design choices, particularly around security roles and CDC parameters.
