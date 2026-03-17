import org.apache.spark.sql.SparkSession
import org.apache.spark.sql.functions._

object UserActivityAnalysis {
  def main(args: Array[String]): Unit = {
    // Create a Spark session
    val spark = SparkSession.builder()
      .appName("User Activity Analysis")
      .getOrCreate()

    // Load the data from a CSV file
    val logsDF = spark.read.option("header", "true").option("inferSchema", "true")
      .csv("user_activity_logs.csv")

    // Filter out logs where the duration is less than or equal to zero
    val filteredLogsDF = logsDF.filter(col("duration") > 0)

    // Group the data by user_id and calculate total duration and activity count
    val userStatsDF = filteredLogsDF.groupBy("user_id")
      .agg(
        sum("duration").alias("total_duration"),
        count("*").alias("activity_count")
      )

    // Filter users who have a total duration greater than 1000 seconds
    val activeUsersDF = userStatsDF.filter(col("total_duration") > 1000)

    // Order the results by total_duration in descending order
    val orderedUsersDF = activeUsersDF.orderBy(col("total_duration").desc)

    // Show the results
    orderedUsersDF.show()

    // Store the results in an output file
    orderedUsersDF.write.option("header", "true").csv("active_users_stats")

    // Stop the Spark session
    spark.stop()
  }
}
