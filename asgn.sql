use airbnb;
/*
1. How many records are there in the dataset?
 - Use COUNT(*) function
 - Select from the main table
 */
 SELECT 
    COUNT(*) Total_Records
FROM
    fact_airbnb;
 
 /*
2. How many unique cities are in the European dataset?
 - Use COUNT(DISTINCT ) function
 - Apply it to the CITY column
 */
 with cte as (
 select Distinct CityID from fact_airbnb)
 Select count(*) unique_city from cte;
 
 select Count( Distinct CityID) unique_city from fact_airbnb;
 
/*
3. What are the names of the cities in the dataset?
 - Use DISTINCT keyword
 - Select from the CITY column
 */
 SELECT DISTINCT
    City
FROM
    fact_airbnb fa
        JOIN
    dim_city dc ON fa.CityID = dc.CityID;
 
 /*
4. How many bookings are there in each city?
 - Use COUNT(*) function
 - Group by CITY
 - Order results descending
 */
 SELECT DISTINCT
    City, count(*) Total_booking
FROM
    fact_airbnb fa
        JOIN
    dim_city dc ON fa.CityID = dc.CityID
    group by City
    order by Total_booking desc;

 /*
5. What is the total booking revenue for each city?
 - Use SUM() function on the PRICE column
 - Group by CITY
 - Round the result
 - Order by total revenue descending
 */
SELECT DISTINCT
    City, concat('$ ',round(sum(Price)/1000000,2), ' M')  Total_rev
FROM
    fact_airbnb fa
        JOIN
    dim_city dc ON fa.CityID = dc.CityID
    group by City
    order by Total_rev desc;

 /*
6. What is the average guest satisfaction score for each city?
 - Use AVG() function on GUEST_SATISFACTION column
 - Group by CITY
 - Round the result
 - Order by average score descending
 */
SELECT DISTINCT
    City, round(avg(fa.GuestSatisfaction),2)  Avg_Guest_Satisfaction
FROM
    fact_airbnb fa
        JOIN
    dim_city dc ON fa.CityID = dc.CityID
    group by City
    order by Avg_Guest_Satisfaction desc;
    
 /*
7. What are the minimum, maximum, average, and median booking prices?
 - Use MIN(), MAX(), AVG() functions on PRICE column
 - Use PERCENTILE_CONT(0.5) for median
 - Round results
 */
SELECT 
  ROUND(MIN(Price), 2) AS Min_Price,
  ROUND(MAX(Price), 2) AS Max_Price,
  ROUND(AVG(Price), 2) AS Avg_Price,
  -- Median calculation using subquery and conditional aggregation
  (SELECT 
     ROUND(AVG(Price), 2)
   FROM (
     SELECT 
       Price, 
       ROW_NUMBER() OVER (ORDER BY Price) AS row_num, 
       COUNT(*) OVER () AS total_rows
     FROM fact_airbnb
   ) AS ranked_data
   WHERE row_num IN (FLOOR((total_rows + 1) / 2), CEIL((total_rows + 1) / 2))) AS Median_Price
FROM fact_airbnb;

/*
8. How many outliers are there in the price field?
 - Calculate Q1, Q3, and IQR using PERCENTILE_CONT()
 - Define lower and upper bounds
 - Count records outside these bounds
*/

create view Outlier as
WITH ranked_data AS (
    SELECT
        Price,
        ROW_NUMBER() OVER (ORDER BY Price) AS row_num,
        COUNT(*) OVER () AS total_rows
    FROM fact_airbnb
),
median AS (
    SELECT
        ROUND(AVG(Price), 2) AS median_price
    FROM ranked_data
    WHERE row_num BETWEEN CEIL(total_rows / 2.0) - 1 AND CEIL(total_rows / 2.0)
),
lower_half AS (
    SELECT
        Price,
        ROW_NUMBER() OVER (ORDER BY Price) AS row_num,
        COUNT(*) OVER () AS total_rows
    FROM fact_airbnb
    WHERE Price < (SELECT median_price FROM median)
),
lower_half_median AS (
    SELECT
        ROUND(AVG(Price), 2) AS Q1
    FROM lower_half
    WHERE row_num BETWEEN CEIL(total_rows / 2.0) - 1 AND CEIL(total_rows / 2.0)
),
upper_half AS (
    SELECT
        Price,
        ROW_NUMBER() OVER (ORDER BY Price) AS row_num,
        COUNT(*) OVER () AS total_rows
    FROM fact_airbnb
    WHERE Price > (SELECT median_price FROM median)
),
upper_half_median AS (
    SELECT
        ROUND(AVG(Price), 2) AS Q3
    FROM upper_half
    WHERE row_num BETWEEN CEIL(total_rows / 2.0) - 1 AND CEIL(total_rows / 2.0)
),
quartiles AS (
  SELECT
    (SELECT Q1 FROM lower_half_median) AS Q1,
    (SELECT Q3 FROM upper_half_median) AS Q3,
    (SELECT Q3 - Q1 FROM lower_half_median, upper_half_median) AS IQR
)
SELECT *
FROM fact_airbnb
WHERE Price < (SELECT Q1 - (IQR * 1.5) FROM quartiles)
   OR Price > (SELECT Q3 + (IQR * 1.5) FROM quartiles);
   
