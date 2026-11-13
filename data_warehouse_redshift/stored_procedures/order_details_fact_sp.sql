CREATE OR REPLACE PROCEDURE sales.sp_merge_fact_order_details()
LANGUAGE plpgsql
AS $$
BEGIN

-- Remove fact rows that have a newer version in the staging table
DELETE FROM sales.fact_order_details
USING sales.stage_fact_order_details s
WHERE sales.fact_order_details.order_details_id_ = s.order_details_id;

-- Insert the latest staged version of each order line
INSERT INTO sales.fact_order_details
   (order_details_id_, order_id, product_id, product_quantity, ingestion_date)
SELECT
    deduped.order_details_id, deduped.order_id, deduped.product_id,
    deduped.product_quantity, deduped.ingestion_date
FROM (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY order_details_id ORDER BY ingestion_date DESC) AS row_num
    FROM sales.stage_fact_order_details
) deduped
WHERE deduped.row_num = 1;

-- Truncate the staging table
TRUNCATE TABLE sales.stage_fact_order_details;

END;
$$;
