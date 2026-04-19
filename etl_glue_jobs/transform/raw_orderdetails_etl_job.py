"""%%configure 
{
  "--job-bookmark-option": "job-bookmark-enable"
} """       

import sys
from pyspark.context import SparkContext
from awsglue.context import GlueContext	
from pyspark.sql.functions import current_timestamp, lit, sha2, concat_ws, col, current_date, split,to_date, round, year, month
from pyspark.sql.types import TimestampType, DateType
from awsglue.dynamicframe import DynamicFrame
from awsglue.utils import getResolvedOptions
from awsglue.job import Job

# Get arguments from Job
args = getResolvedOptions(sys.argv, ["JOB_NAME", "SOURCE_BUCKET", "GLUE_DATABASE", "TARGET_PREFIX"])

# Initialize variables from args
source_bucket = args['SOURCE_BUCKET']
glue_database = args['GLUE_DATABASE']
target_prefix = args['TARGET_PREFIX'] # e.g. "silver/dev"
table_name = "orderDetails"
glue_table_name = "orderdetails" # Lowercase matching crawler convention

# set up contexts
sc = SparkContext.getOrCreate()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)  
job.init(args['JOB_NAME'], args)

# Read from Data Catalog
order_details_df_from_catalog = glueContext.create_data_frame_from_catalog(
    database = glue_database,
    table_name = glue_table_name,
    additional_options = {"useCatalogSchema": True},
    transformation_ctx = "orderdetails_df_from_catalog"
)

if order_details_df_from_catalog.count() > 0: 
    # Create new dataframe for renamed fields
    renamed_order_details = order_details_df_from_catalog.withColumnRenamed("orderDetailsId","order_details_id")\
                        .withColumnRenamed("orderId","order_id")\
                        .withColumnRenamed("productid","product_id")\
                        .withColumnRenamed("Quantity","product_quantity")\
                        .drop("op")
    
    # Create current_date variable
    curr_date = current_date()

    # create dataframe with new columns
    order_details_final_df = renamed_order_details.withColumn("ingestion_date",curr_date)\
                                .withColumn("ingestion_date_pk",curr_date)

    order_details_final_dyf = DynamicFrame.fromDF(order_details_final_df,glueContext,"order_details_final_dyf")  

    # Write rows to S3 as Parquet
    glueContext.write_dynamic_frame.from_options(
        frame = order_details_final_dyf,
        connection_type = "s3",    
        connection_options = {"path": f"s3://{source_bucket}/{target_prefix}/{table_name}/", "partitionKeys": ["ingestion_date_pk"]},
        format = "parquet",
        transformation_ctx = "order_details_final_dyf"
    )
    
else:
    print("No new records found in the source data. Skipping further processing.")

job.commit()
