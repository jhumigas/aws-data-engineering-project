# Lambda Packaging with UV Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automate AWS Lambda packaging using `uv` within Terraform to ensure cross-platform (Linux) compatibility and clean dependency management.

**Architecture:** Initialize a `uv` project in the Lambda directory, then use a Terraform `null_resource` to trigger a `uv pip install` targeting the Linux platform before zipping.

**Tech Stack:** Python 3.9, uv, Terraform, AWS Lambda.

---

### Task 1: Initialize UV Project

**Files:**
- Create: `data_generator_lambda/pyproject.toml`

- [ ] **Step 1: Initialize the project with uv**

Run: `uv init --lib` in `data_generator_lambda/`
Expected: `pyproject.toml` and `src/` directory created (we will move things around).

- [ ] **Step 2: Configure pyproject.toml**

Update `data_generator_lambda/pyproject.toml` with required dependencies.

```toml
[project]
name = "data-generator-lambda"
version = "0.1.0"
description = "Simulates data generation for an e-commerce application"
readme = "README.md"
requires-python = ">=3.9"
dependencies = [
    "mysql-connector-python>=9.0.0",
    "Faker>=20.0.0",
]

[tool.uv]
managed = true
```

- [ ] **Step 3: Generate lockfile**

Run: `uv lock` in `data_generator_lambda/`
Expected: `uv.lock` file created.

- [ ] **Step 4: Commit**

```bash
git add data_generator_lambda/pyproject.toml data_generator_lambda/uv.lock
git commit -m "chore: initialize uv project for lambda"
```

---

### Task 2: Automate Build in Terraform

**Files:**
- Modify: `terraform/modules/lambda/main.tf`

- [ ] **Step 1: Add build resource to Terraform**

Update `terraform/modules/lambda/main.tf` to include the `null_resource` for building.

```hcl
resource "null_resource" "lambda_build" {
  triggers = {
    pyproject_hash = filemd5("${path.module}/../../../data_generator_lambda/pyproject.toml")
    lock_hash      = filemd5("${path.module}/../../../data_generator_lambda/uv.lock")
    lambda_hash    = filemd5("${path.module}/../../../data_generator_lambda/lambda_function.py")
  }

  provisioner "local-exec" {
    command = <<EOT
      cd ${path.module}/../../../data_generator_lambda
      rm -rf build
      mkdir -p build
      uv pip install -r pyproject.toml \
        --target build/ \
        --python-platform x86_64-unknown-linux-gnu \
        --python-version 3.9 \
        --only-binary=:all:
      cp lambda_function.py build/
    EOT
  }
}
```

- [ ] **Step 2: Update archive_file to use build directory**

Modify the `archive_file` data source to depend on the build resource and use the `build/` directory.

```hcl
data "archive_file" "lambda_zip" {
  depends_on  = [null_resource.lambda_build]
  type        = "zip"
  source_dir  = "${path.module}/../../../data_generator_lambda/build/"
  output_path = "${path.module}/lambda_function.zip"
}
```

- [ ] **Step 3: Commit**

```bash
git add terraform/modules/lambda/main.tf
git commit -m "feat: automate lambda build with uv in terraform"
```

---

### Task 3: Cleanup and Verification

**Files:**
- Remove: `data_generator_lambda/package/`
- Remove: `data_generator_lambda/six.py`
- Remove: `data_generator_lambda/*.pth`

- [ ] **Step 1: Run Terraform build locally**

Run: `terraform plan` in `terraform/`
Expected: Shows `null_resource.lambda_build` being created/updated.

- [ ] **Step 2: Verify build artifacts**

Check `data_generator_lambda/build/` for `mysql`, `faker`, and `lambda_function.py`.

- [ ] **Step 3: Remove legacy files**

```bash
rm -rf data_generator_lambda/package
rm data_generator_lambda/six.py
rm data_generator_lambda/*.pth
```

- [ ] **Step 4: Final Commit**

```bash
git add data_generator_lambda/
git commit -m "cleanup: remove legacy lambda package files"
```
