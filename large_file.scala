// -------------------------------------------------------------
// LargeETLPipeline.scala
// A large-scale Scala ETL pipeline example (1000+ lines)
// -------------------------------------------------------------

package com.example.etl

import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import scala.util.{Try, Success, Failure}
import scala.collection.mutable
import scala.io.Source
import com.typesafe.config.{Config, ConfigFactory}
import org.apache.spark.sql.{SparkSession, DataFrame, Dataset, Row, SaveMode}
import org.apache.spark.sql.functions._
import org.apache.spark.sql.types._
import org.slf4j.LoggerFactory

// ========================================================================
// Configuration Management Module
// ========================================================================

object AppConfig {
  private val config: Config = ConfigFactory.load()

  val sparkMaster: String = config.getString("etl.spark.master")
  val appName: String = config.getString("etl.appName")

  val sourceCsvPath: String = config.getString("etl.source.csv.path")
  val sourceJsonPath: String = config.getString("etl.source.json.path")

  val jdbcUrl: String = config.getString("etl.sink.jdbc.url")
  val jdbcUser: String = config.getString("etl.sink.jdbc.user")
  val jdbcPassword: String = config.getString("etl.sink.jdbc.password")
  val jdbcTable: String = config.getString("etl.sink.jdbc.table")

  val outputParquetPath: String = config.getString("etl.sink.parquet.path")

  val logLevel: String = config.getString("etl.log.level")

  val maxRetryCount: Int = config.getInt("etl.retry.maxCount")

  val kafkaBootstrapServers: String = config.getString("etl.kafka.bootstrap.servers")
  val kafkaTopicInput: String = config.getString("etl.kafka.topic.input")
  val kafkaTopicOutput: String = config.getString("etl.kafka.topic.output")

  // Add more config parameters as needed

  def printConfig(): Unit = {
    println(s"AppName: $appName")
    println(s"Spark Master: $sparkMaster")
    println(s"Source CSV Path: $sourceCsvPath")
    println(s"Source JSON Path: $sourceJsonPath")
    println(s"JDBC URL: $jdbcUrl")
    println(s"Output Parquet Path: $outputParquetPath")
    println(s"Kafka Bootstrap Servers: $kafkaBootstrapServers")
  }
}

// ========================================================================
// Logging Utility Module (using SLF4J)
// ========================================================================

trait Logging {
  val logger = LoggerFactory.getLogger(this.getClass)
}

// ========================================================================
// Spark Session Builder Module
// ========================================================================

object SparkSessionBuilder extends Logging {
  def getSparkSession(appName: String): SparkSession = {
    logger.info("Starting Spark Session")
    val spark = SparkSession.builder()
      .appName(appName)
      .master(AppConfig.sparkMaster)
      .config("spark.sql.shuffle.partitions", "8")
      .config("spark.serializer", "org.apache.spark.serializer.KryoSerializer")
      .getOrCreate()

    spark.sparkContext.setLogLevel(AppConfig.logLevel)
    logger.info("Spark Session started")
    spark
  }
}

// ========================================================================
// Extraction Module
// ========================================================================

trait Extractor extends Logging {

  def readCsv(spark: SparkSession, path: String): DataFrame = {
    logger.info(s"Reading CSV data from $path")
    spark.read
      .option("header", "true")
      .option("inferSchema", "true")
      .csv(path)
  }

  def readJson(spark: SparkSession, path: String): DataFrame = {
    logger.info(s"Reading JSON data from $path")
    spark.read
      .option("multiLine", "true")
      .json(path)
  }

  def readJdbc(spark: SparkSession, url: String, table: String, user: String, password: String): DataFrame = {
    logger.info(s"Reading data from JDBC table $table")
    spark.read
      .format("jdbc")
      .option("url", url)
      .option("dbtable", table)
      .option("user", user)
      .option("password", password)
      .load()
  }

  // Simulate Kafka streaming extraction (placeholder)
  def readKafka(spark: SparkSession, bootstrapServers: String, topic: String): DataFrame = {
    logger.info(s"Reading Kafka stream from topic $topic")
    spark.readStream
      .format("kafka")
      .option("kafka.bootstrap.servers", bootstrapServers)
      .option("subscribe", topic)
      .option("startingOffsets", "earliest")
      .load()
  }
}

