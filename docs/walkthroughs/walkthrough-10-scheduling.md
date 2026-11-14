# Walkthrough 10: Scheduling (EventBridge)

Run the data generator and the pipeline on a schedule.

- **Rule 1**: Trigger the Lambda Data Generator (e.g., every 5 minutes).
- **Rule 2**: Trigger the Step Functions State Machine (e.g., every hour).

> [!NOTE]
> Before enabling schedules, ensure all intermediate data is purged and Glue job bookmarks are reset for a clean production run.

---

Next: [Walkthrough 11: PII Management (Lake Formation)](./walkthrough-11-lake-formation.md)  
Back to [Walkthroughs](./README.md)
