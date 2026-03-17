%scala
// Running the SQL query directly without showing the query text
val result = spark.sql("""
WITH UnifiedData AS (
  SELECT
      CONCAT(
          A.Corp_SubscriberID, '|',
          TRIM(A.PlanName), '|',
          CAST(SUM(B.Amount) AS DECIMAL(10,2)), '|',
          COUNT(B.PaymentID), '|',
          TRIM(A.DeviceModel), '|',
          COALESCE(MAX(B.PaymentDate), DATE '1900-01-01'), '|',
          CASE
              WHEN A.PaymentStatus = 'Late' THEN 'Overdue'
              ELSE 'On Time'
          END, '|',
          CASE
              WHEN A.RoamingType = 'International' THEN 'Roaming'
              ELSE 'Local'
          END, '|',
          CAST(YEAR(A.PlanStartDate) AS STRING), '|',
          LPAD(CAST(MONTH(A.PlanStartDate) AS STRING), 2, '0'), '|',
          TRIM(C.PlanName), '|',
          CASE
              WHEN SUM(B.Amount) >= 150 THEN 'High Payment'
              WHEN SUM(B.Amount) >= 100 THEN 'Medium Payment'
              ELSE 'Low Payment'
          END, '|',
          MAX(B.PaymentDate), '|',
          (CURRENT_DATE - MAX(B.PaymentDate)), '|',
          TRIM(D.DeviceModel), '|',
          RANK() OVER (ORDER BY SUM(B.Amount) DESC), '|',
          'N/A', '|',
          'N/A'
      ) AS UnifiedColumn
  FROM CORP_CUSTOMER.CORPORATE_CUST_DETAILS A
  LEFT JOIN CORP_CUSTOMER.CORPORATE_CUST_PAYMENTS B ON A.Corp_SubscriberID = B.Corp_SubscriberID
  LEFT JOIN CORP_CUSTOMER.CORPORATE_CUST_PLANS C ON C.PlanName = B.PlanName
  LEFT JOIN CORP_CUSTOMER.DEVICE_MODELS D ON D.DeviceModel = A.DeviceModel
  LEFT JOIN CORP_CUSTOMER.CORPORATE_CUST_CONTACT E ON E.PlanName = C.PlanName
  WHERE A.RoamingType = 'Local' OR A.PlanName = 'Basic Plan'
  GROUP BY A.Corp_SubscriberID, A.PlanName, A.DeviceModel, A.PaymentStatus, A.RoamingType, A.PlanStartDate, C.PlanName, D.DeviceModel

  UNION

  SELECT
      CONCAT(
          A.Corp_SubscriberID, '|',
          TRIM(C.PlanName), '|',
          CAST(AVG(B.Amount) AS DECIMAL(10,2)), '|',
          COUNT(F.TicketID), '|',
          TRIM(D.DeviceModel), '|',
          COALESCE(MAX(B.PaymentDate), DATE '1900-01-01'), '|',
          'N/A', '|',
          CASE
              WHEN D.Manufacturer IN ('Apple', 'Samsung') THEN 'Top Brand'
              ELSE 'Other Brand'
          END, '|',
          CAST(YEAR(B.PaymentDate) AS STRING), '|',
          'N/A', '|',
          C.PlanDescription, '|',
          CASE
              WHEN AVG(B.Amount) >= 150 THEN 'High Payment'
              WHEN AVG(B.Amount) >= 100 THEN 'Medium Payment'
              ELSE 'Low Payment'
          END, '|',
          'N/A', '|',
          'N/A', '|',
          TRIM(D.DeviceModel), '|',
          RANK() OVER (ORDER BY C.PlanCost DESC), '|',
          'N/A', '|',
          'N/A'
      ) AS UnifiedColumn
  FROM CORP_CUSTOMER.CORPORATE_CUST_DETAILS A
  LEFT JOIN CORP_CUSTOMER.CORPORATE_CUST_PAYMENTS B ON A.Corp_SubscriberID = B.Corp_SubscriberID
  LEFT JOIN CORP_CUSTOMER.CORPORATE_CUST_PLANS C ON C.PlanName = B.PlanName
  LEFT JOIN CORP_CUSTOMER.DEVICE_MODELS D ON D.DeviceModel = A.DeviceModel
  LEFT JOIN CORP_CUSTOMER.CUSTOMER_SUPPORT_TICKETS F ON F.PlanName = C.PlanName
  WHERE A.RoamingType = 'Local' OR C.PlanName = 'Standard Plan'
  GROUP BY A.Corp_SubscriberID, C.PlanName, D.DeviceModel, D.Manufacturer, C.PlanDescription, C.PlanCost, YEAR(B.PaymentDate)

  UNION

  SELECT
      CONCAT(
          G.Corp_SubscriberID, '|',
          J.PlanName, '|',
          CAST(AVG(G.NewAmount) AS DECIMAL(10,2)), '|',
          COUNT(K.AdjustmentID), '|',
          TRIM(H.DeviceID), '|',
          COALESCE(MAX(G.ChangeDate), DATE '1900-01-01'), '|',
          MAX(
              CASE
                  WHEN G.NewAmount > G.OldAmount THEN 'Increased'
                  WHEN G.NewAmount < G.OldAmount THEN 'Decreased'
                  ELSE 'No Change'
              END
          ), '|',
          'N/A', '|',
          CAST(YEAR(G.ChangeDate) AS STRING), '|',
          'N/A', '|',
          'N/A', '|',
          CASE
              WHEN AVG(G.NewAmount) >= 150 THEN 'High Payment'
              WHEN AVG(G.NewAmount) >= 100 THEN 'Medium Payment'
              ELSE 'Low Payment'
          END, '|',
          'N/A', '|',
          'N/A', '|',
          TRIM(H.DeviceID), '|',
          RANK() OVER (PARTITION BY G.Corp_SubscriberID ORDER BY MAX(G.ChangeDate) DESC), '|',
          'N/A', '|',
          'N/A'
      ) AS UnifiedColumn
  FROM CORP_CUSTOMER.PAYMENT_HISTORY G
  LEFT JOIN CORP_CUSTOMER.DEVICE_REPAIRS H ON G.Corp_SubscriberID = H.Corp_SubscriberID
  LEFT JOIN CORP_CUSTOMER.SUBSCRIPTION_RENEWALS J ON J.Corp_SubscriberID = G.Corp_SubscriberID
  LEFT JOIN CORP_CUSTOMER.PAYMENT_ADJUSTMENTS K ON K.Corp_SubscriberID = J.Corp_SubscriberID
  WHERE J.PlanName = 'Premium Plan'
  GROUP BY G.Corp_SubscriberID, J.PlanName, H.DeviceID, YEAR(G.ChangeDate)
)
SELECT * FROM UnifiedData
ORDER BY UnifiedColumn ASC
""")

// Display the result without showing the query itself
result.show(truncate = false)
