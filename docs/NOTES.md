## Project Steps

0. **Set up user permissions**: Create an IAM user with admin access

1. **Set up the source database**: We will use RDS to simulate an on-premise MySQL database. We will create a database and populate it with sample sales data.
    - Create parameter group with engine type MySQL 8.0 and set `binlog_format` to `ROW`
    - Create database use MySQL for engine, and MySQL community, use free tier if possible
    - Make sure the database is publicly accessible (check with your SQL client from your local machine)
    - Run the DDL script to create the tables (see `rds/mysql_source_ddl.sql`)
    - Activate CDC 
        - on the source database (enable binary logging, see the steps in the script `rds/activate_cdc.sql`)
        - Update the parameter group to set `binlog_format` to `ROW` and `binlog_row_image` to `FULL`

2. ** Set up S3 buckets**: We will create one S3 bucket to store the raw and processed data.
    - Create your bucket and folders bronze and silver folders inside
    Data will be stored in csv format in bronze folder, and parquet format in silver folder
    - Create a policy to allow other services to access the bucket (Glue, DMS, Redshift etc)

3. **Set up DMS**: We will use DMS to replicate data from the source database to S3 using CDC. We will create a replication instance, source and target endpoints, and a replication task.
    - Create a replication instance (use free tier if possible)
    - Create a source endpoint for the RDS database, make sure to test the connection
    - Create a target endpoint for the S3 bucket (set up a role to allow DMS to write to S3), make sure to test the connection
    - Create a replication task to replicate data from the source to the target using CDC

4. **Set up data generation**: We will use Lambda to generate sample sales data and insert it into the source database. This will simulate real-time data generation.
    - Create a role to allow Lambda to access RDS
    - Create a Lambda function to generate sample sales data and insert it into the source database (see `lambda/data_generation.py`)
    - Setup secrets manager to store the database credentials alongside host and port
    - Attach a policy to the role to allow access to secrets manager
    - Test the function to make sure it works

5. **Set up Glue for transformation**: We will use Glue to process the data from S3, first store it into S3 and load it into Redshift. We will create a Glue database, crawler, and job.
    - Create a role to allow Glue to access S3 and for other operations (we need to add policies AWSGlueServiceRole, AWSGlueNotebookRole and the S3 bucket policy created in step 2)
    - Attach a policy to allow glue to pass the its role to the glue job
    - Create a Glue database
    - Create a Glue crawler to crawl the data in the bronze folder (you'll need one crawler per folder)
    - Create a Glue job to process the data from the bronze folder and load it into the silver folder in parquet format (see `glue/etl_glue_jobs.py`)
    - Test the jobs to make sure it works
    - Enable job bookmarks to avoid reprocessing data

6. **Set up Redshift**: We will use Redshift as our data warehouse to store the processed data. We will create a Redshift cluster, database, and tables.
    - Create a role to allow Redshift to access S3 (attach the S3 access policy created in step 2)
    - Create a redshift workgroup (use free tier if possible) and a namespace
    - Make sure the cluster is publicly accessible (check with your SQL client from your local machine)
    - Create a database and tables to store the processed data (see `redshift/ddl`)
    - Create stored procedures to have SCD type 2 functionality

7. **Set up Glue for Readshift loading**: We will use Glue to load the processed data from S3 to Redshift. We will create a Glue job.
    - Create a policy to allow glue to retrieve the Redshift credentials from secrets manager
    - Attach the policy to the Glue role
    - Create a VPC endpoint for S3, secrets manager, redshift and sts (for temporary credentials)
    - Create a Glue connection to connect to Redshift (use the VPC, subnet and security group of the Redshift cluster)
    - Create a Glue job to load the data from the silver folder to Redshift (see `etl_glue_jobs/load`)
    - Test the job to make sure it works
    - Enable job bookmarks to avoid reprocessing data

8. **Set up Step Functions**: We will use Step Functions to orchestrate the data pipeline. We will create a state machine to run the Glue jobs in sequence.
    - Create a role to allow Step Functions to access Glue (attach the AWSGlueServiceRole policy)
    - Create a state machine to run the Glue jobs in sequence (see `step_functions/state_machine_definition.json`)
    - Test the state machine to make sure it works

9. **Set up Quicksight**: We will use Quicksight to visualize the data in Redshift. We will create a dataset and a dashboard.
    - Sign up for Quicksight (use the same region as the other services)
    - Create a dataset to connect to Redshift (make sure to use the same VPC, subnet and security group as Redshift)
    - Create a dashboard to visualize the data (see `quicksight/dashboard_example.png` for inspiration)

10. **Schedule with EventBridge**: We will use EventBridge to schedule the data pipeline to run at regular intervals.
    - Create a rule to trigger the lambda function for data generation at regular intervals (e.g., every 5 minutes) using a cron expression
    - Create a rule to trigger the Step Functions state machine at regular intervals (e.g., every hour) using a cron expression
    - Test the rules to make sure they work
    - Once you are ready to run EventBridge rules, make sure to clean all the intermediate steps we did prior meaning removing bronze, silver layer zone, resetting job bookmarks on glue jobs

11. **Clean resources**: Once you are done, and are satisfied clean up all resources