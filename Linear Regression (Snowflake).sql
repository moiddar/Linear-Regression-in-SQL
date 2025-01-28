-- Filtering for relevant crime data and aggregating to crimes per day
-- Converting date to epoch time for linear regression calculation
with crimes_per_day as (
    SELECT 
        date_part(epoch_second, to_date("DATE OCC",'MM/DD/YYYY')) as epochtime,
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
    AND "Crm Cd Desc" != 'THEFT OF IDENTITY' -- not a theft but our like operator above would pick it up so we exclude
    AND to_date("DATE OCC",'MM/DD/YYYY') < '2024-01-01' -- excluding incomplete data
    ORDER BY epochtime
),
-- regression calculation
regression as (
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
