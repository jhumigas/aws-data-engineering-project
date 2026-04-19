import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue import DynamicFrame

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
source_path = f"s3://{args['SOURCE_BUCKET']}/{args['TARGET_PREFIX']}/orderDetails/"
silver_node = glueContext.create_dynamic_frame.from_options(
    format_options={}, 
    connection_type="s3", 
    format="parquet", 
    connection_options={"paths": [source_path], "recurse": True}, 
    transformation_ctx="silver_node"
)

# Write to Redshift Staging Table
redshift_node = glueContext.write_dynamic_frame.from_options(
    frame=silver_node, 
    connection_type="redshift", 
    connection_options={
        "redshiftTmpDir": args['TEMP_DIR'], 
        "useConnectionProperties": "true", 
        "dbtable": args['STAGING_TABLE'], 
        "connectionName": args['REDSHIFT_CONNECTION']
    }, 
    transformation_ctx="redshift_node"
)

job.commit()
