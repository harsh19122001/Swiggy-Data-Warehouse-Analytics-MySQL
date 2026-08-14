CREATE DATABASE swiggydata;
USE swiggydata;

CREATE DATABASE swiggy_database_;
USE swiggy_database_;

SELECT * FROM swiggy_data limit 197000;
SELECT COUNT(*) FROM swiggy_data

-- Column Rename
ALTER TABLE swiggy_data
RENAME COLUMN `Order Date` TO order_date,
RENAME COLUMN `Restaurant Name` TO restaurant_name,
RENAME COLUMN `Dish Name` TO dish_name,
RENAME COLUMN `Price (INR)` TO price_inr,
RENAME COLUMN `Rating Count` TO rating_count;

-- Data Validation & Cleaning
-- Null check table

SELECT
    SUM(CASE WHEN State IS NULL THEN 1 ELSE 0 END) AS null_state,
    SUM(CASE WHEN City IS NULL THEN 1 ELSE 0 END) AS null_city,
    SUM(CASE WHEN Order_Date IS NULL THEN 1 ELSE 0 END) AS null_order_date,
    SUM(CASE WHEN Restaurant_Name IS NULL THEN 1 ELSE 0 END) AS null_restaurant,
    SUM(CASE WHEN Location IS NULL THEN 1 ELSE 0 END) AS null_location,
    SUM(CASE WHEN Category IS NULL THEN 1 ELSE 0 END) AS null_category,
    SUM(CASE WHEN Dish_Name IS NULL THEN 1 ELSE 0 END) AS null_dish,
    SUM(CASE WHEN Price_INR IS NULL THEN 1 ELSE 0 END) AS null_price,
    SUM(CASE WHEN Rating IS NULL THEN 1 ELSE 0 END) AS null_rating,
    SUM(CASE WHEN Rating_Count IS NULL THEN 1 ELSE 0 END) AS null_rating_count
FROM swiggy_data;

-- Blank or Empty String 
SELECT * 
FROM swiggy_data
WHERE
State = '' OR City = '' OR Restaurant_Name = '' OR Location = '' OR Category = '' OR Dish_Name = '';

-- Date Conversion
ALTER TABLE swiggy_data
ADD COLUMN order_date_new DATE;

SET SQL_SAFE_UPDATES = 0;

UPDATE swiggy_data
SET order_date_new = STR_TO_DATE(order_date,'%d-%m-%Y');

SET SQL_SAFE_UPDATES = 1;

SELECT
    order_date,
    order_date_new
FROM swiggy_data
LIMIT 20;

ALTER TABLE swiggy_data
DROP COLUMN order_date;

ALTER TABLE swiggy_data
RENAME COLUMN order_date_new TO order_date;

DESC swiggy_data;

-- Duplicate Detection
SELECT 
State, City , order_date, restaurant_name, Location, Category, Dish_Name, Price_INR, Rating, Rating_Count, COUNT(*) AS CNT
FROM swiggy_data
GROUP BY 
State, City , order_date, restaurant_name, Location, Category, Dish_Name, Price_INR, Rating, Rating_Count
HAVING COUNT(*) > 1;

-- Duplicate Detection with CTE.
WITH CTE AS (
    SELECT *,
           ROW_NUMBER() OVER(
               PARTITION BY State, City, order_date, restaurant_name,
                            Location, Category, Dish_Name,
                            Price_INR, Rating, Rating_Count
               ORDER BY State
           ) AS rn
    FROM swiggy_data
)
SELECT *
FROM CTE
WHERE rn > 1;

-- Delete Duplication
CREATE TABLE swiggy_new AS
SELECT DISTINCT *
FROM swiggy_data;

DROP TABLE swiggy_data;

RENAME TABLE swiggy_new TO swiggy_data;

SELECT * FROM swiggy_data limit 197000;

-- CREATING SCHEMA
-- DIMENSION TABLES
-- DATE TABLE
CREATE TABLE dim_date (
    date_id INT AUTO_INCREMENT PRIMARY KEY,
    Full_Date DATE,
    Year INT,
    Month INT,
    Month_Name VARCHAR(20),
    Quarter INT,
    Day INT,
    Week INT
);

