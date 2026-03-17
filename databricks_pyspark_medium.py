from pyspark.sql import SparkSession
from pyspark.sql.functions import col, concat_ws, trim, coalesce, max as spark_max, current_date, expr, rank, when, year, month, avg, count
from pyspark.sql.window import Window

# Initialize Spark session
spark = SparkSession.builder.appName("UnifiedQuery").getOrCreate()

# Load tables
corporate_cust_details = spark.table("corp_customer.corporate_cust_details")
corporate_cust_payments = spark.table("corp_customer.corporate_cust_payments")
corporate_cust_plans = spark.table("corp_customer.corporate_cust_plans")
device_models = spark.table("corp_customer.device_models")
corporate_cust_contact = spark.table("corp_customer.corporate_cust_contact")
customer_support_tickets = spark.table("corp_customer.customer_support_tickets")
payment_history = spark.table("corp_customer.payment_history")
device_repairs = spark.table("corp_customer.device_repairs")
subscription_renewals = spark.table("corp_customer.subscription_renewals")
payment_adjustments = spark.table("corp_customer.payment_adjustments")

# Query 1: Details for "Basic Plan" Customers
query1 = (corporate_cust_details.alias("A")
          .join(corporate_cust_payments.alias("B"), col("A.corp_subscriberid") == col("B.corp_subscriberid"), "left")
          .join(corporate_cust_plans.alias("C"), col("C.planname") == col("B.planname"), "left")
          .join(device_models.alias("D"), col("D.devicemodel") == col("A.devicemodel"), "left")
          .join(corporate_cust_contact.alias("E"), col("E.planname") == col("C.planname"), "left")
          .where((col("A.roamingtype") == "Local") | (col("A.planname") == "Basic Plan"))
          .groupBy("A.corp_subscriberid", "A.planname", "A.devicemodel", "A.paymentstatus", "A.roamingtype", "A.planstartdate", "C.planname", "D.devicemodel")
          .agg(
              concat_ws('|',
                        col("A.corp_subscriberid"),
                        trim(col("A.planname")),
                        expr("CAST(SUM(B.amount) AS DECIMAL(10,2))"),
                        count(col("B.paymentid")),
                        trim(col("A.devicemodel")),
                        coalesce(spark_max(col("B.paymentdate")), expr("DATE '1900-01-01'")),
                        when(col("A.paymentstatus") == "Late", "Overdue").otherwise("On Time"),
                        when(col("A.roamingtype") == "International", "Roaming").otherwise("Local"),
                        year(col("A.planstartdate")).cast("string"),
                        month(col("A.planstartdate")).cast("string"),
                        trim(col("C.planname")),
                        when(expr("SUM(B.amount) >= 150"), "High Payment")
                        .when(expr("SUM(B.amount) >= 100"), "Medium Payment")
                        .otherwise("Low Payment"),
                        spark_max(col("B.paymentdate")),
                        (current_date() - spark_max(col("B.paymentdate"))),
                        trim(col("D.devicemodel")),
                        rank().over(Window.orderBy(expr("SUM(B.amount) DESC"))),
                        expr("'N/A'"),
                        expr("'N/A'")
                        ).alias("UnifiedColumn")
          ))

# Query 2: Support ticket details for "Standard Plan" Customers
query2 = (corporate_cust_details.alias("A")
          .join(corporate_cust_payments.alias("B"), col("A.corp_subscriberid") == col("B.corp_subscriberid"), "left")
          .join(corporate_cust_plans.alias("C"), col("C.planname") == col("B.planname"), "left")
          .join(device_models.alias("D"), col("D.devicemodel") == col("A.devicemodel"), "left")
          .join(customer_support_tickets.alias("F"), col("F.planname") == col("C.planname"), "left")
          .where((col("A.roamingtype") == "Local") | (col("C.planname") == "Standard Plan"))
          .groupBy("A.corp_subscriberid", "C.planname", "D.devicemodel", "D.manufacturer", "C.plandescription", "C.plancost", year(col("B.paymentdate")))
          .agg(
              concat_ws('|',
                        col("A.corp_subscriberid"),
                        trim(col("C.planname")),
                        expr("CAST(AVG(B.amount) AS DECIMAL(10,2))"),
                        count(col("F.ticketid")),
                        trim(col("D.devicemodel")),
                        coalesce(spark_max(col("B.paymentdate")), expr("DATE '1900-01-01'")),
                        expr("'N/A'"),
                        when(col("D.manufacturer").isin("Apple", "Samsung"), "Top Brand").otherwise("Other Brand"),
                        year(col("B.paymentdate")).cast("string"),
                        expr("'N/A'"),
                        col("C.plandescription"),
                        when(expr("AVG(B.amount) >= 150"), "High Payment")
                        .when(expr("AVG(B.amount) >= 100"), "Medium Payment")
                        .otherwise("Low Payment"),
                        expr("'N/A'"),
                        expr("'N/A'"),
                        trim(col("D.devicemodel")),
                        rank().over(Window.orderBy(col("C.plancost").desc())),
                        expr("'N/A'"),
                        expr("'N/A'")
                        ).alias("UnifiedColumn")
          ))

# Query 3: Premium plan support tickets and adjustment tracking
query3 = (payment_history.alias("G")
          .join(device_repairs.alias("H"), col("G.corp_subscriberid") == col("H.corp_subscriberid"), "left")
          .join(subscription_renewals.alias("J"), col("J.corp_subscriberid") == col("G.corp_subscriberid"), "left")
          .join(payment_adjustments.alias("K"), col("K.corp_subscriberid") == col("J.corp_subscriberid"), "left")
          .where(col("J.planname") == "Premium Plan")
          .groupBy("G.corp_subscriberid", "J.planname", "H.deviceid", year(col("G.changedate")))
          .agg(
              concat_ws('|',
                        col("G.corp_subscriberid"),
                        col("J.planname"),
                        expr("CAST(AVG(G.newamount) AS DECIMAL(10,2))"),
                        count(col("K.adjustmentid")),
                        trim(col("H.deviceid")),
                        coalesce(spark_max(col("G.changedate")), expr("DATE '1900-01-01'")),
                        spark_max(when(col("G.newamount") > col("G.oldamount"), "Increased")
                                  .when(col("G.newamount") < col("G.oldamount"), "Decreased")
                                  .otherwise("No Change")),
                        expr("'N/A'"),
                        year(col("G.changedate")).cast("string"),
                        expr("'N/A'"),
                        expr("'N/A'"),
                        when(expr("AVG(G.newamount) >= 150"), "High Payment")
                        .when(expr("AVG(G.newamount) >= 100"), "Medium Payment")
                        .otherwise("Low Payment"),
                        expr("'N/A'"),
                        expr("'N/A'"),
                        trim(col("H.deviceid")),
                        rank().over(Window.partitionBy(col("G.corp_subscriberid")).orderBy(spark_max(col("G.changedate")).desc())),
                        expr("'N/A'"),
                        expr("'N/A'")
                        ).alias("UnifiedColumn")
          ))

# Ensure all queries have the same number of columns
query1 = query1.selectExpr("UnifiedColumn")
query2 = query2.selectExpr("UnifiedColumn")
query3 = query3.selectExpr("UnifiedColumn")

# Combine queries using union
unified_query = query1.union(query2).union(query3)

# Final selection and ordering
final_result = unified_query.orderBy("UnifiedColumn")

# Show the result
final_result.show()