select Count(*) Ourlier_Count
from outlier;
    
    
/*
9. What are the characteristics of the outliers in terms of room type, number of bookings, and 
price?
 - Create a view or CTE for outliers
 - Group by ROOM_TYPE
 - Use COUNT(), MIN(), MAX(), AVG() functions
*/
select 
dr.RooomType, 
min(ou.Price) min_price,
Max(ou.Price) max_price,
round(Avg(ou.Price),2) avg_price,
count(*) as booking_count
from outlier ou -- view created at problem no 8
join dim_roomtype dr on ou.RoomTypeID=dr.RoomTypeID
group by dr.RooomType;

/*
10. How does the average price differ between the main dataset and the dataset with outliers 
removed?
 - Create a view for cleaned data (without outliers)
 - Calculate average price for both datasets
 - Compare results
*/
create view cleaned_data as
WITH ranked_data AS (
    SELECT
        Price,
        ROW_NUMBER() OVER (ORDER BY Price) AS row_num,
        COUNT(*) OVER () AS total_rows
    FROM fact_airbnb
),
median AS (
    SELECT
        ROUND(AVG(Price), 2) AS median_price
    FROM ranked_data
    WHERE row_num BETWEEN CEIL(total_rows / 2.0) - 1 AND CEIL(total_rows / 2.0)
),
lower_half AS (
    SELECT
        Price,
        ROW_NUMBER() OVER (ORDER BY Price) AS row_num,
        COUNT(*) OVER () AS total_rows
    FROM fact_airbnb
    WHERE Price < (SELECT median_price FROM median)
),
lower_half_median AS (
    SELECT
        ROUND(AVG(Price), 2) AS Q1
    FROM lower_half
    WHERE row_num BETWEEN CEIL(total_rows / 2.0) - 1 AND CEIL(total_rows / 2.0)
),
upper_half AS (
    SELECT
        Price,
        ROW_NUMBER() OVER (ORDER BY Price) AS row_num,
        COUNT(*) OVER () AS total_rows
    FROM fact_airbnb
    WHERE Price > (SELECT median_price FROM median)
),
upper_half_median AS (
    SELECT
        ROUND(AVG(Price), 2) AS Q3
    FROM upper_half
    WHERE row_num BETWEEN CEIL(total_rows / 2.0) - 1 AND CEIL(total_rows / 2.0)
),
quartiles AS (
  SELECT
    (SELECT Q1 FROM lower_half_median) AS Q1,
    (SELECT Q3 FROM upper_half_median) AS Q3,
    (SELECT Q3 - Q1 FROM lower_half_median, upper_half_median) AS IQR
)
SELECT *
FROM fact_airbnb
WHERE Price > (SELECT Q1 - (IQR * 1.5) FROM quartiles)
   and Price < (SELECT Q3 + (IQR * 1.5) FROM quartiles);
   
with avg_prices AS (
  select
  (  SELECT Round(AVG(Price),2)
  FROM fact_airbnb)  AS original_avg_price,
  (SELECT Round(AVG(Price),2)  -- Changed cleaned_avg_price to avg_price
  FROM cleaned_data) AS clean_avg_price
)
SELECT 
 *,
round((original_avg_price-clean_avg_price),2) diffrence
FROM avg_prices;

/*
11. What is the average price for each room type?
 - Use AVG() function on PRICE column 
Group by ROOM_TYPE
*/

select dr.RooomType, Round(Avg(fa.Price),2) Avg_Price
from dim_roomtype dr
join fact_airbnb fa on dr.RoomTypeID= fa.RoomTypeID
group by dr.RooomType;

/*
12. How do weekend and weekday bookings compare in terms of average price and number of 
bookings?
 - Group by DAY column
 - Use AVG() for price and COUNT() for bookings
*/
SELECT 
    dd.DayType,
    ROUND(AVG(fa.Price), 2) avg_price,
    COUNT(*) booking_no    
FROM
    fact_airbnb fa
        JOIN
    dim_daytype dd ON fa.DayTypeID = dd.DayTypeID
GROUP BY dd.DayType;

/*
13. What is the average distance from metro and city center for each city?
 - Use AVG() on METRO_DISTANCE_KM and CITY_CENTER_KM columns
 - Group by CITY
*/
select dc.City, round(avg(fa.Metro_Distance_KM),2) avg_metro_dstn, round(avg(fa.City_Center_KM),2) avg_city_dstn from fact_airbnb fa
join dim_city dc on fa.CityID= dc.CityID
group by dc.City;

