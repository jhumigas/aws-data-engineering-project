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

### Manual Build
If running without the Makefile, execute the following from this directory:
```bash
# 1. Install dependencies to a target folder
uv pip install \
  --no-installer-metadata \
  --no-compile-bytecode \
  --python-platform x86_64-manylinux2014 \
  --python 3.13 \
  --target build/ \
  -r pyproject.toml

# 2. Add handler logic
cp lambda_function.py build/

# 3. Create ZIP archive
cd build && zip -r ../lambda_function.zip .
```
The resulting ZIP is deployed via the Terraform Lambda module.
