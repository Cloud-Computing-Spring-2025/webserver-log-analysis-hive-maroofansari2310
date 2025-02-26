-- Create a database named 'web_logs' if it does not already exist
CREATE DATABASE web_logs;

-- Switch to the 'web_logs' database
USE web_logs;

-- Create an external table 'web_server_logs' to store web log data
-- External table means Hive does not manage the data, it just references it
CREATE EXTERNAL TABLE IF NOT EXISTS web_server_logs (
    ip STRING,             -- IP address of the user making the request
    timestamp STRING,      -- Timestamp of the request
    url STRING,            -- Requested URL
    status INT,            -- HTTP status code of the request (e.g., 200, 404, 500)
    user_agent STRING      -- Information about the user's browser and operating system
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','   -- Fields in the log file are separated by commas
STORED AS TEXTFILE        -- Data is stored as a plain text file
LOCATION '/user/hive/warehouse/web_logs/';  -- HDFS location of the data

-- 1. Count Total Requests
-- This query calculates the total number of requests in the logs
INSERT OVERWRITE DIRECTORY '/user/hive/output/total_requests'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' 
SELECT COUNT(*) AS total_requests FROM web_server_logs;

-- 2. Count Frequency of Status Codes
-- This query counts how often each HTTP status code appears in the logs
INSERT OVERWRITE DIRECTORY '/user/hive/output/status_codes_frequency'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' 
SELECT status, COUNT(*) AS frequency 
FROM web_server_logs 
GROUP BY status;

-- 3. Most Visited Pages
-- This query identifies the top 3 most visited URLs based on request count
INSERT OVERWRITE DIRECTORY '/user/hive/output/most_visited_pages'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' 
SELECT url, COUNT(*) AS request_count 
FROM web_server_logs 
GROUP BY url 
ORDER BY request_count DESC 
LIMIT 3;

-- 4. Traffic Source Analysis
-- This query analyzes traffic sources by counting the most common user agents (browsers)
INSERT OVERWRITE DIRECTORY '/user/hive/output/traffic_source_analysis'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' 
SELECT user_agent, COUNT(*) AS frequency 
FROM web_server_logs 
GROUP BY user_agent 
ORDER BY frequency DESC 
LIMIT 3;

-- 5. Suspicious Activity (Failed Requests)
-- This query detects IPs with more than 3 failed requests (404, 500 errors)
INSERT OVERWRITE DIRECTORY '/user/hive/output/suspicious_activity'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' 
SELECT ip, COUNT(*) AS failed_requests 
FROM web_server_logs 
WHERE status IN (404, 500) 
GROUP BY ip 
HAVING COUNT(*) > 3;

-- 6. Traffic Trends by Minute
-- This query groups requests by the minute to analyze traffic trends over time
INSERT OVERWRITE DIRECTORY '/user/hive/output/traffic_trends'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' 
SELECT FROM_UNIXTIME(UNIX_TIMESTAMP(timestamp, 'yyyy-MM-dd HH:mm:ss'), 'yyyy-MM-dd HH:mm') AS minute, 
       COUNT(*) AS request_count 
FROM web_server_logs 
GROUP BY FROM_UNIXTIME(UNIX_TIMESTAMP(timestamp, 'yyyy-MM-dd HH:mm:ss'), 'yyyy-MM-dd HH:mm') 
ORDER BY minute;

-- 7. Create a Partitioned Table
-- This table is partitioned by 'status' to optimize query performance
CREATE TABLE web_server_logs_partitioned (
    ip STRING,             -- IP address of the requestor
    url STRING,            -- Requested URL
    user_agent STRING,     -- User agent details
    timestamp STRING       -- Timestamp of the request
) 
PARTITIONED BY (status INT)  -- Partitioning by HTTP status code
ROW FORMAT DELIMITED 
FIELDS TERMINATED BY ',' 
STORED AS TEXTFILE;

-- 8. Insert Data into the Partitioned Table
-- This command loads data from the 'web_server_logs' table into the partitioned table
-- It dynamically partitions the data based on the 'status' column
SET hive.exec.dynamic.partition.mode=nonstrict;  -- Enable dynamic partitioning
INSERT OVERWRITE TABLE web_server_logs_partitioned PARTITION (status)
SELECT ip, url, user_agent, timestamp, status FROM web_server_logs;
