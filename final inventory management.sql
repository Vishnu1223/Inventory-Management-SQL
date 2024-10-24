select * from products
select * from orders
select * from customers

---List of all products with their price, quantity per unit, and units in stock:---

SELECT product_name, unit_price, quantity_per_unit, units_in_stock
FROM Products;

---Total number of customers from each country:---

SELECT country, COUNT(customer_id) AS total_customers
FROM Customers
GROUP BY country
order by count(customer_id)desc;

---List of ship country along with their freight charges:---

SELECT ship_country, sum(freight)Total_freight
FROM Orders
group by ship_country
order by sum(freight)Desc;

---Products that are currently out of stock:---

SELECT product_name
FROM Products
WHERE units_in_stock = 0;

---List of customers who have placed order:---

SELECT customer_id, COUNT(order_id) AS order_count
FROM Orders
GROUP BY customer_id
order by count(order_id)desc;

---Total number of orders shipped by each shipper:---

SELECT ship_via, COUNT(order_id) AS total_orders
FROM Orders
GROUP BY ship_via
order by count(order_id)desc;

---Average freight cost per order:---

SELECT AVG(freight) AS average_freight
FROM Orders;

---All discontinued products:---

SELECT product_name
FROM Products
WHERE discontinued = 1;

---Total price by each product:---

SELECT product_name, SUM(unit_price * units_in_stock) AS total_price
FROM Products
GROUP BY product_name
order by total_price Desc;


---Customers who have placed the highest number of orders:---

SELECT customer_id, COUNT(order_id) AS order_count
FROM Orders
GROUP BY customer_id
ORDER BY order_count DESC

---The total freight cost for each customer:---

SELECT customer_id, SUM(freight) AS total_freight_cost
FROM Orders
where customer_id is not null
GROUP BY customer_id;

---Number of days taken to deliver order:---

SELECT order_id, customer_id, DATEDIFF(DAY, delivered_date, shipped_date) AS days_late
FROM Orders
WHERE shipped_date > delivered_date
order by days_late desc;


---Month with the highest number of orders placed:---

SELECT MONTH(order_date) AS order_month,
	datename(month,order_date)as month,
	COUNT(order_id) AS total_orders
FROM Orders
GROUP BY MONTH(order_date),datename(month,order_date)
ORDER BY total_orders DESC;

--- List of products with low stock than reorder level:---

SELECT product_name, units_in_stock, reorder_level
FROM Products
WHERE units_in_stock < reorder_level;

---Percentage of discontinued products in the inventory:---
SELECT round((sum(CASE WHEN discontinued = 1 THEN 1 END) * 100.0 / COUNT(*)),2) AS discontinued_percentage
FROM Products;

---The average order processing time:---

SELECT AVG(DATEDIFF(day, order_date,shipped_date)) AS avg_processing_time
FROM Orders;

---Product sold over year:---

SELECT product_name, YEAR(order_date) AS order_year,
	SUM(order_quantity) AS total_units_sold
FROM Orders
JOIN Products ON Orders.product_id = Products.product_id
GROUP BY product_name, YEAR(order_date)
ORDER BY order_year,total_units_sold desc;

---Customer purchase behavior:---
select customer_id,
	sum(freight) over(partition by customer_id order by order_date ) as rolling_freight,
	max(freight) over(partition by customer_id )as maximum_freight,
	min(freight) over(partition by customer_id )as  minimum_freight,
	DENSE_RANK()over(partition by customer_id order by freight desc)as rank_of_freight,
	count(freight) over(partition by customer_id order by order_date ) as order_count
from orders
where customer_id is not null
group by customer_id,freight,order_date
order by customer_id,order_count;

---List of product categories which need restocking:---

SELECT product_name, units_in_stock, reorder_level
FROM Products
WHERE units_in_stock < reorder_level AND discontinued = 0;

---Segmentation of customers using RFM analysis:---

