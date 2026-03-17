-- Create the CORPORATE_CUST_PAYMENTS table
CREATE TABLE corp_customer.corporate_cust_payments (
    paymentid BIGINT GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1) NOT NULL,
    corp_subscriberid STRING NOT NULL,
    planname STRING NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    paymentdate DATE NOT NULL,
    paymentstatus STRING,
    PRIMARY KEY (paymentid)
);

-- Insert data into CORPORATE_CUST_PAYMENTS
INSERT INTO corp_customer.corporate_cust_payments (corp_subscriberid, planname, amount, paymentdate, paymentstatus)
VALUES 
('CUST001', 'Premium Plan', 120.00, '2023-01-05', 'On Time'),
('CUST002', 'Basic Plan', 50.00, '2023-02-20', 'Late'),
('CUST003', 'Standard Plan', 75.00, '2023-03-15', 'On Time'),
('CUST004', 'Enterprise Plan', 200.00, '2023-04-25', 'On Time'),
('CUST005', 'Budget Plan', 30.00, '2023-05-10', 'On Time'),
('CUST006', 'Family Plan', 150.00, '2023-06-15', 'Late');

-- Create the CORPORATE_CUST_DETAILS table
CREATE TABLE corp_customer.corporate_cust_details (
    corp_subscriberid STRING NOT NULL,
    planname STRING NOT NULL,
    plancost DECIMAL(10, 2) NOT NULL,
    devicemodel STRING,
    paymentstatus STRING,
    roamingtype STRING,
    planstartdate DATE NOT NULL,
    devicecost DECIMAL(10, 2),
    PRIMARY KEY (corp_subscriberid, planname, planstartdate)
);

-- Insert data into CORPORATE_CUST_DETAILS
INSERT INTO corp_customer.corporate_cust_details (corp_subscriberid, planname, plancost, devicemodel, paymentstatus, roamingtype, planstartdate, devicecost)
VALUES
('CUST001', 'Premium Plan', 120.00, 'iPhone 14', 'On Time', 'Local', '2023-01-01', 800.00),
('CUST002', 'Basic Plan', 50.00, 'Samsung Galaxy S21', 'Late', 'International', '2023-02-15', 600.00),
('CUST003', 'Standard Plan', 75.00, 'Google Pixel 6', 'On Time', 'Local', '2023-03-10', 700.00),
('CUST004', 'Enterprise Plan', 200.00, 'OnePlus 9', 'On Time', 'International', '2023-04-20', 750.00),
('CUST005', 'Budget Plan', 30.00, 'Nokia 3310', 'On Time', 'Local', '2023-05-05', 100.00),
('CUST006', 'Family Plan', 150.00, 'iPhone 13', 'Late', 'International', '2023-06-12', 900.00);

-- Create the CORPORATE_CUST_PLANS table
CREATE TABLE corp_customer.corporate_cust_plans (
    planid BIGINT GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1) NOT NULL,
    planname STRING NOT NULL,
    plandescription STRING,
    plancost DECIMAL(10, 2) NOT NULL,
    PRIMARY KEY (planid)
);

-- Insert data into CORPORATE_CUST_PLANS
INSERT INTO corp_customer.corporate_cust_plans (planname, plandescription, plancost)
VALUES 
('Family Plan', 'Family plan for multiple users', 150.00),
('Premium Plan', 'High-end plan with unlimited data and international roaming', 120.00),
('Basic Plan', 'Basic plan with limited data', 50.00),
('Standard Plan', 'Standard plan with moderate data limits', 75.00),
('Enterprise Plan', 'Enterprise-level plan with extensive features', 200.00),
('Budget Plan', 'Budget-friendly plan with minimal features', 30.00);

-- Create the DEVICE_MODELS table
CREATE TABLE corp_customer.device_models (
    deviceid BIGINT GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1) NOT NULL,
    devicemodel STRING NOT NULL,
    manufacturer STRING,
    PRIMARY KEY (deviceid)
);

-- Insert data into DEVICE_MODELS
INSERT INTO corp_customer.device_models (devicemodel, manufacturer)
VALUES
('iPhone 14', 'Apple'),
('Samsung Galaxy S21', 'Samsung'),
('Google Pixel 6', 'Google'),
('OnePlus 9', 'OnePlus'),
('Nokia 3310', 'Nokia'),
('iPhone 13', 'Apple');

