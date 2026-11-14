# Walkthrough 8: Step Functions (Orchestration)

Sequence the entire pipeline logic.

## IAM Role
Grant Step Functions permission to start and poll Glue jobs and crawlers, and to run and describe Redshift Data API statements.

## State Machine
Build four stages, in order:
1. Run the four crawlers and wait until each one is `READY` with a `SUCCEEDED` last crawl.
2. Run the four transform jobs in parallel.
3. Load and merge the dimensions in parallel (`sp_merge_dim_*`).
4. Load and merge the facts in parallel (`sp_merge_fact_*`).

## Merge Polling
After each `executeStatement`, poll `describeStatement` until `FINISHED`, and fail on `FAILED` or `ABORTED`.

## Reference
`orchestration_step_function/state_machine.json` is the original console definition.
The Terraform module `terraform/modules/step_functions` is the current one.

---

Next: [Walkthrough 9: Visualization (QuickSight / BI)](./walkthrough-9-visualization.md)  
Back to [Walkthroughs](./README.md)
