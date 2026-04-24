# Data Generator Lambda

Python-based AWS Lambda function designed to simulate real-time application traffic by generating and inserting sample sales data into the source RDS MySQL database.

## Pre-requisites
- **Python 3.x** and **uv** installed.
- **AWS CLI** configured.

## Folder Structure
```text
.
├── build                         <-- Local build artifacts and packaged ZIP
├── lambda_function.py            <-- Core Lambda handler logic
├── pyproject.toml                <-- Dependency management (uv)
├── uv.lock                       <-- Locked dependency versions
└── README.md
```

## Build & Deployment
Build the deployment package locally using the root control plane:
```bash
make build-lambda
```
The resulting package is automatically deployed via the Terraform Lambda module.
