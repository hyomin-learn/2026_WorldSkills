CREATE TABLE order_stream (
    order_id     STRING,
    product_name STRING,
    price        DOUBLE,
    quantity     INT,
    event_time   TIMESTAMP(3),
    WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND
) WITH (
    'connector'                  = 'kinesis',
    'stream'                     = 'wsc2026-order-stream',
    'aws.region'                 = 'ap-northeast-2',
    'scan.stream.initpos'        = 'LATEST',
    'format'                     = 'json',
    'json.timestamp-format.standard' = 'ISO-8601'
);

SELECT COUNT(*) AS order_count
  FROM order_stream
  WHERE event_time > CURRENT_TIMESTAMP - INTERVAL '1' MINUTE;

SELECT product_name, SUM(price * quantity) AS total_revenue
  FROM order_stream
  GROUP BY product_name;