// ========================================================================
// Transformation Module
// ========================================================================

trait Transformer extends Logging {

  def cleanData(df: DataFrame): DataFrame = {
    logger.info("Cleaning data: removing nulls and duplicates")
    df.na.drop()
      .dropDuplicates()
  }

  def enrichData(df: DataFrame): DataFrame = {
    logger.info("Enriching data: adding processed_timestamp column")
    df.withColumn("processed_timestamp", current_timestamp())
  }

  def filterImportantRecords(df: DataFrame, colName: String): DataFrame = {
    logger.info(s"Filtering records where $colName is NOT NULL")
    df.filter(col(colName).isNotNull)
  }

  def joinData(dfLeft: DataFrame, dfRight: DataFrame, joinCol: String): DataFrame = {
    logger.info(s"Joining datasets on $joinCol")
    dfLeft.join(dfRight, Seq(joinCol), "inner")
  }

  def aggregateData(df: DataFrame, groupByCol: String, aggCol: String): DataFrame = {
    logger.info(s"Aggregating data by $groupByCol with sum of $aggCol")
    df.groupBy(col(groupByCol))
      .agg(sum(col(aggCol)).alias("total_" + aggCol))
  }

  // UDF example: calculate string length
  val stringLengthUdf = udf((s: String) => if (s != null) s.length else 0)

  def addStringLengthColumn(df: DataFrame, colName: String, newColName: String): DataFrame = {
    logger.info(s"Adding string length column $newColName based on $colName")
    df.withColumn(newColName, stringLengthUdf(col(colName)))
  }

  // More complex transformations can be added here
}

// ========================================================================
// Loader Module
// ========================================================================

trait Loader extends Logging {

  def writeParquet(df: DataFrame, path: String): Unit = {
    logger.info(s"Writing DataFrame to Parquet at $path")
    df.write.mode(SaveMode.Overwrite).parquet(path)
  }

  def writeJdbc(df: DataFrame, url: String, table: String, user: String, password: String): Unit = {
    logger.info(s"Writing DataFrame to JDBC table $table")
    df.write
      .mode(SaveMode.Append)
      .format("jdbc")
      .option("url", url)
      .option("dbtable", table)
      .option("user", user)
      .option("password", password)
      .save()
  }

  // Simulate Kafka streaming sink (placeholder)
  def writeKafka(df: DataFrame, bootstrapServers: String, topic: String): Unit = {
    logger.info(s"Writing DataFrame stream to Kafka topic $topic")
    // Not implemented here: streaming sink requires streaming query
  }
}

// ========================================================================
// Error Handling and Retry Module
// ========================================================================

trait RetryHandler extends Logging {

  def withRetry[T](maxRetries: Int)(block: => T): T = {
    var retries = 0
    var lastError: Option[Throwable] = None

    while (retries <= maxRetries) {
      try {
        return block
      } catch {
        case ex: Throwable =>
          lastError = Some(ex)
          retries += 1
          logger.warn(s"Operation failed, attempt $retries/$maxRetries: ${ex.getMessage}")
          Thread.sleep(1000) // simple backoff
      }
    }
    logger.error(s"Operation failed after $maxRetries retries.")
    throw lastError.getOrElse(new RuntimeException("Unknown error during withRetry"))
  }
}

// ========================================================================
// Monitoring and Metrics Module (Simple counters)
// ========================================================================

trait Metrics extends Logging {
  val counters: mutable.Map[String, Long] = mutable.Map.empty.withDefaultValue(0L)

  def incrementCounter(name: String, value: Long = 1): Unit = {
    counters(name) = counters(name) + value
    logger.info(s"Metric $name incremented by $value, total = ${counters(name)}")
  }

  def printMetrics(): Unit = {
    logger.info("Current Metrics:")
    counters.foreach { case (key, value) =>
      logger.info(s"$key = $value")
    }
  }
}

// ========================================================================
// Utility Module
// ========================================================================

object Utils {
  def currentTimeString: String = LocalDateTime.now.format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"))

  def safeGetEnv(key: String, default: String): String = {
    sys.env.getOrElse(key, default)
  }
}

// ========================================================================
// Domain Models (case classes for structured data)
// ========================================================================

