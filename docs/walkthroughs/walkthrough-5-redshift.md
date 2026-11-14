# Walkthrough 5: Redshift Data Warehouse

Provision the warehouse that holds the gold layer.

- **Provisioning**: Create a Redshift RA3 cluster or a Serverless Workgroup/Namespace.
- **Network**: Ensure the cluster is accessible and VPC endpoints are configured (see [Walkthrough 7](./walkthrough-7-redshift-loading-and-vpc.md)).
- **Schema & Objects**: Establish the `sales` schema and run the DDLs/Stored Procedures in `data_warehouse_redshift/` to enable SCD Type 2 functionality.

---

Next: [Walkthrough 6: Glue ETL (Transformation)](./walkthrough-6-glue-etl.md)  
Back to [Walkthroughs](./README.md)
