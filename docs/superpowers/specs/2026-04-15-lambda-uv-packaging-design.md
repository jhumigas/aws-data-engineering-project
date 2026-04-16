# Design Spec: Lambda Packaging with UV

**Date**: 2026-04-15  
**Topic**: Modernizing Lambda dependency management and automation.

## 1. Overview
The current `data_generator_lambda` uses manual dependency management (a `package/` folder and loose `.pth` files). This is fragile and makes it difficult to track versions or ensure cross-platform compatibility. We will migrate to `uv` for dependency management and automate the "Linux-compatible" build process within Terraform.

## 2. Proposed Changes

### 2.1 Dependency Management
*   **Initialize**: Convert `data_generator_lambda` into a managed project using `uv init`.
*   **Project File**: A `pyproject.toml` will track:
    *   `mysql-connector-python`
    *   `Faker`
*   **Lockfile**: A `uv.lock` file will be committed to ensure reproducible builds.

### 2.2 Terraform Automation
We will update `terraform/modules/lambda/main.tf` to handle the build lifecycle:

1.  **Build Resource**: A `null_resource` will execute the build command:
    ```bash
    # Step 1: Install dependencies for Linux Lambda target directly from pyproject.toml
    uv pip install -r pyproject.toml \
      --target build/ \
      --python-platform x86_64-unknown-linux-gnu \
      --python-version 3.9 \
      --only-binary=:all:
      
    # Step 2: Copy source code into the build directory
    cp lambda_function.py build/
    ```
2.  **Triggers**: The build will only re-run if `pyproject.toml`, `uv.lock`, or `lambda_function.py` changes.
3.  **Archiving**: The `archive_file` will now point to the `build/` directory created by `uv`.

### 2.3 Cleanup
*   Remove `data_generator_lambda/package/`
*   Remove `data_generator_lambda/six.py`
*   Remove `data_generator_lambda/*.pth`

## 3. Implementation Plan
1.  Install/Verify `uv` locally.
2.  Initialize `uv` project in `data_generator_lambda`.
3.  Add dependencies and generate lockfile.
4.  Modify Terraform module to include the `null_resource` build step.
5.  Update `archive_file` source.
6.  Verify deployment with `terraform apply`.
7.  Clean up legacy files.

## 4. Risks & Mitigations
*   **Risk**: `uv` not being present on the machine running Terraform.
*   **Mitigation**: Add a check or documentation in the README. Since this is a personal portfolio, it assumes `uv` is part of the developer's toolkit.