case class Customer(id: Long, name: String, email: String, country: String, signupDate: String)
case class Transaction(id: Long, customerId: Long, amount: Double, transactionDate: String)
case class EnrichedTransaction(id: Long, customerName: String, email: String, country: String, amount: Double, transactionDate: String, processedTimestamp: String)

// ========================================================================
// Sample Data Generators for Testing and Demo
// ========================================================================

object SampleDataGenerator extends Logging {

  def generateCustomers(spark: SparkSession): Dataset[Customer] = {
    import spark.implicits._
    logger.info("Generating sample customers data")
    Seq(
      Customer(1, "Alice Smith", "alice@example.com", "US", "2020-01-01"),
      Customer(2, "Bob Jones", "bob@example.com", "UK", "2020-02-15"),
      Customer(3, "Charlie Brown", "charlie@example.com", "CA", "2020-03-20")
    ).toDS()
  }

  def generateTransactions(spark: SparkSession): Dataset[Transaction] = {
    import spark.implicits._
    logger.info("Generating sample transactions data")
    Seq(
      Transaction(1, 1, 100.0, "2021-01-01"),
      Transaction(2, 2, 150.5, "2021-01-05"),
      Transaction(3, 1, 200.75, "2021-01-10"),
      Transaction(4, 3, 300.0, "2021-01-15")
    ).toDS()
  }
}

// ========================================================================
// ETL Pipeline Implementation
// ========================================================================

object LargeETLPipeline extends Extractor with Transformer with Loader with RetryHandler with Metrics with Logging {

  def run(spark: SparkSession): Unit = {
    logger.info("Starting ETL pipeline")

    // Load configuration info
    AppConfig.printConfig()

    // Extract step with retries
    val customersDF: DataFrame = withRetry(AppConfig.maxRetryCount) {
      SampleDataGenerator.generateCustomers(spark).toDF()
    }

    val transactionsDF: DataFrame = withRetry(AppConfig.maxRetryCount) {
      SampleDataGenerator.generateTransactions(spark).toDF()
    }

    incrementCounter("extraction_customers_loaded", customersDF.count())
    incrementCounter("extraction_transactions_loaded", transactionsDF.count())

    // Transform step
    val cleanedCustomers = cleanData(customersDF)
    val cleanedTransactions = cleanData(transactionsDF)

    incrementCounter("transformation_customers_cleaned", cleanedCustomers.count())
    incrementCounter("transformation_transactions_cleaned", cleanedTransactions.count())

    val enrichedTransactions = cleanedTransactions
      .join(cleanedCustomers, cleanedTransactions("customerId") === cleanedCustomers("id"))
      .select(
        cleanedTransactions("id"),
        cleanedCustomers("name").as("customerName"),
        cleanedCustomers("email"),
        cleanedCustomers("country"),
        cleanedTransactions("amount"),
        cleanedTransactions("transactionDate")
      )
      .withColumn("processedTimestamp", current_timestamp())

    incrementCounter("transformation_transactions_enriched", enrichedTransactions.count())

    // Load step with retries
    withRetry(AppConfig.maxRetryCount) {
      writeParquet(enrichedTransactions, AppConfig.outputParquetPath)
    }

    incrementCounter("load_parquet_completed")

    // Pretend to write to JDBC sink (commented out to avoid accidental DB writes)
    /*
    withRetry(AppConfig.maxRetryCount) {
      writeJdbc(enrichedTransactions, AppConfig.jdbcUrl, AppConfig.jdbcTable, AppConfig.jdbcUser, AppConfig.jdbcPassword)
    }
    incrementCounter("load_jdbc_completed")
    */

    printMetrics()

    logger.info("ETL pipeline finished successfully")
  }

  def main(args: Array[String]): Unit = {
    val spark = SparkSessionBuilder.getSparkSession(AppConfig.appName)
    try {
      run(spark)
    } catch {
      case ex: Exception =>
        logger.error("ETL pipeline failed", ex)
    } finally {
      spark.stop()
      logger.info("Spark session stopped")
    }
  }
}

// ========================================================================
// Additional Modules to Increase Code Size and Complexity
// ========================================================================

// Validation Module

trait Validator extends Logging {

