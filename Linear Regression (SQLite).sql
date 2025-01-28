-- -- validating that the primary key is unique
SELECT count(distinct "DR_NO"), count("DR_NO")
FROM crime_data_la;

-- Converting string date to a format SQlite can understand
-- Filtering for relevant crime data 
with crimes as (
    SELECT 
        substr(substr("DATE OCC",0,11),7,4)||'-'||substr(substr("DATE OCC",0,11),1,2)||'-'||substr(substr("DATE OCC",0,11),4,2) as day,
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
        AND "Crm Cd Desc" != 'THEFT OF IDENTITY' -- not a theft but our like operator above would pick it up so we exclude
        AND "DATE OCC" NOT LIKE '%2024%' -- excluding incomplete data
        AND "DATE OCC" NOT LIKE '%2025%' -- excluding incomplete data
),
-- converting date to julian day for linear regression calculation
crimes_per_day as (
    SELECT distinct 
        julianday(day) as juliandate,
        count("DR_NO") as crimes 
    FROM crimes
    GROUP BY 1
    ORDER BY 1
),
number_of_points as (
    SELECT 
        count(juliandate) as n
    FROM crimes_per_day 
),
slope as (
    SELECT 
        (sum(c.juliandate*c.crimes) - sum(c.juliandate)*sum(c.crimes)/m.n) / (sum(c.juliandate*c.juliandate) - sum(c.juliandate)*sum(c.juliandate)/m.n) as b
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
CROSS JOIN intercept as i;