WITH RFM AS (
    SELECT customer_id,
           MAX(order_date) AS recency,
           COUNT(order_id) AS frequency,
           SUM(freight) AS monetary
    FROM Orders
    GROUP BY customer_id
)
SELECT customer_id,
       DENSE_RANK() OVER (ORDER BY frequency DESC) AS frequency_rank,
       DENSE_RANK() OVER (ORDER BY monetary DESC) AS monetary_rank,
	   DENSE_RANK() OVER (ORDER BY recency ASC) AS recency_rank
FROM RFM
order by frequency_rank,monetary_rank,recency_rank;

---Order trends to identify seasonal demand peaks:---

SELECT MONTH(order_date) AS order_month,
	datename(month,order_date)as month_name,
	COUNT(order_id) AS total_orders
FROM Orders
where month(order_date)is not null
GROUP BY MONTH(order_date),datename(month,order_date)
ORDER BY total_orders DESC;

---Top  Customers by revenue:---

SELECT C.customer_id, C.company_name, SUM(O.freight) AS total_spent
FROM Customers C
JOIN Orders O ON C.customer_id = O.customer_id
GROUP BY C.customer_id, C.company_name
ORDER BY total_spent DESC;

---Products with declining sales over time:---

with cte as(select product_name,
	year(order_date)yea,
	sum(order_quantity+units_in_stock)total_stock
from orders o
join products p 
on o.product_id=p.product_id
group by product_name,year(order_date)),
cte_1 as(
select *,lag(total_stock,1)over(partition by product_name order by yea)as previous_year,
	lag(total_stock,2)over(partition by product_name order by yea)two_year
from cte)
select product_name
from cte_1
where total_stock<previous_year and previous_year<two_year
order by product_name;

---Customers who have not placed an order in the last 6 months (to target for re-engagement):---

with cte as (select max(order_date)as high_Date from orders)
SELECT customer_id 
from orders
join cte
on 1=1
group by customer_id,high_Date
having max(order_date) <DATEADD(month, -6,high_Date);

---ABC Analysis:---
WITH RevenueData AS (
    SELECT product_name, SUM(unit_price*(units_in_stock)) AS total_revenue
    FROM Products
    GROUP BY product_name
),
RankedData AS (
    SELECT product_name, total_revenue,
           RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
           SUM(total_revenue) OVER () AS total_cumulative_revenue,
           SUM(total_revenue) OVER (ORDER BY total_revenue DESC) / SUM(total_revenue) OVER () * 100 AS revenue_percent
    FROM RevenueData
)
SELECT product_name, total_revenue, revenue_percent,
       CASE 
           WHEN revenue_percent <= 80 THEN 'A'
           WHEN revenue_percent > 80 AND revenue_percent <= 95 THEN 'B'
           ELSE 'C'
       END AS abc_classification
FROM RankedData;

---Inventory Turnover Ratio:---

WITH COGS AS (
    SELECT product_name, SUM(unit_price * (units_in_Stock+order_quantity)) AS cogs
    FROM Products
    JOIN Orders ON Products.product_id = Orders.product_id
    GROUP BY product_name
),
AverageInventory AS (
    SELECT product_name, (units_in_stock + order_quantity) / 2 AS avg_inventory
    FROM Products 
	JOIN Orders ON Products.product_id = Orders.product_id
)
SELECT distinct
    COGS.product_name, 
    COGS.cogs, 
    AverageInventory.avg_inventory,
    CASE 
        WHEN AverageInventory.avg_inventory = 0 THEN 0
        ELSE (COGS.cogs / AverageInventory.avg_inventory) 
    END AS inventory_turnover_ratio
FROM COGS
JOIN AverageInventory ON COGS.product_name = AverageInventory.product_name
order by inventory_turnover_ratio desc;


