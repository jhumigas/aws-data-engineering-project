import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue import DynamicFrame

args = getResolvedOptions(sys.argv, ['JOB_NAME'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Script generated for node Amazon S3
AmazonS3_node1757458918452 = glueContext.create_dynamic_frame.from_options(format_options={}, connection_type="s3", format="parquet", connection_options={"paths": ["s3://data-engineering-project-424254664937/silver_data/dev/orderDetails/"], "recurse": True}, transformation_ctx="AmazonS3_node1757458918452")

# Script generated for node Amazon Redshift
AmazonRedshift_node1757458967431 = glueContext.write_dynamic_frame.from_options(frame=AmazonS3_node1757458918452, connection_type="redshift", connection_options={"redshiftTmpDir": "s3://aws-glue-assets-424254664937-us-east-2/temporary/", "useConnectionProperties": "true", "dbtable": "sales.fact_order_details", "connectionName": "Redshift connection", "preactions": "CREATE TABLE IF NOT EXISTS sales.fact_order_details (order_details_id_ VARCHAR, order_id VARCHAR, product_id VARCHAR, product_quantity VARCHAR, ingestion_date DATE);"}, transformation_ctx="AmazonRedshift_node1757458967431")

job.commit()