/*
14. How many bookings are there for each room type on weekdays vs weekends?
 - Use CASE statements to categorize room types
 - Group by DAY and ROOM_TYPE
*/
WITH BookingCounts AS (
  SELECT
    dd.DayType,
    dr.RooomType,
    COUNT(*) AS total_booking
  FROM fact_airbnb fa
  JOIN dim_daytype dd ON fa.DayTypeID = dd.DayTypeID
  JOIN dim_roomtype dr ON fa.RoomTypeID = dr.RoomTypeID
  GROUP BY dd.DayType,
    dr.RooomType
)

SELECT
  *,
  CASE
    WHEN total_booking > 10000 THEN 'High Demand'
    WHEN total_booking BETWEEN 5000 AND 10000 THEN 'Medium Demand'
    ELSE 'Low Demand'
  END AS BookingCategory
FROM BookingCounts
order by total_booking desc;

/*
15. What is the booking revenue for each room type on weekdays vs weekends?
 - Similar to previous question, but use SUM() on PRICE instead of COUNT()
*/

WITH TotalRev AS (
  SELECT
    dd.DayType,
    dr.RooomType,
    Concat(Round(Sum(fa.Price)/1000000,2), ' M') AS RevTotal
  FROM fact_airbnb fa
  JOIN dim_daytype dd ON fa.DayTypeID = dd.DayTypeID
  JOIN dim_roomtype dr ON fa.RoomTypeID = dr.RoomTypeID
  GROUP BY dd.DayType, dr.RooomType
)

SELECT
  *,
  CASE
    WHEN RevTotal > 3 THEN 'High Revenue'
    WHEN RevTotal BETWEEN 1 AND 2.9 THEN 'Medium Revenue'
    ELSE 'Low Revenue'
  END AS RevCategory
FROM TotalRev
order by RevTotal desc;

/*
16. What is the overall average, minimum, and maximum guest satisfaction score?
- Use AVG(), MIN(), MAX() functions on GUEST_SATISFACTION column
*/

Select 
	Round(Avg(GuestSatisfaction),2) Avg_Guest_Satisfaction,
	MIN(GuestSatisfaction) Min_Guest_Satisfaction,
    Max(GuestSatisfaction) Max_Guest_Satisfaction
from fact_airbnb;

/*
17. How does guest satisfaction score vary by city?
 - Group by CITY
 - Use AVG(), MIN(), MAX() on GUEST_SATISFACTION column
 */
 
 Select 
	dc.City,
	Round(Avg(fa.GuestSatisfaction),2) Avg_Guest_Satisfaction,
	MIN(fa.GuestSatisfaction) Min_Guest_Satisfaction,
    Max(fa.GuestSatisfaction) Max_Guest_Satisfaction
from fact_airbnb fa
join dim_city dc on fa.CityID= dc.CityID
group by dc.City;

/*
18. Is there a correlation between guest satisfaction and factors like cleanliness rating, price, or 
attraction index?
 - Use CORR() function to calculate correlation coefficients
 */

SELECT 
  Round((AVG(GuestSatisfaction * CleanlinessRating) - AVG(GuestSatisfaction) * AVG(CleanlinessRating)) 
  / (STDDEV(GuestSatisfaction) * STDDEV(CleanlinessRating)), 2) AS approx_corrCoff_CleanlinessRating,
  Round((AVG(GuestSatisfaction * Price) - AVG(GuestSatisfaction) * AVG(Price)) 
  / (STDDEV(GuestSatisfaction) * STDDEV(Price)), 2) AS approx_corrCoff_price,
  Round((AVG(GuestSatisfaction * AttractionIndex) - AVG(GuestSatisfaction) * AVG(AttractionIndex)) 
  / (STDDEV(GuestSatisfaction) * STDDEV(AttractionIndex)), 2) AS approx_corrCoff_AttractionIndex  
FROM fact_airbnb;

/*
19. What is the average booking value across all cleaned data? 
- Use AVG() function on PRICE column from cleaned data view
*/

SELECT 
    ROUND(AVG(Price),2) AS Avg_Price
FROM
    cleaned_data; -- view created at the problem no 10

/*
20. What is the average cleanliness score across all cleaned data?
- Use AVG() function on CLEANINGNESS_RATING column from cleaned data
*/

SELECT 
    ROUND(avg(CleanlinessRating),2) AS Avg_Cleanliness_Rating
FROM
    cleaned_data; -- view created at the problem no 10
    
/*
21. How do cities rank in terms of total revenue?
 - Use SUM() on PRICE column
 - Group by CITY
 - Use window function ROW_NUMBER() to assign rank
*/

select dc.City, concat(Round(sum(fa.Price)/1000000,2), ' M') TotalRev,
dense_rank() over (order by sum(fa.Price) desc) CityRank
from fact_airbnb fa
join dim_city dc on fa.CityID= dc.CityID
group by dc.City;