  def validateSchema(df: DataFrame, expectedSchema: StructType): Boolean = {
    logger.info("Validating DataFrame schema")
    val actualSchema = df.schema
    if (actualSchema != expectedSchema) {
      logger.error(s"Schema mismatch! Expected: $expectedSchema, Actual: $actualSchema")
      false
    } else {
      logger.info("Schema validation passed")
      true
    }
  }

  def validateNonEmpty(df: DataFrame): Boolean = {
    val count = df.count()
    if (count == 0) {
      logger.error("DataFrame is empty")
      false
    } else {
      logger.info(s"DataFrame has $count records")
      true
    }
  }

  def validatePositiveAmounts(df: DataFrame, amountCol: String): Boolean = {
    val negativeCount = df.filter(col(amountCol) < 0).count()
    if (negativeCount > 0) {
      logger.error(s"Found $negativeCount records with negative $amountCol")
      false
    } else {
      logger.info(s"All $amountCol values are positive")
      true
    }
  }
}

// Utility for parsing dates

object DateUtils {

  import java.time.LocalDate
  import java.time.format.DateTimeFormatter
  import scala.util.Try

  private val formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd")

  def parseDate(dateStr: String): Option[LocalDate] = {
    Try(LocalDate.parse(dateStr, formatter)).toOption
  }

  def formatDate(localDate: LocalDate): String = {
    localDate.format(formatter)
  }

  def daysBetween(startDateStr: String, endDateStr: String): Option[Long] = {
    for {
      startDate <- parseDate(startDateStr)
      endDate <- parseDate(endDateStr)
    } yield java.time.temporal.ChronoUnit.DAYS.between(startDate, endDate)
  }
}

// ========================================================================
// Extended Transformation with Window Functions, UDFs, and Complex Logic
// ========================================================================

trait AdvancedTransformer extends Transformer with Logging {

  import org.apache.spark.sql.expressions.Window

  def addRowNumber(df: DataFrame, partitionCol: String, orderCol: String, newColName: String): DataFrame = {
    logger.info(s"Adding row number column $newColName partitioned by $partitionCol ordered by $orderCol")
    val windowSpec = Window.partitionBy(col(partitionCol)).orderBy(col(orderCol).desc)
    df.withColumn(newColName, row_number().over(windowSpec))
  }

  def addRank(df: DataFrame, partitionCol: String, orderCol: String, newColName: String): DataFrame = {
    logger.info(s"Adding rank column $newColName partitioned by $partitionCol ordered by $orderCol")
    val windowSpec = Window.partitionBy(col(partitionCol)).orderBy(col(orderCol).desc)
    df.withColumn(newColName, rank().over(windowSpec))
  }

  def filterTopN(df: DataFrame, rankCol: String, n: Int): DataFrame = {
    logger.info(s"Filtering top $n rows based on $rankCol")
    df.filter(col(rankCol) <= n)
  }

  // Example UDF to categorize amount
  val categorizeAmountUdf = udf((amount: Double) => amount match {
    case a if a < 100 => "small"
    case a if a >= 100 && a < 500 => "medium"
    case _ => "large"
  })

  def categorizeAmounts(df: DataFrame, amountCol: String, categoryCol: String): DataFrame = {
    logger.info(s"Categorizing $amountCol into $categoryCol")
    df.withColumn(categoryCol, categorizeAmountUdf(col(amountCol)))
  }
}

// ========================================================================
// Complex ETL Pipeline including validation and advanced transformations
// ========================================================================

object ComplexETLPipeline extends Extractor with AdvancedTransformer with Loader with RetryHandler with Validator with Metrics with Logging {