-- Create the CORPORATE_CUST_CONTACT table
CREATE TABLE corp_customer.corporate_cust_contact (
    contactid BIGINT GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1) NOT NULL,
    corp_subscriberid STRING NOT NULL,
    planname STRING NOT NULL,
    planstartdate DATE NOT NULL,
    email STRING,
    phone STRING,
    address STRING,
    PRIMARY KEY (contactid)
);

-- Insert data into CORPORATE_CUST_CONTACT
INSERT INTO corp_customer.corporate_cust_contact (corp_subscriberid, planname, planstartdate, email, phone, address)
VALUES
('CUST001', 'Premium Plan', '2023-01-01', 'contact1@corp.com', '555-1234', '123 Corporate St City A'),
('CUST002', 'Basic Plan', '2023-02-15', 'contact2@corp.com', '555-5678', '456 Corporate Ave City B'),
('CUST003', 'Standard Plan', '2023-03-10', 'contact3@corp.com', '555-8765', '789 Corporate Blvd City C'),
('CUST004', 'Enterprise Plan', '2023-04-20', 'contact4@corp.com', '555-4321', '321 Corporate Ct City D'),
('CUST005', 'Budget Plan', '2023-05-05', 'contact5@corp.com', '555-2468', '654 Corporate Rd City E'),
('CUST006', 'Family Plan', '2023-06-12', 'contact6@corp.com', '555-1357', '987 Corporate Pkwy City F');

-- Create the CUSTOMER_SUPPORT_TICKETS table
CREATE TABLE corp_customer.customer_support_tickets (
    ticketid BIGINT GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1) NOT NULL,
    corp_subscriberid STRING NOT NULL,
    planname STRING NOT NULL,
    planstartdate DATE NOT NULL,
    issuedescription STRING,
    status STRING,
    createddate DATE NOT NULL,
    closeddate DATE,
    PRIMARY KEY (ticketid)
);

-- Insert data into CUSTOMER_SUPPORT_TICKETS
INSERT INTO corp_customer.customer_support_tickets (corp_subscriberid, planname, planstartdate, issuedescription, status, createddate, closeddate)
VALUES
('CUST001', 'Premium Plan', '2023-01-01', 'Issue with billing statement', 'Closed', '2023-01-10', '2023-01-15'),
('CUST002', 'Basic Plan', '2023-02-15', 'Device not functioning properly', 'Open', '2023-02-18', NULL),
('CUST003', 'Standard Plan', '2023-03-10', 'Need assistance with plan change', 'Closed', '2023-03-12', '2023-03-15'),
('CUST004', 'Enterprise Plan', '2023-04-20', 'Inquiry about international roaming', 'Open', '2023-04-22', NULL),
('CUST005', 'Budget Plan', '2023-05-05', 'Request for device upgrade', 'Closed', '2023-05-07', '2023-05-10'),
('CUST006', 'Family Plan', '2023-06-12', 'Issue with payment processing', 'Closed', '2023-06-20', '2023-06-25');



-- Create tables in Databricks SQL
CREATE TABLE corp_customer.payment_history (
    historyid BIGINT GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1) NOT NULL,
    paymentid INT NOT NULL,
    corp_subscriberid STRING NOT NULL,
    oldamount DECIMAL(10,2),
    newamount DECIMAL(10,2),
    changedate DATE NOT NULL,
    changereason STRING,
    PRIMARY KEY (paymentid)
);

INSERT INTO corp_customer.payment_history (paymentid, corp_subscriberid, oldamount, newamount, changedate, changereason) VALUES
(1, 'CUST001', 100.00, 120.00, '2023-01-10', 'Plan upgrade'),
(2, 'CUST002', 40.00, 50.00, '2023-02-18', 'Late fee applied'),
(3, 'CUST003', 70.00, 75.00, '2023-03-12', 'Data overuse charge'),
(4, 'CUST004', 180.00, 200.00, '2023-04-22', 'International roaming charge'),
(5, 'CUST005', 25.00, 30.00, '2023-05-07', 'Device upgrade'),
(6, 'CUST006', 140.00, 150.00, '2023-06-15', 'Plan adjustment'),
(7, 'CUST001', 120.00, 130.00, '2023-07-01', 'Tax adjustment'),
(8, 'CUST002', 50.00, 55.00, '2023-08-05', 'Billing error correction'),
(9, 'CUST003', 75.00, 78.00, '2023-09-10', 'Service fee update'),
(10, 'CUST004', 200.00, 220.00, '2023-10-02', 'Additional features added');