-- dim_location
CREATE TABLE dim_location (
    location_id INT AUTO_INCREMENT PRIMARY KEY,
    State VARCHAR(100),
    City VARCHAR(100),
    Location VARCHAR(200)
);

-- dim_restaurant
CREATE TABLE dim_restaurant (
    restaurant_id INT AUTO_INCREMENT PRIMARY KEY,
    Restaurant_Name VARCHAR(200)
);

-- dim_category
CREATE TABLE dim_category (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    Category VARCHAR(200)
);

-- dim_dish
CREATE TABLE dim_dish (
    dish_id INT AUTO_INCREMENT PRIMARY KEY,
    Dish_Name VARCHAR(200)
);

-- FACT TABLE

CREATE TABLE fact_swiggy_orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,

    date_id INT,
    Price_INR DECIMAL(10,2),
    Rating DECIMAL(4,2),
    Rating_Count INT,

    location_id INT,
    restaurant_id INT,
    category_id INT,
    dish_id INT,

    CONSTRAINT fk_date
        FOREIGN KEY (date_id)
        REFERENCES dim_date(date_id),

    CONSTRAINT fk_location
        FOREIGN KEY (location_id)
        REFERENCES dim_location(location_id),

    CONSTRAINT fk_restaurant
        FOREIGN KEY (restaurant_id)
        REFERENCES dim_restaurant(restaurant_id),

    CONSTRAINT fk_category
        FOREIGN KEY (category_id)
        REFERENCES dim_category(category_id),

    CONSTRAINT fk_dish
        FOREIGN KEY (dish_id)
        REFERENCES dim_dish(dish_id)
);


-- dim_date

INSERT INTO dim_date
(Full_Date, Year, Month, Month_Name, Quarter, Day, Week)

SELECT DISTINCT
    order_date,
    YEAR(order_date),
    MONTH(order_date),
    MONTHNAME(order_date),
    QUARTER(order_date),
    DAY(order_date),
    WEEK(order_date)

FROM swiggy_data
WHERE order_date IS NOT NULL;

-- dim Loaction
INSERT INTO dim_location
(State, City, Location)

SELECT DISTINCT
    State,
    City,
    Location

FROM swiggy_data;

-- dim_restaurant
INSERT INTO dim_restaurant
(restaurant_name)

SELECT DISTINCT
    restaurant_name

FROM swiggy_data;

-- dim_category
INSERT INTO dim_category
(Category)

SELECT DISTINCT
    Category

FROM swiggy_data;

-- dim_dish
INSERT INTO dim_dish
(Dish_Name)

SELECT DISTINCT
    Dish_Name

FROM swiggy_data;

-- Add Indexes
CREATE INDEX idx_date
ON dim_date(Full_Date);

CREATE INDEX idx_location
ON dim_location(State,City,Location);

CREATE INDEX idx_restaurant
ON dim_restaurant(Restaurant_Name);

CREATE INDEX idx_category
ON dim_category(Category);

CREATE INDEX idx_dish
ON dim_dish(Dish_Name);

-- Check Counts
SELECT COUNT(*) FROM dim_date;
SELECT COUNT(*) FROM dim_location;
SELECT COUNT(*) FROM dim_restaurant;
SELECT COUNT(*) FROM dim_category;
SELECT COUNT(*) FROM dim_dish;


-- INSERT INTO FACT_SWIGGY_ORDERS
INSERT INTO fact_swiggy_orders
(
    date_id,
    Price_INR,
    Rating,
    Rating_Count,
    location_id,
    restaurant_id,
    category_id,
    dish_id
)
SELECT
    dd.date_id,
    s.Price_INR,
    s.Rating,
    s.Rating_Count,
    dl.location_id,
    dr.restaurant_id,
    dc.category_id,
    dsh.dish_id
FROM swiggy_data s
JOIN dim_date dd
    ON dd.Full_Date = s.order_date
JOIN dim_location dl
    ON dl.State = s.State
    AND dl.City = s.City
    AND dl.Location = s.Location
