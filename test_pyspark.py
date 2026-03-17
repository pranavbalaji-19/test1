from pyspark.sql import SparkSession
from pyspark.sql.functions import col, sum, count

# Create a Spark session
spark = SparkSession.builder \
    .appName("User Activity Analysis") \
    .getOrCreate()

# Load the data from a CSV file
logs_df = spark.read.csv('user_activity_logs.csv', header=True, inferSchema=True)

# Filter out logs where the duration is less than or equal to zero
filtered_logs_df = logs_df.filter(col("duration") > 0)

# Group the data by user_id and calculate total duration and activity count
user_stats_df = filtered_logs_df.groupBy("user_id").agg(
    sum("duration").alias("total_duration"),
    count("*").alias("activity_count")
)

# Filter users who have a total duration greater than 1000 seconds
active_users_df = user_stats_df.filter(col("total_duration") > 1000)

# Order the results by total_duration in descending order
ordered_users_df = active_users_df.orderBy(col("total_duration").desc())

# Show the results
ordered_users_df.show()

# Store the results in an output file
ordered_users_df.write.csv('active_users_stats', header=True)

# Stop the Spark session
spark.stop()
