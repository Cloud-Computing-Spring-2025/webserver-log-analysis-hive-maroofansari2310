### README.md

```markdown
# Web Server Log Analysis Using Apache Hive

## Project Overview
This project involves analyzing web server log data using Apache Hive to generate reports on total requests, status code frequencies, most visited pages, traffic sources, suspicious activities, and traffic trends. The data includes IP addresses, timestamps, URLs, HTTP status codes, and user agents. Partitioning is implemented to optimize query performance.

## Implementation Approach
### 1. **Count Total Web Requests**
Calculate the total number of requests processed by the web server.
```sql
INSERT OVERWRITE DIRECTORY '/user/hive/output/total_requests'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' 
SELECT COUNT(*) AS total_requests FROM web_server_logs;
```

### 2. **Analyze Status Codes**
Compute the frequency of each HTTP status code.
```sql
INSERT OVERWRITE DIRECTORY '/user/hive/output/status_codes_frequency'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' 
SELECT status, COUNT(*) AS frequency 
FROM web_server_logs 
GROUP BY status;
```

### 3. **Identify Most Visited Pages**
Find the top 3 most visited URLs.
```sql
INSERT OVERWRITE DIRECTORY '/user/hive/output/most_visited_pages'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' 
SELECT url, COUNT(*) AS request_count 
FROM web_server_logs 
GROUP BY url 
ORDER BY request_count DESC 
LIMIT 3;
```

### 4. **Traffic Source Analysis**
Identify the most common user agents (browsers).
```sql
INSERT OVERWRITE DIRECTORY '/user/hive/output/traffic_source_analysis'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' 
SELECT user_agent, COUNT(*) AS frequency 
FROM web_server_logs 
GROUP BY user_agent 
ORDER BY frequency DESC 
LIMIT 3;
```

### 5. **Detect Suspicious Activity**
Find IP addresses with >3 failed requests (status codes 404 or 500).
```sql
INSERT OVERWRITE DIRECTORY '/user/hive/output/suspicious_activity'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' 
SELECT ip, COUNT(*) AS failed_requests 
FROM web_server_logs 
WHERE status IN (404, 500) 
GROUP BY ip 
HAVING COUNT(*) > 3;
```

### 6. **Analyze Traffic Trends**
Calculate requests per minute.
```sql
INSERT OVERWRITE DIRECTORY '/user/hive/output/traffic_trends'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' 
SELECT FROM_UNIXTIME(UNIX_TIMESTAMP(timestamp, 'yyyy-MM-dd HH:mm:ss'), 'yyyy-MM-dd HH:mm') AS minute, 
       COUNT(*) AS request_count 
FROM web_server_logs 
GROUP BY minute 
ORDER BY minute;
```

### 7. **Implement Partitioning**
Create a partitioned table by `status` for faster queries.
```sql
CREATE TABLE web_server_logs_partitioned (
    ip STRING, 
    status INT, 
    url STRING, 
    user_agent STRING, 
    timestamp STRING
) PARTITIONED BY (status INT)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' 
STORED AS TEXTFILE;