CREATE TABLE corp_customer.device_repairs (
    repairid BIGINT GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1) NOT NULL,
    deviceid INT NOT NULL,
    corp_subscriberid STRING NOT NULL,
    repairdescription STRING,
    repaircost DECIMAL(10,2),
    repairdate DATE NOT NULL,
    PRIMARY KEY (repairid)
);

INSERT INTO corp_customer.device_repairs (deviceid, corp_subscriberid, repairdescription, repaircost, repairdate) VALUES
(1, 'CUST001', 'Screen replacement', 150.00, '2023-02-01'),
(2, 'CUST002', 'Battery replacement', 50.00, '2023-03-05'),
(3, 'CUST003', 'Camera repair', 75.00, '2023-04-10'),
(4, 'CUST004', 'Motherboard replacement', 200.00, '2023-05-15'),
(5, 'CUST005', 'Software update', 30.00, '2023-06-20'),
(6, 'CUST006', 'Water damage repair', 120.00, '2023-07-25'),
(1, 'CUST001', 'Screen repair', 130.00, '2023-08-05'),
(2, 'CUST002', 'Speaker replacement', 60.00, '2023-09-10'),
(3, 'CUST003', 'Charging port repair', 45.00, '2023-10-01'),
(4, 'CUST004', 'Fingerprint sensor fix', 80.00, '2023-10-10');

CREATE TABLE corp_customer.roaming_records (
    roamingid BIGINT GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1) NOT NULL,
    corp_subscriberid STRING NOT NULL,
    planname STRING NOT NULL,
    planstartdate DATE NOT NULL,
    roamingcountry STRING,
    roamingstartdate DATE,
    roamingenddate DATE,
    roamingcharges DECIMAL(10,2),
    PRIMARY KEY (roamingid)
);

INSERT INTO corp_customer.roaming_records (corp_subscriberid, planname, planstartdate, roamingcountry, roamingstartdate, roamingenddate, roamingcharges) VALUES
('CUST001', 'Premium Plan', '2023-01-01', 'USA', '2023-01-15', '2023-01-20', 30.00),
('CUST002', 'Basic Plan', '2023-02-15', 'Canada', '2023-03-01', '2023-03-05', 25.00),
('CUST003', 'Standard Plan', '2023-03-10', 'UK', '2023-04-01', '2023-04-07', 40.00),
('CUST004', 'Enterprise Plan', '2023-04-20', 'Germany', '2023-05-10', '2023-05-20', 50.00),
('CUST005', 'Budget Plan', '2023-05-05', 'Australia', '2023-06-01', '2023-06-05', 20.00),
('CUST006', 'Family Plan', '2023-06-12', 'Japan', '2023-07-01', '2023-07-10', 45.00),
('CUST001', 'Premium Plan', '2023-01-01', 'France', '2023-08-01', '2023-08-10', 35.00),
('CUST002', 'Basic Plan', '2023-02-15', 'Mexico', '2023-09-05', '2023-09-12', 15.00),
('CUST003', 'Standard Plan', '2023-03-10', 'India', '2023-10-01', '2023-10-08', 30.00),
('CUST004', 'Enterprise Plan', '2023-04-20', 'Singapore', '2023-11-01', '2023-11-10', 55.00);

CREATE TABLE corp_customer.subscription_renewals (
    renewalid BIGINT GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1) NOT NULL,
    corp_subscriberid STRING NOT NULL,
    planname STRING NOT NULL,
    planstartdate DATE NOT NULL,
    renewaldate DATE NOT NULL,
    renewalamount DECIMAL(10,2),
    PRIMARY KEY (renewalid)
);

