import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue import DynamicFrame
from pyspark.sql.functions import col

# Get arguments from Job
args = getResolvedOptions(sys.argv, [
    'JOB_NAME', 
    'SOURCE_BUCKET', 
    'TARGET_PREFIX', 
    'REDSHIFT_CONNECTION', 
    'STAGING_TABLE', 
    'TEMP_DIR'
])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Read from Silver Layer S3
source_path = f"s3://{args['SOURCE_BUCKET']}/{args['TARGET_PREFIX']}/Orders/"
silver_node = glueContext.create_dynamic_frame.from_options(
    format_options={}, 
    connection_type="s3", 
    format="parquet", 
    connection_options={"paths": [source_path], "recurse": True}, 
    transformation_ctx="silver_node"
)

# Columns of the Redshift staging table, in DDL order.
# Selecting them explicitly drops partition and CDC helper columns from the silver files.
STAGING_COLUMNS = [
    ("order_id", "string"),
    ("order_customer_id", "string"),
    ("order_date", "date"),
    ("payment_method", "string"),
    ("order_platform", "string"),
    ("order_year", "int"),
    ("order_month", "int"),
    ("ingestion_date", "date"),
]

if silver_node.count() > 0:
    staged_df = silver_node.toDF().select(
        [col(name).cast(data_type) for name, data_type in STAGING_COLUMNS]
    )
    staged_dyf = DynamicFrame.fromDF(staged_df, glueContext, "staged_dyf")

    # Write to Redshift Staging Table
    glueContext.write_dynamic_frame.from_options(
        frame=staged_dyf,
        connection_type="redshift",
        connection_options={
            "redshiftTmpDir": args['TEMP_DIR'],
            "useConnectionProperties": "true",
            "dbtable": args['STAGING_TABLE'],
            "connectionName": args['REDSHIFT_CONNECTION']
        },
        transformation_ctx="redshift_node"
    )
else:
    print("No new Orders files in the silver layer. Skipping the staging load.")

job.commit()