JOIN dim_restaurant dr
    ON dr.Restaurant_Name = s.restaurant_name
JOIN dim_category dc
    ON dc.Category = s.Category
JOIN dim_dish dsh
    ON dsh.Dish_Name = s.Dish_Name;

SELECT COUNT(*)
FROM fact_swiggy_orders;

    
SELECT * FROM fact_swiggy_orders;

SELECT COUNT(*) FROM swiggy_data;

SELECT COUNT(*) FROM fact_swiggy_orders;


SELECT * FROM fact_swiggy_orders f
JOIN dim_date d ON f.date_id = d.date_id
JOIN dim_location l ON f.location_id = l.location_id
JOIN dim_restaurant r ON f.restaurant_id = r.restaurant_id
JOIN dim_category c ON f.category_id = c.category_id
JOIN dim_dish di ON f.dish_id = di.dish_id;

-- KPI's
-- Total Orders
SELECT COUNT(*) 
AS Total_Orders
FROM fact_swiggy_orders;

-- Total Revenue (INR Million)
SELECT
CONCAT(
    FORMAT(SUM(Price_INR)/1000000,2),
    ' INR Million'
) AS Total_Revenue
FROM fact_swiggy_orders;

-- Average Dish Price
SELECT
CONCAT(
	FORMAT(AVG(PRICE_INR),2), 
    ' INR'
) AS Average_dish_price
FROM fact_swiggy_orders;

-- Average Rating
SELECT 
AVG(Rating)
AS Avergae_Rating
FROM fact_swiggy_orders;


-- Deep-Dive Business Analysis
-- Monthly Order Trends
SELECT 
d.Year,
d.Month, 
d.Month_Name,
COUNT(*) AS Total_Orders
FROM fact_swiggy_orders f
JOIN dim_date d 
ON d.date_id = f.date_id
GROUP BY 
d.year, 
d.Month,
d.Month_Name
ORDER BY  d.Year,d.Month DESC;

-- Monthly Revenue Trend
SELECT 
d.Year,
d.Month,
d.Month_Name,
SUM(f.Price_INR) AS Total_Revenue
FROM fact_swiggy_orders f
JOIN dim_date d
ON d.date_id = f.date_id
GROUP BY D.Year, d.Month, d.Month_Name
ORDER BY SUM(Price_INR) DESC;
 
-- Quarterly order trend
SELECT 
d.Year,
d.Quarter,
COUNT(*) AS Total_Orders
FROM fact_swiggy_orders f
JOIN dim_date d
ON f.date_id = d.date_id
GROUP BY d.Year, d.Quarter
ORDER BY COUNT(*) DESC;

-- Quarterly Revenue trend
SELECT 
d.Year,
d.Quarter,
SUM(f.Price_INR) AS Total_Revenue
FROM fact_swiggy_orders f
JOIN dim_date d
ON f.date_id = d.date_id
GROUP BY d.Year
ORDER BY Total_Revenue DESC;

-- Yearly Order Trend
SELECT
d.Year,
COUNT(*) AS Total_Orders
FROM fact_swiggy_orders f
JOIN dim_date d
ON f.date_id = d.date_id
GROUP BY d.Year
Order BY COUNT(*) DESC;

-- Yearly Revenue Trend
SELECT 
d.year,
SUM(Price_INR) AS Total_Revenue
FROM fact_swiggy_orders f
JOIN dim_date d
ON f.date_id = d.date_id
GROUP BY d.Year
Order By SUM(Price_INR) DESC;

SELECT * FROM dim_date
-- Orders by Day of Week(Mon-Sun)
SELECT
    DAYNAME(d.Full_Date) AS day_name,
    COUNT(*) AS total_orders
FROM fact_swiggy_orders f
JOIN dim_date d
    ON f.date_id = d.date_id
GROUP BY
    DAYOFWEEK(d.Full_Date),
    DAYNAME(d.Full_Date)
ORDER BY
    DAYOFWEEK(d.Full_Date);
    