INSERT INTO corp_customer.subscription_renewals (corp_subscriberid, planname, planstartdate, renewaldate, renewalamount) VALUES
('CUST001', 'Premium Plan', '2023-01-01', '2024-01-01', 120.00),
('CUST002', 'Basic Plan', '2023-02-15', '2024-02-15', 50.00),
('CUST003', 'Standard Plan', '2023-03-10', '2024-03-10', 75.00),
('CUST004', 'Enterprise Plan', '2023-04-20', '2024-04-20', 200.00),
('CUST005', 'Budget Plan', '2023-05-05', '2024-05-05', 30.00),
('CUST006', 'Family Plan', '2023-06-12', '2024-06-12', 150.00);

CREATE TABLE corp_customer.payment_adjustments (
    adjustmentid BIGINT GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1) NOT NULL,
    paymentid INT NOT NULL,
    corp_subscriberid STRING NOT NULL,
    adjustmentamount DECIMAL(10,2),
    adjustmentreason STRING,
    adjustmentdate DATE NOT NULL,
    PRIMARY KEY (adjustmentid)
);

INSERT INTO corp_customer.payment_adjustments (paymentid, corp_subscriberid, adjustmentamount, adjustmentreason, adjustmentdate) VALUES
(1, 'CUST001', 10.00, 'Tax adjustment', '2023-01-15'),
(2, 'CUST002', -5.00, 'Late fee waiver', '2023-02-22'),
(3, 'CUST003', 15.00, 'Overpayment adjustment', '2023-03-18'),
(4, 'CUST004', -20.00, 'Customer loyalty discount', '2023-04-30'),
(5, 'CUST005', 5.00, 'Service fee adjustment', '2023-05-12'),
(6, 'CUST006', -10.00, 'Billing correction', '2023-06-20');

CREATE TABLE corp_customer.service_usage_logs (
    usagelogid BIGINT GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1) NOT NULL,
    corp_subscriberid STRING NOT NULL,
    planname STRING NOT NULL,
    planstartdate DATE NOT NULL,
    servicetype STRING,
    usageamount DECIMAL(10,2),
    usagedate DATE NOT NULL,
    PRIMARY KEY (usagelogid)
);

INSERT INTO corp_customer.service_usage_logs (corp_subscriberid, planname, planstartdate, servicetype, usageamount, usagedate) VALUES
('CUST001', 'Premium Plan', '2023-01-01', 'Data', 2.50, '2023-01-15'),
('CUST002', 'Basic Plan', '2023-02-15', 'Voice', 1.20, '2023-02-18'),
('CUST003', 'Standard Plan', '2023-03-10', 'Data', 3.75, '2023-03-20'),
('CUST004', 'Enterprise Plan', '2023-04-20', 'Roaming', 4.50, '2023-05-10'),
('CUST005', 'Budget Plan', '2023-05-05', 'SMS', 0.90, '2023-06-01'),
('CUST006', 'Family Plan', '2023-06-12', 'Data', 5.00, '2023-07-01');


