CREATE OR REPLACE PROCEDURE sales.sp_merge_fact_orders()
LANGUAGE plpgsql
AS $$
BEGIN

-- Remove fact rows that have a newer version in the staging table
DELETE FROM sales.fact_orders
USING sales.stage_fact_orders s
WHERE sales.fact_orders.order_id_ = s.order_id;

-- Insert the latest staged version of each order
INSERT INTO sales.fact_orders
   (order_id_, order_customer_id, order_date, payment_method, order_platform,
    order_year, order_month, ingestion_date)
SELECT
    deduped.order_id, deduped.order_customer_id, deduped.order_date, deduped.payment_method,
    deduped.order_platform, deduped.order_year, deduped.order_month, deduped.ingestion_date
FROM (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY ingestion_date DESC) AS row_num
    FROM sales.stage_fact_orders
) deduped
WHERE deduped.row_num = 1;

-- Truncate the staging table
TRUNCATE TABLE sales.stage_fact_orders;

END;
$$;