SELECT * FROM dim_location;
-- Location Based Analysis
-- Top 10 Cities by order volume
SELECT 
l.City,
COUNT(*) AS Total_Orders
FROM fact_swiggy_orders f
JOIN dim_location l
ON f.location_id = l.location_id
GROUP BY l.City
ORDER BY COUNT(*) DESC
LIMIT 10;

-- Top 10 Cities by Revenue
SELECT 
l.City,
SUM(f.Price_INR) AS Total_Revenue
FROM fact_swiggy_orders f
JOIN dim_location l
ON f.location_id = l.location_id
GROUP BY l.City
ORDER BY SUM(f.Price_INR) DESC
LIMIT 10;

-- Revenue contribution by states
SELECT 
l.State,
SUM(Price_INR) AS Total_Revenue
FROM fact_swiggy_orders f
JOIN dim_location l
ON f.location_id = l.location_id
GROUP BY l.State
ORDER BY SUM(Price_INR) DESC;

-- Food Performance
-- Top 10 Restaurants by orders
SELECT 
r.Restaurant_Name,
COUNT(*) AS Total_Orders
FROM fact_swiggy_orders f
JOIN dim_restaurant r
ON f.restaurant_id = r.restaurant_id
GROUP BY r.Restaurant_Name
ORDER BY COUNT(*) DESC
LIMIT 10;

-- Top 10 Restaurants by Revenue
SELECT 
r.Restaurant_Name,
SUM(Price_INR) AS Total_Revenue
FROM fact_swiggy_orders f
JOIN dim_restaurant r
ON f.restaurant_id = r.restaurant_id
GROUP BY r.Restaurant_Name
ORDER BY SUM(Price_INR) DESC
LIMIT 10;

-- Top categories BY Order Volume
SELECT
c.Category,
COUNT(*) AS Total_Orders
FROM fact_swiggy_orders f
JOIN dim_category c
ON f.category_id = c.category_id
GROUP BY c.Category
ORDER BY COUNT(*) DESC;

SELECT * FROM dim_dish;
-- Most Ordered Dishes
SELECT 
d.Dish_Name,
COUNT(*) AS Total_Orders
FROM fact_swiggy_orders f
JOIN dim_dish d
ON f.dish_id = d.dish_id
GROUP BY DISH_NAME
ORDER BY COUNT(*) DESC;

-- Cusisne Performace (Orders + Avg Rating)
SELECT 
c.Category,
AVG(f.Rating) AS Avg_rating,
COUNT(*) AS Total_Orders
FROM fact_swiggy_orders f
JOIN dim_category c
ON f.category_id = c.category_id
GROUP BY c.category
ORDER BY Total_Orders Desc;

-- Customer Spending Insights
SELECT 
   CASE
     WHEN Price_INR < 100 THEN 'Under 100'
     WHEN Price_INR BETWEEN 100 AND 199 THEN '100 - 199'
     WHEN Price_INR BETWEEN 200 AND 299 THEN '200 - 299'
     WHEN Price_INR BETWEEN 300 AND 399 THEN '300 - 399'
     ELSE '500+'
   END AS price_range,
COUNT(*) AS Total_Orders
FROM fact_swiggy_orders
GROUP BY 
    CASE
     WHEN Price_INR < 100 THEN 'Under 100'
     WHEN Price_INR BETWEEN 100 AND 199 THEN '100 - 199'
     WHEN Price_INR BETWEEN 200 AND 299 THEN '200 - 299'
     WHEN Price_INR BETWEEN 300 AND 399 THEN '300 - 399'
     ELSE '500+'
	END
ORDER BY Total_orders DESC;

-- Rating Count Distribution (1-5)
SELECT 
      rating,
      COUNT(*) AS rating_count
FROM fact_swiggy_orders
GROUP BY rating
ORDER BY rating;

SELECT
    r.Restaurant_Name,
    COUNT(*) AS Total_Orders
FROM fact_swiggy_orders f
JOIN dim_restaurant r
ON f.restaurant_id = r.restaurant_id
GROUP BY r.Restaurant_Name
ORDER BY Total_Orders DESC
LIMIT 10;