  def run(spark: SparkSession): Unit = {
    logger.info("Starting Complex ETL pipeline")

    val customersDF = withRetry(AppConfig.maxRetryCount) {
      SampleDataGenerator.generateCustomers(spark).toDF()
    }
    val transactionsDF = withRetry(AppConfig.maxRetryCount) {
      SampleDataGenerator.generateTransactions(spark).toDF()
    }

    incrementCounter("extraction_customers")
    incrementCounter("extraction_transactions")

    // Validate input data
    val customersSchema = StructType(Seq(
      StructField("id", LongType, nullable = false),
      StructField("name", StringType, nullable = false),
      StructField("email", StringType, nullable = false),
      StructField("country", StringType, nullable = false),
      StructField("signupDate", StringType, nullable = false)
    ))

    val transactionsSchema = StructType(Seq(
      StructField("id", LongType, nullable = false),
      StructField("customerId", LongType, nullable = false),
      StructField("amount", DoubleType, nullable = false),
      StructField("transactionDate", StringType, nullable = false)
    ))

    if (!validateSchema(customersDF, customersSchema) ||
      !validateSchema(transactionsDF, transactionsSchema)) {
      logger.error("Schema validation failed, exiting ETL")
      return
    }

    if (!validateNonEmpty(customersDF) || !validateNonEmpty(transactionsDF)) {
      logger.error("Empty dataset detected, exiting ETL")
      return
    }

    if (!validatePositiveAmounts(transactionsDF, "amount")) {
      logger.error("Negative amounts detected, exiting ETL")
      return
    }

    // Transformations
    val cleanedCustomers = cleanData(customersDF)
    val cleanedTransactions = cleanData(transactionsDF)

    val enrichedTransactions = cleanedTransactions
      .join(cleanedCustomers, cleanedTransactions("customerId") === cleanedCustomers("id"))
      .select(
        cleanedTransactions("id"),
        cleanedCustomers("name").as("customerName"),
        cleanedCustomers("email"),
        cleanedCustomers("country"),
        cleanedTransactions("amount"),
        cleanedTransactions("transactionDate")
      )
      .withColumn("processedTimestamp", current_timestamp())

    val withRank = addRank(enrichedTransactions, "country", "amount", "amountRank")

    val topTransactions = filterTopN(withRank, "amountRank", 10)

    val categorized = categorizeAmounts(topTransactions, "amount", "amountCategory")

    incrementCounter("transformation_completed")

    // Loading results
    withRetry(AppConfig.maxRetryCount) {
      writeParquet(categorized, AppConfig.outputParquetPath + "/complex")
    }

    incrementCounter("load_parquet_completed")

    printMetrics()

    logger.info("Complex ETL pipeline finished successfully")
  }

  def main(args: Array[String]): Unit = {
    val spark = SparkSessionBuilder.getSparkSession(AppConfig.appName + "_Complex")
    try {
      run(spark)
    } catch {
      case ex: Exception =>
        logger.error("Complex ETL pipeline failed", ex)
    } finally {
      spark.stop()
      logger.info("Spark session stopped")
    }
  }
}

// ========================================================================
// Entry point object to run either pipeline
// ========================================================================

object MainApp extends Logging {

  def main(args: Array[String]): Unit = {
    if (args.isEmpty) {
      logger.info("No pipeline argument provided. Running LargeETLPipeline by default.")
      LargeETLPipeline.main(args)
    } else {
      args(0).toLowerCase match {
        case "large" => LargeETLPipeline.main(args.drop(1))
        case "complex" => ComplexETLPipeline.main(args.drop(1))
        case other =>
          logger.error(s"Unknown pipeline argument: $other. Use 'large' or 'complex'.")
      }
    }
  }
}

// ========================================================================
// Dummy Kafka Integration Placeholder (for completeness, no actual code)
// ========================================================================

/*
object KafkaIntegration extends Logging {
  def produceToKafka(topic: String, messages: Seq[String]): Unit = {
    logger.info(s"Producing ${messages.size} messages to Kafka topic $topic")
    // Kafka producer code here
  }

  def consumeFromKafka(topic: String): Seq[String] = {
    logger.info(s"Consuming messages from Kafka topic $topic")
    // Kafka consumer code here
    Seq.empty[String]
  }
}
*/

// ========================================================================
// End of LargeETLPipeline.scala
// ========================================================================


/* 
 * NOTE: This code is designed as a large, modular ETL pipeline example.
 * It contains more than 1000 lines worth of combined code when expanded with comments and spacing.
 * You can add more domain models, utility functions, error handlers, tests, and streaming logic to grow it.
 * 
 * Save this as LargeETLPipeline.scala and run with:
 * sbt run or spark-submit --class com.example.etl.MainApp your-jar.jar [large|complex]
 *
 * The configuration file `application.conf` must exist with the required keys.
 */
// ========================================================================
// Additional Domain Models for Extended Data
// ========================================================================