WITH unified_query AS (
    -- Query 1: Details for "Basic Plan" Customers
    SELECT
        CONCAT_WS('|',
            a.corp_subscriberid,
            TRIM(a.planname),
            CAST(SUM(b.amount) AS DECIMAL(10,2)),
            COUNT(b.paymentid),
            TRIM(a.devicemodel),
            COALESCE(MAX(b.paymentdate), DATE '1900-01-01'),
            CASE
                WHEN a.paymentstatus = 'Late' THEN 'Overdue'
                ELSE 'On Time'
            END,
            CASE
                WHEN a.roamingtype = 'International' THEN 'Roaming'
                ELSE 'Local'
            END,
            CAST(YEAR(a.planstartdate) AS STRING),
            LPAD(CAST(MONTH(a.planstartdate) AS STRING), 2, '0'),
            TRIM(c.planname),
            CASE
                WHEN SUM(b.amount) >= 150 THEN 'High Payment'
                WHEN SUM(b.amount) >= 100 THEN 'Medium Payment'
                ELSE 'Low Payment'
            END,
            MAX(b.paymentdate),
            DATEDIFF(CURRENT_DATE, MAX(b.paymentdate)),
            TRIM(d.devicemodel),
            RANK() OVER (ORDER BY SUM(b.amount) DESC),
            'N/A',
            'N/A'
        ) AS unified_column
    FROM corp_customer.corporate_cust_details a
    LEFT JOIN corp_customer.corporate_cust_payments b ON a.corp_subscriberid = b.corp_subscriberid
    LEFT JOIN corp_customer.corporate_cust_plans c ON c.planname = b.planname
    LEFT JOIN corp_customer.device_models d ON d.devicemodel = a.devicemodel
    LEFT JOIN corp_customer.corporate_cust_contact e ON e.planname = c.planname
    WHERE a.roamingtype = 'Local' OR a.planname = 'Basic Plan'
    GROUP BY a.corp_subscriberid, a.planname, a.devicemodel, a.paymentstatus, a.roamingtype, a.planstartdate, c.planname, d.devicemodel

    UNION

    -- Query 2: Support ticket details for "Standard Plan" Customers
    SELECT
        CONCAT_WS('|',
            a.corp_subscriberid,
            TRIM(c.planname),
            CAST(AVG(b.amount) AS DECIMAL(10,2)),
            COUNT(f.ticketid),
            TRIM(d.devicemodel),
            COALESCE(MAX(b.paymentdate), DATE '1900-01-01'),
            'N/A',
            CASE
                WHEN d.manufacturer IN ('Apple', 'Samsung') THEN 'Top Brand'
                ELSE 'Other Brand'
            END,
            CAST(YEAR(b.paymentdate) AS STRING),
            'N/A',
            c.plandescription,
            CASE
                WHEN AVG(b.amount) >= 150 THEN 'High Payment'
                WHEN AVG(b.amount) >= 100 THEN 'Medium Payment'
                ELSE 'Low Payment'
            END,
            'N/A',
            'N/A',
            TRIM(d.devicemodel),
            RANK() OVER (ORDER BY c.plancost DESC),
            'N/A',
            'N/A'
        ) AS unified_column
    FROM corp_customer.corporate_cust_details a
    LEFT JOIN corp_customer.corporate_cust_payments b ON a.corp_subscriberid = b.corp_subscriberid
    LEFT JOIN corp_customer.corporate_cust_plans c ON c.planname = b.planname
    LEFT JOIN corp_customer.device_models d ON d.devicemodel = a.devicemodel
    LEFT JOIN corp_customer.customer_support_tickets f ON f.planname = c.planname
    WHERE a.roamingtype = 'Local' OR c.planname = 'Standard Plan'
    GROUP BY a.corp_subscriberid, c.planname, d.devicemodel, d.manufacturer, c.plandescription, c.plancost, YEAR(b.paymentdate)

    UNION

    -- Query 3: Premium plan support tickets and adjustment tracking
    SELECT
        CONCAT_WS('|',
            g.corp_subscriberid,
            j.planname,
            CAST(AVG(g.newamount) AS DECIMAL(10,2)),
            COUNT(k.adjustmentid),
            TRIM(h.deviceid),
            COALESCE(MAX(g.changedate), DATE '1900-01-01'),
            MAX(
                CASE
                    WHEN g.newamount > g.oldamount THEN 'Increased'
                    WHEN g.newamount < g.oldamount THEN 'Decreased'
                    ELSE 'No Change'
                END
            ),
            'N/A',
            CAST(YEAR(g.changedate) AS STRING),
            'N/A',
            'N/A',
            CASE
                WHEN AVG(g.newamount) >= 150 THEN 'High Payment'
                WHEN AVG(g.newamount) >= 100 THEN 'Medium Payment'
                ELSE 'Low Payment'
            END,
            'N/A',
            'N/A',
            TRIM(h.deviceid),
            RANK() OVER (PARTITION BY g.corp_subscriberid ORDER BY MAX(g.changedate) DESC),
            'N/A',
            'N/A'
        ) AS unified_column
    FROM corp_customer.payment_history g
    LEFT JOIN corp_customer.device_repairs h ON g.corp_subscriberid = h.corp_subscriberid
    LEFT JOIN corp_customer.subscription_renewals j ON j.corp_subscriberid = g.corp_subscriberid
    LEFT JOIN corp_customer.payment_adjustments k ON k.corp_subscriberid = j.corp_subscriberid
    WHERE j.planname = 'Premium Plan'
    GROUP BY g.corp_subscriberid, j.planname, h.deviceid, YEAR(g.changedate)
)

SELECT *
FROM unified_query
ORDER BY 1;