-- Insert data into the partitioned table
INSERT OVERWRITE TABLE web_server_logs_partitioned PARTITION(status)
SELECT ip, status, url, user_agent, timestamp, status FROM web_server_logs;
```

## Execution Steps
1. **Setup Hive Environment**
   ```sql
   CREATE DATABASE IF NOT EXISTS web_log_analysis;
   USE web_log_analysis;

   CREATE EXTERNAL TABLE web_server_logs (
       ip STRING,
       timestamp STRING,
       url STRING,
       status INT,
       user_agent STRING
   )
   ROW FORMAT DELIMITED 
   FIELDS TERMINATED BY ',' 
   STORED AS TEXTFILE 
   LOCATION '/user/hive/warehouse/web_server_logs';
   ```

2. **Load Data into HDFS**
   ```bash
   hdfs dfs -put /path/to/web_server_logs.csv /user/hive/warehouse/web_server_logs;
   ```

3. **Run Queries**
   Execute the SQL queries sequentially (see `web_log_analysis.hql`).

4. **Export Results**
   Results are stored in HDFS directories under `/user/hive/output/`.

## Challenges Faced
- **Data Loading Issues**: Initial slow data uploads were resolved by chunking the CSV file.
- **Partitioning Limitations**: Uneven data distribution was mitigated by adjusting the partitioning strategy.

## Sample Input and Output
### Sample Input (CSV)
```csv
ip,timestamp,url,status,user_agent
192.168.1.1,2024-02-01 10:15:00,/home,200,Mozilla/5.0
192.168.1.2,2024-02-01 10:16:00,/products,200,Chrome/90.0
192.168.1.3,2024-02-01 10:17:00,/checkout,404,Safari/13.1
192.168.1.10,2024-02-01 10:18:00,/home,500,Mozilla/5.0
192.168.1.15,2024-02-01 10:19:00,/products,404,Chrome/90.0
```

### Expected Outputs
- **Total Requests**: `5`
- **Status Code Frequency**:
  ```
  200,3
  404,2
  500,1
  ```
- **Most Visited Pages**:
  ```
  /home,2
  /products,2
  /checkout,1
  ```
- **Traffic Source Analysis**:
  ```
  Mozilla/5.0,2
  Chrome/90.0,2
  Safari/13.1,1
  ```
- **Suspicious Activity**:
  ```
  192.168.1.10,1
  192.168.1.15,1
  ```
- **Traffic Trend by Minute**:
  ```
  2024-02-01 10:15,1
  2024-02-01 10:16,1
  2024-02-01 10:17,1
  2024-02-01 10:18,1
  2024-02-01 10:19,1
  ```
```

### web_log_analysis.hql

```sql
-- Create database and table
CREATE DATABASE IF NOT EXISTS web_log_analysis;
USE web_log_analysis;

CREATE EXTERNAL TABLE web_server_logs (
    ip STRING,
    timestamp STRING,
    url STRING,
    status INT,
    user_agent STRING
)
ROW FORMAT DELIMITED 
FIELDS TERMINATED BY ',' 
STORED AS TEXTFILE 
LOCATION '/user/hive/warehouse/web_server_logs';

-- Query 1: Count Total Web Requests
INSERT OVERWRITE DIRECTORY '/user/hive/output/total_requests'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' 
SELECT COUNT(*) AS total_requests FROM web_server_logs;

-- Query 2: Analyze Status Codes
INSERT OVERWRITE DIRECTORY '/user/hive/output/status_codes_frequency'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' 
SELECT status, COUNT(*) AS frequency 
FROM web_server_logs 
GROUP BY status;

-- Query 3: Identify Most Visited Pages
INSERT OVERWRITE DIRECTORY '/user/hive/output/most_visited_pages'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' 
SELECT url, COUNT(*) AS request_count 
FROM web_server_logs 
GROUP BY url 
ORDER BY request_count DESC 
LIMIT 3;

-- Query 4: Traffic Source Analysis
INSERT OVERWRITE DIRECTORY '/user/hive/output/traffic_source_analysis'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' 
SELECT user_agent, COUNT(*) AS frequency 
FROM web_server_logs 
GROUP BY user_agent 
ORDER BY frequency DESC 
LIMIT 3;

-- Query 5: Detect Suspicious Activity
INSERT OVERWRITE DIRECTORY '/user/hive/output/suspicious_activity'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' 
SELECT ip, COUNT(*) AS failed_requests 
FROM web_server_logs 
WHERE status IN (404, 500) 
GROUP BY ip 
HAVING COUNT(*) > 3;

-- Query 6: Analyze Traffic Trends
INSERT OVERWRITE DIRECTORY '/user/hive/output/traffic_trends'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' 
SELECT 
    FROM_UNIXTIME(UNIX_TIMESTAMP(timestamp, 'yyyy-MM-dd HH:mm:ss'), 'yyyy-MM-dd HH:mm') AS minute, 
    COUNT(*) AS request_count 
FROM web_server_logs 
GROUP BY 
    FROM_UNIXTIME(UNIX_TIMESTAMP(timestamp, 'yyyy-MM-dd HH:mm:ss'), 'yyyy-MM-dd HH:mm') 
ORDER BY minute;

-- Query 7: Implement Partitioning
CREATE TABLE web_server_logs_partitioned (
    ip STRING, 
    status INT, 
    url STRING, 
    user_agent STRING, 
    timestamp STRING
) PARTITIONED BY (status INT)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' 
STORED AS TEXTFILE;

INSERT OVERWRITE TABLE web_server_logs_partitioned PARTITION(status)
SELECT ip, status, url, user_agent, timestamp, status FROM web_server_logs;
```