---Safety Stock Calculation:---
WITH LeadTimeDemand AS (
    SELECT product_name, 
           AVG(CASE 
                WHEN DATEDIFF(day, order_date, shipped_date) > 0 
                THEN DATEDIFF(day, order_date, shipped_date)
                ELSE NULL
               END) AS avg_lead_time,
           round(STDEV(order_quantity),0) AS demand_variability
    FROM Orders
    JOIN Products ON Orders.product_id = Products.product_id
    WHERE order_date IS NOT NULL AND shipped_date IS NOT NULL
    GROUP BY product_name
)
SELECT product_name, 
       avg_lead_time, 
       demand_variability,
       CASE 
           WHEN avg_lead_time > 0 AND demand_variability IS NOT NULL 
           THEN round((demand_variability * (SQRT(avg_lead_time)*1.0) * 1.65),0) 
           ELSE 0
       END AS safety_stock
FROM LeadTimeDemand;

---Products which are less than safety stock---
WITH LeadTimeDemand AS (
    SELECT product_name, 
           AVG(CASE 
                WHEN DATEDIFF(day, order_date, shipped_date) > 0 
                THEN DATEDIFF(day, order_date, shipped_date)
                ELSE NULL
               END) AS avg_lead_time,
           round(STDEV(order_quantity),0) AS demand_variability
    FROM Orders
    JOIN Products ON Orders.product_id = Products.product_id
    WHERE order_date IS NOT NULL AND shipped_date IS NOT NULL
    GROUP BY product_name
),cte_2 as(
SELECT product_name, 
       avg_lead_time, 
       demand_variability,
       CASE 
           WHEN avg_lead_time > 0 AND demand_variability IS NOT NULL 
           THEN round((demand_variability * (SQRT(avg_lead_time)*1.0) * 1.65),0) 
           ELSE 0
       END AS safety_stock
FROM LeadTimeDemand)
select products.product_name 
from products
join cte_2 
on products.product_name=cte_2.product_name
where products.units_in_stock<safety_stock;

---Stockout Risk Reduction---
WITH LeadTimeDemand AS (
    SELECT product_name, 
           AVG(CASE 
                WHEN DATEDIFF(day, order_date, shipped_date) > 0 
                THEN DATEDIFF(day, order_date, shipped_date)
                ELSE NULL
               END) AS avg_lead_time,
           round(STDEV(order_quantity),0) AS demand_variability
    FROM Orders
    JOIN Products ON Orders.product_id = Products.product_id
    WHERE order_date IS NOT NULL AND shipped_date IS NOT NULL
    GROUP BY product_name
),cte_2 as(
SELECT product_name, 
       avg_lead_time, 
       demand_variability,
       CASE 
           WHEN avg_lead_time > 0 AND demand_variability IS NOT NULL 
           THEN round((demand_variability * (SQRT(avg_lead_time)*1.0) * 1.65),0) 
           ELSE 0
       END AS safety_stock
FROM LeadTimeDemand),stocked_out_stocks as (
select count(*)as stocked_out_stocks 
from products
join cte_2 
on products.product_name=cte_2.product_name
where products.units_in_stock<safety_stock)
select round(stocked_out_stocks.stocked_out_stocks*100.0/count(*),0)as percentage_of_stockoutreduced_stocks
from products
join stocked_out_stocks 
on 1=1
group by stocked_out_stocks;


--- Reduction in Holding Costs:---
WITH RevenueData AS (
    SELECT product_name, SUM(unit_price*(units_in_stock)) AS total_revenue
    FROM Products
    GROUP BY product_name
),
RankedData AS (
    SELECT product_name, total_revenue,
           RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
           SUM(total_revenue) OVER () AS total_cumulative_revenue,
           SUM(total_revenue) OVER (ORDER BY total_revenue DESC) / SUM(total_revenue) OVER () * 100 AS revenue_percent
    FROM RevenueData
),
cte_2 as(
SELECT product_name, total_revenue, revenue_percent,
       CASE 
           WHEN revenue_percent <= 80 THEN 'A'
           WHEN revenue_percent > 80 AND revenue_percent <= 95 THEN 'B'
           ELSE 'C'
       END AS abc_classification
FROM RankedData),
total_products as(
select count(*)as total_count
from products)
select count(*)*100.0/total_count as percentage_of_topvalue_holding_stocks
from cte_2
join total_products
on 1=1
where abc_classification='A'
group by total_count;

