logs = LOAD 'user_activity_logs.csv' USING PigStorage(',') 
       AS (user_id: int, activity: chararray, timestamp: long, duration: int);

-- Filter out logs where the duration is less than or equal to zero
filtered_logs = FILTER logs BY duration > 0;

-- Group the data by user_id
grouped_logs = GROUP filtered_logs BY user_id;

-- Calculate the total duration and count of activities for each user
user_stats = FOREACH grouped_logs GENERATE 
    group AS user_id, 
    SUM(filtered_logs.duration) AS total_duration, 
    COUNT(filtered_logs) AS activity_count;

-- Filter users who have a total duration greater than 1000 seconds
active_users = FILTER user_stats BY total_duration > 1000;

-- Order the results by total_duration in descending order
ordered_users = ORDER active_users BY total_duration DESC;

-- Store the results in an output file
STORE ordered_users INTO 'active_users_stats' USING PigStorage(',');