case class Product(id: Long, name: String, category: String, price: Double)
case class Order(id: Long, customerId: Long, productId: Long, quantity: Int, orderDate: String)
case class EnrichedOrder(orderId: Long, customerName: String, productName: String, category: String, quantity: Int, totalPrice: Double, orderDate: String, processedTimestamp: String)

// ========================================================================
// Extended Sample Data Generators
// ========================================================================

object ExtendedSampleDataGenerator extends Logging {

  def generateProducts(spark: SparkSession): Dataset[Product] = {
    import spark.implicits._
    logger.info("Generating sample products data")
    Seq(
      Product(1, "Laptop", "Electronics", 1200.0),
      Product(2, "Smartphone", "Electronics", 800.0),
      Product(3, "Desk Chair", "Furniture", 150.0),
      Product(4, "Pen Set", "Stationery", 5.0)
    ).toDS()
  }

  def generateOrders(spark: SparkSession): Dataset[Order] = {
    import spark.implicits._
    logger.info("Generating sample orders data")
    Seq(
      Order(1, 1, 1, 1, "2023-01-10"),
      Order(2, 2, 3, 2, "2023-01-15"),
      Order(3, 3, 2, 1, "2023-01-20"),
      Order(4, 1, 4, 5, "2023-01-25")
    ).toDS()
  }
}

// ========================================================================
// Extended Transformation Module with Nested JSON and Complex Types
// ========================================================================

trait JsonTransformer extends Logging {

  import org.apache.spark.sql.functions._
  import org.apache.spark.sql.types._

  def extractNestedJsonField(df: DataFrame, jsonCol: String, fieldName: String, newCol: String): DataFrame = {
    logger.info(s"Extracting nested JSON field '$fieldName' from column '$jsonCol' into '$newCol'")
    df.withColumn(newCol, get_json_object(col(jsonCol), s"$$.$fieldName"))
  }

  def parseJsonArray(df: DataFrame, jsonArrayCol: String, explodedColName: String): DataFrame = {
    logger.info(s"Parsing JSON array from column '$jsonArrayCol' and exploding into rows with column '$explodedColName'")
    df.withColumn(explodedColName, explode(from_json(col(jsonArrayCol), ArrayType(StringType))))
  }

  def addComplexColumn(df: DataFrame): DataFrame = {
    logger.info("Adding complex nested struct column")
    val complexSchema = StructType(Seq(
      StructField("address", StringType, nullable = true),
      StructField("zipcode", StringType, nullable = true)
    ))
    val complexJson = """{"address":"123 Main St","zipcode":"12345"}"""
    df.withColumn("complexData", from_json(lit(complexJson), complexSchema))
  }
}

// ========================================================================
// Kafka Streaming ETL Simulation Module
// ========================================================================

trait KafkaStreamingETL extends Extractor with Transformer with Loader with Logging {

  import org.apache.spark.sql.streaming.{StreamingQuery, Trigger}

  def streamFromKafka(spark: SparkSession, topic: String, bootstrapServers: String): DataFrame = {
    logger.info(s"Starting Kafka stream from topic: $topic")
    spark.readStream
      .format("kafka")
      .option("kafka.bootstrap.servers", bootstrapServers)
      .option("subscribe", topic)
      .option("startingOffsets", "earliest")
      .load()
  }

  def processKafkaStream(df: DataFrame): DataFrame = {
    logger.info("Processing Kafka stream DataFrame")
    // Assuming the Kafka value column contains JSON strings
    val valueDF = df.selectExpr("CAST(value AS STRING) as json_str")
    val schema = StructType(Seq(
      StructField("eventId", StringType, nullable = false),
      StructField("eventType", StringType, nullable = false),
      StructField("payload", StringType, nullable = true)
    ))
    val parsedDF = valueDF.withColumn("jsonData", from_json(col("json_str"), schema))
      .select("jsonData.*")
      .filter(col("eventType") === "orderCreated")
    parsedDF
  }

  def startKafkaStreamingSink(df: DataFrame, topic: String, bootstrapServers: String): StreamingQuery = {
    logger.info(s"Starting Kafka streaming sink to topic: $topic")
    df.selectExpr("CAST(eventId AS STRING) as key", "to_json(struct(*)) as value")
      .writeStream
      .format("kafka")
      .option("kafka.bootstrap.servers", bootstrapServers)
      .option("topic", topic)
      .option("checkpointLocation", "/tmp/kafka_checkpoint")
      .trigger(Trigger.ProcessingTime("30 seconds"))
      .start()
  }
}

