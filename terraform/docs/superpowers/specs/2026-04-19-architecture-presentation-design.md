# Design: Multi-Layered Architecture and Security Presentation

This document outlines the plan to create a professional, maintainable, and highly technical presentation of the AWS Data Engineering project using Mermaid.js and structured documentation.

## 1. Goal
To provide a three-layered view of the project that serves Portfolio (hiring), Technical (deep dive), and Maintenance (operator) needs.

## 2. Layers

### 2.1. Layer 1: Portfolio High-Level Architecture
- **Location**: `README.md` (Top section)
- **Format**: Mermaid `graph TD`
- **Focus**: End-to-end data flow (Source -> Replication -> Lake -> Warehouse).
- **Visuals**: Clean icons/labels for RDS, DMS, S3, Glue, Redshift, and Step Functions.

### 2.2. Layer 2: Security and Policy Design (Deep Dive)
- **Location**: `docs/SECURITY_DESIGN.md`
- **Format**: Mermaid sequence diagrams + explanatory text.
- **Focus**: 
    - Surgical S3 Bucket Policy (Role-based access).
    - Regional Service Principal nuances.
    - Least Privilege mapping (e.g., Glue role can only write to `silver/`).

### 2.3. Layer 3: Operator's Logic Flow
- **Location**: `docs/OPERATIONS_GUIDE.md`
- **Format**: Mermaid `stateDiagram-v2` and `flowchart`.
- **Focus**:
    - Step Functions orchestration logic (Parallel Dim -> Sequential Fact).
    - SCD Type 2 merge sequence in Redshift.

## 3. Implementation Strategy

1.  **Surgical Policy Documentation**: Audit the `main.tf` and `modules/` to extract the exact IAM statement rationale.
2.  **Mermaid Drafting**: 
    - Create the high-level graph.
    - Create the sequence diagrams for S3 access.
    - Create the Step Function flow.
3.  **Documentation Polish**: Ensure all files reference the `Makefile` and `walkthrough.md` for a cohesive developer experience.

## 4. Maintenance
- Using Mermaid (text-based) ensures that as the Terraform code changes, the diagrams can be updated via simple PRs without needing external image editors.
