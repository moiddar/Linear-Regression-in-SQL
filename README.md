# Linear Regression using SQL (SQLite & Snowflake)
<br>
<br>

### High Level Summary
In this project we will figure out what the LA PD budget should be in 2025 using linear regression. 
<br>

Linear regression is a common data science technique that lets us predict values from datasets. It's very simple to implement and most tools will have built functions for it. In this project we will apply it directly in SQL because there's several scenarios where its quicker and cheaper to work directly in SQL than it is to setup infrastructure for Python or other languages. 
<br>

From our regression we determined that the average number of crimes reported per day in 2025 will have increased by 4.1% against 2023 levels. As such we would recommend that the LA PD ask for a budget of between $946.97M and $998.98M. The actual budget granted for 2025 is $985.95, within our recommended range. 
<br>
<br>
<br>
### What is Linear Regression
In plain English, it draws the best straight line through the data you have which lets you predict the data you don't have. 
In more technical terms, it finds the relationship between the independent and dependent variables with the assumption that the relationship is linear. It does this by minimising the mean squared error. We're going to be focusing on simple linear regression which is where there's only one independent variable. 
<br>
<br>
The equations for Simple Linear Regression are:
<br>
<br>
$$y = a + b x$$
<br>
<br>
$$b = \frac{\sum_{i=1}^{n} (x_i - \bar{x})(y_i - \bar{y})}{\sum_{i=1}^{n} (x_i - \bar{x})^2}$$
<br>
<br>
$$a = \bar{y} - b \bar{x}$$
<br>
<br>
<br>

### The Data
We're going to be using data on crimes in Los Angeles, USA from the USA Government Website. The practical purpose of this analysis is to imagine that we're the head of the Los Angeles Police Department and we need to have an estimate on how many crimes occur per day so we know how much budget to assign to our field services. We're just starting off 2024 and we want to submit a proposal for the 2025 budget. 
<br>
<br>
In our dataset we've got two date columns to work with; the date the crime was reported, and the date the crime occurred. Date reported aligns more with the purpose of the analysis because it directly affects how many staff you would need to respond to each report. There are crimes that have longer timescales between occurrence and reporting which also makes date reported more relevant. We're also going to focus only on crimes related to theft to simplify the real world scenario. 
<br>
Once we have the number of crimes per day we need to convert the date into a format that we can use in our equations. For SQLite this is the Julian Day and for Snowflake this is Epoch Seconds. The actual conversion doesn't matter as long as the data remains chronological. 
<br>
<br>
<br>
### Stage 1: Cleaning, Filtering, and Aggregation
First, we need to filter the data to only thefts. Then we need to clean up the date column and aggregate the primary key to get the number of crimes per day. Both code samples below do the same thing, but the Snowflake sample is more readable and clean, which is important if you're working in a team. 
<table>
<tr>
<td> SQLite </td> <td> Snowflake </td>
</tr>
<tr>
<td>

```sql
with crimes as (
    SELECT 
        substr(substr("DATE OCC",0,11),7,4)||
    '-'||substr(substr("DATE OCC",0,11),1,2)||
    '-'||substr(substr("DATE OCC",0,11),4,2) as day,
        "DATE OCC" as date, 
        "DR_NO"
    FROM crime_data_la
    WHERE ("Crm Cd Desc" LIKE '%STOLEN%'
        OR "Crm Cd Desc" LIKE '%BURGLARY%'
        OR "Crm Cd Desc" LIKE '%THEFT%'
        OR "Crm Cd Desc" LIKE '%ROBBERY%'
        OR "Crm Cd Desc" LIKE '%PURSE SNATCHING%'
        OR "Crm Cd Desc" LIKE '%PICKPOCKET%'
        OR "Crm Cd Desc" LIKE '%SHOPLIFTING%')
        AND "Crm Cd Desc" != 'THEFT OF IDENTITY' 
        AND "DATE OCC" NOT LIKE '%2024%'
        AND "DATE OCC" NOT LIKE '%2025%'
)
SELECT distinct 
    julianday(day) as juliandate,
    count("DR_NO") as crimes 
FROM crimes
GROUP BY 1
ORDER BY 1
```