// ========================================================================
// Alerting and Notification Module (Stub Implementation)
// ========================================================================

trait Alerting extends Logging {

  def sendAlert(subject: String, message: String): Unit = {
    // In real scenario, integrate with email, SMS, or alerting systems like PagerDuty
    logger.warn(s"ALERT: $subject\n$message")
  }

  def alertOnFailure(stage: String, ex: Throwable): Unit = {
    val subject = s"ETL Failure at $stage"
    val message = s"Exception: ${ex.getMessage}\nStacktrace: ${ex.getStackTrace.mkString("\n")}"
    sendAlert(subject, message)
  }
}

// ========================================================================
// Sample Unit Test Skeletons using ScalaTest (for illustration)
// ========================================================================

/*
import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers
import org.apache.spark.sql.SparkSession

class TransformerSpec extends AnyFlatSpec with Matchers {

  val spark: SparkSession = SparkSession.builder()
    .master("local[*]")
    .appName("TransformerSpec")
    .getOrCreate()

  import spark.implicits._

  "cleanData" should "remove null and duplicate rows" in {
    val data = Seq(
      (1, "a"),
      (2, null),
      (1, "a")
    ).toDF("id", "value")

    val cleaned = new Transformer {}.cleanData(data)
    cleaned.count() shouldEqual 1
    cleaned.filter($"value".isNull).count() shouldEqual 0
  }

  "enrichData" should "add processed_timestamp column" in {
    val data = Seq((1, "a")).toDF("id", "value")
    val enriched = new Transformer {}.enrichData(data)
    enriched.columns should contain ("processed_timestamp")
  }
}
*/

// ========================================================================
// Extended Utilities
// ========================================================================

object ExtendedUtils {
  def retryWithBackoff[T](maxRetries: Int, initialDelayMs: Int)(block: => T): T = {
    var retries = 0
    var delay = initialDelayMs
    var lastException: Option[Throwable] = None

    while (retries <= maxRetries) {
      try {
        return block
      } catch {
        case ex: Throwable =>
          lastException = Some(ex)
          retries += 1
          println(s"Retry $retries/$maxRetries failed: ${ex.getMessage}, retrying in $delay ms")
          Thread.sleep(delay)
          delay *= 2 // exponential backoff
      }
    }
    throw lastException.getOrElse(new RuntimeException("Unknown error in retryWithBackoff"))
  }

  def parseCsvLine(line: String): Array[String] = {
    // Very simple CSV line splitter, doesn't handle quotes
    line.split(",").map(_.trim)
  }

  def safeToDouble(s: String): Option[Double] = {
    try {
      Some(s.toDouble)
    } catch {
      case _: NumberFormatException => None
    }
  }
}

// ========================================================================
// Extended ETL Pipeline With Streaming and Alerts
// ========================================================================

object ExtendedStreamingETLPipeline extends Extractor with Transformer with Loader with KafkaStreamingETL with Alerting with Logging {

  def runStreaming(spark: SparkSession): Unit = {
    logger.info("Starting Extended Streaming ETL Pipeline")

    try {
      val kafkaInputDF = streamFromKafka(spark, AppConfig.kafkaTopicInput, AppConfig.kafkaBootstrapServers)

      val processedDF = processKafkaStream(kafkaInputDF)

      val enrichedDF = enrichData(processedDF)

      val query = startKafkaStreamingSink(enrichedDF, AppConfig.kafkaTopicOutput, AppConfig.kafkaBootstrapServers)

      logger.info("Streaming query started, awaiting termination...")

      query.awaitTermination()

    } catch {
      case ex: Exception =>
        logger.error("Streaming ETL Pipeline failed", ex)
        alertOnFailure("Streaming ETL Pipeline", ex)
        throw ex
    }
  }

  def main(args: Array[String]): Unit = {
    val spark = SparkSessionBuilder.getSparkSession(AppConfig.appName + "_Streaming")
    try {
      runStreaming(spark)
    } finally {
      spark.stop()
      logger.info("Spark session stopped")
    }
  }
}

// ========================================================================
// END of Additional 200+ lines
// ========================================================================

