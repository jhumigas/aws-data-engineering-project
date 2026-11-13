# Walkthrough 1: RDS MySQL Setup

We use RDS to simulate an on-premise transactional source database.

## Instance
- **Engine**: MySQL 8.0 Community Edition.
- **Instance Class**: `db.t3.micro` (Free Tier eligible).
- **Public Access**: Enable **Publicly Accessible** to allow local SQL client connectivity for initial setup.

## Parameter Group
- Create a custom parameter group for MySQL 8.0.
- Set `binlog_format = ROW`.
- Set `binlog_row_image = FULL`.
- Attach to the RDS instance (reboot required to apply).

## Initialization
Run the DDL script found in `application_db_rds/migration/V1__Initial_Schema.sql`.

## CDC Configuration
Connect via SQL client and execute the binary logging retention command:
```sql
CALL mysql.rds_set_configuration('binlog retention hours', 24);
```

---

Next: [Walkthrough 2: S3 Data Lake](./walkthrough-2-s3-data-lake.md)  
Back to [Walkthroughs](./README.md)