</td>
<td>
    
```sql
SELECT 
    date_part(epoch_second, to_date(
      "DATE OCC",'MM/DD/YYYY')) as epochtime,
    count("DR_NO") as crimes
FROM crime_data_la
WHERE "Crm Cd Desc" LIKE ANY (
    '%STOLEN%',
    '%BURGLARY%',
    '%THEFT%',
    '%ROBBERY%',
    '%PURSE SNATCHING%',
    '%PICKPOCKET%',
    '%SHOPLIFTING%')
AND "Crm Cd Desc" != 'THEFT OF IDENTITY' 
AND to_date("DATE OCC",'MM/DD/YYYY') < '2024-01-01'
```
</td>
</tr>
</table>
<br>
SQLite doesn't have a date data type and our dataset has date columns stored as varchar so you have to manipulate the string to get to a date that can be converted to Julian days. Snowflake on the other hand, has a built in function that can convert strings to dates. Snowflake can also do all conversions, filtering, and aggregation in one query whereas SQLite has to be broken down into common table expressions or subqueries (with CTEs being preferred for readability).  
<br>
<br>
<br>

### Stage 2: Calculation
In SQLite we have to calculate the slope and intercept "by hand" whereas with Snowflake there's built in functions for it.
<table>
<tr>
<td> SQLite </td> <td> Snowflake </td>
</tr>
<tr>
<td>

```sql
with number_of_points as (
    SELECT 
        count(juliandate) as n
    FROM crimes_per_day 
),
slope as (
    SELECT 
        (sum(c.juliandate*c.crimes)
            - sum(c.juliandate)*sum(c.crimes)/m.n)
        /(sum(c.juliandate*c.juliandate)
            - sum(c.juliandate)*sum(c.juliandate)/m.n) as b
    FROM crimes_per_day as c
    CROSS JOIN number_of_points as m
),
intercept as (
    SELECT
        sum(c.crimes)/m.n - s.b*sum(juliandate)/n as a  
    FROM crimes_per_day as c
    CROSS JOIN number_of_points as m
    CROSS JOIN slope as s 
)
SELECT 
    datetime(c.juliandate) as date,
    c.crimes,
    s.b*c.juliandate + i.a as regression_line
FROM crimes_per_day as c
CROSS JOIN slope as s
CROSS JOIN intercept as i

```

</td>
<td>
    
```sql
with regression as (
    SELECT
        REGR_SLOPE(crimes, epochtime) as slope,
        REGR_INTERCEPT(crimes,epochtime) as intercept
    FROM crimes_per_day
)
SELECT
    to_timestamp(epochtime) as date,
    c.crimes,
    r.slope*c.epochtime + r.intercept as regression_line
FROM crimes_per_day as c
CROSS JOIN regression as r
ORDER BY c.date;
```
</td>
</tr>
</table>
<br>
<br>
<br>
 
### Visualization
![Dashboard 1](https://github.com/user-attachments/assets/e1a11129-e1c3-4dee-b37e-a096c64cafef)
From a visual inspection we can see that the line does fit the data. If we wanted to take it a step further and be completely sure, we could validate it in Excel too. Excel's built in trendline feature uses the same linear regression as above. 
![Picture1](https://github.com/user-attachments/assets/ac164723-4da6-4565-8817-1a0835d9af98)
We can cross reference the equation on the Excel chart to our intercept and slope values to make sure they're correct. 
<br>
<br>
<br>
### Applied Use Case
Going back to our practical purpose for doing this analysis, we can predict from our regression line that in 2025 we will have an average of 380 crimes reported per day which is up 4.1% from 2023. In 2023 the Field Forces budget for LA PD according to https://openbudget.lacity.org/ was $909.66M. Our proposal for the 2025 field forces budget is $946.97M. Adjusting for CPI Inflation that figure becomes $998.98M. In the real world budgets are made up of many complex parts like wages, inventory, and services while CPI Inflation measures the price of consumer goods. As such we would recommend that the budget be between this range of $946.97M - $998.98M.
<br>
<br>
Interestingly, the actual 2025 budget has been released and it is $985.95 so our CPI adjusted budget is off by 1.3%.
<br>
<br>
