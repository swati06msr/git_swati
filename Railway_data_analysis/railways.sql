--Railways Dataset Project

/*Objective: To identify key insights into railway operations, customer behaviour, and performance metrics.
By leveraging SQL for data analysis and Power BI for visualization, I aimed to uncover patterns and trends that could help optimize
railway services and improve customer satisfaction.

Dataset Overview 
The dataset used contains various columns related to railway ticket purchases and journey details. Key columns include:
•	Transaction ID
•	Date and Time of Purchase
•	Purchase Type and Payment Method
•	Railcard information
•	Ticket Class and Type
•	Price
•	Departure and Arrival Stations
•	Journey details such as Date, Departure Time, Arrival Time, Actual Arrival Time, Journey Status, Reason for Delay, 
and Refund Request.

This comprehensive dataset allowed us to perform a detailed analysis of railway operations.
*/

--create DATABASE RAILWAY2;
USE RAILWAY2;

--create table railway(
--[Transaction ID]  NVARCHAR(MAX),
--[Date of Purchase]  NVARCHAR(MAX) ,
--[Time of Purchase] time,
--[Purchase Type]  NVARCHAR(MAX) ,
--[Payment Method]  NVARCHAR(MAX) ,
--[Railcard]  NVARCHAR(MAX) ,
--[Ticket Class]  NVARCHAR(MAX) ,
--[Ticket Type]  NVARCHAR(MAX) ,
--[Price] NVARCHAR(MAX) ,
--[Departure Station]  NVARCHAR(MAX) ,
--[Arrival Destination]  NVARCHAR(MAX) ,
--[Date of Journey]  NVARCHAR(MAX) ,
--[Departure Time]  NVARCHAR(MAX) ,
--[Arrival Time]  NVARCHAR(MAX) ,
--[Actual Arrival Time]  NVARCHAR(MAX) ,
--[Journey Status]  NVARCHAR(MAX) ,
--[Reason for Delay]  NVARCHAR(MAX) ,
--[Refund Request]  NVARCHAR(MAX) ,
--)
--;
--TRUNCATE TABLE railway;
--BULK INSERT railway
--FROM 'C:\Users\swati\Downloads\railway.csv'
--WITH (
--      FIELDTERMINATOR = ',',
--     ROWTERMINATOR = '\n',
--     FIRSTROW=2
--);

select count(*) from railway;
---cleaning part
---price column junk fixed
SELECT * FROM railway WHERE ISNUMERIC(PRICE) <> 1;

---DROP FUNCTION Junkchars;

CREATE FUNCTION Junkchars (@input NVARCHAR(MAX))
RETURNS INT
AS
BEGIN
    -- Define a string of non-numeric characters to be removed
    DECLARE @nonNumericChars NVARCHAR(MAX) = '[A-Z]!@#$%^&*_ú-?/~`'

    -- Loop through each character in the non-numeric set and remove it
    DECLARE @i INT = 1
    DECLARE @len INT = LEN(@nonNumericChars)

    WHILE @i <= @len
    BEGIN
        SET @input = REPLACE(@input, SUBSTRING(@nonNumericChars, @i, 1), '')
        SET @i = @i + 1
    END

    -- Return the cleaned integer value, or NULL if the output is not numeric
    RETURN CASE 
               WHEN LEN(@input) > 0 THEN CAST(@input AS INT)
               ELSE NULL 
           END
END
;

update railway
set price = dbo.Junkchars(price) WHERE ISNUMERIC(PRICE) <> 1;

--date columns fix

SELECT [Date of Journey], ISdate([Date of Journey]) as d FROM railway WHERE ISdate([Date of Journey])=1;
SELECT * from railway where [Transaction ID] in ('8a66ead7-e381-4311-b667','1613505c-95e9-40bb-acd9');

SELECT [Date of Journey],replace(replace([Date of Journey], '*','-'),'--','-') as date
FROM railway
WHERE TRY_CONVERT(DATE, [Date of Journey], 105) IS NULL; 

update railway
set [Date of Journey]=replace(replace([Date of Journey], '*','-'),'--','-') WHERE TRY_CONVERT(DATE, [Date of Journey], 105) IS NULL; 

select * FROM railway
WHERE TRY_CONVERT(DATE, [Date of Purchase], 105) IS NULL; 

update railway
set [Date of Purchase]=replace([Date of Purchase], '%','-') WHERE TRY_CONVERT(DATE,[Date of Purchase], 105) IS NULL; 

create function timejunk(@input nvarchar(max))
returns nvarchar(max)
as
begin
 declare @output nvarchar(max)
 set @output= REPLACE(@input,'::',':')
 return @output
end;

update railway
set [Actual Arrival Time] = dbo.timejunk([Actual Arrival Time]) WHERE try_cONVERT(time, [Actual Arrival Time]) IS 
 NULL and [Actual Arrival Time] is not null; 

update railway
set [Departure Time] = dbo.timejunk([Departure Time]) WHERE try_cONVERT(time, [Departure Time]) IS 
 NULL and [Departure Time] is not null; 

 --replCE NULL

 CREATE FUNCTION ReplaceNull(
    @input VARCHAR(10),
    @defaultValue VARCHAR(10)
)
RETURNS VARCHAR(10)
AS
BEGIN
    RETURN ISNULL(@input, @defaultValue);
END;


UPDATE railway
SET [Reason for Delay] = dbo.ReplaceNull([Reason for Delay], 'No Delay');

alter table railway
alter column price int;

--Q:Identify Peak Purchase Times and Their Impact on Delays: 

select isnull(datediff(MINUTE,[Arrival Time],[Actual Arrival Time]),0),[transaction id] from railway;
--adding delay column
ALTER TABLE railway
ADD delay AS isnull(DATEDIFF(MINUTE,[Arrival Time],[Actual Arrival Time]),0);

-- purchase count with respect to purchase hours
with cte_p as (select datepart(hour, [Time of Purchase]) as 'purchase_hr' ,count(*) as 'purchase_count' from railway
group by datepart(hour, [Time of Purchase])
),
cte_d as (select datepart(hour, [Time of Purchase]) as 'purchase_hr',avg(delay) as 'Avg_delay' from railway
group by datepart(hour, [Time of Purchase])
)
select p.purchase_hr,
p.purchase_count,
d.avg_delay from cte_p p
join cte_d d on p.purchase_hr=d.purchase_hr order by p.purchase_count desc;

/*MOST DELAYED trains were for the purchase hour 9am ,highest volume of ticket purchases occurred between 6-9 AM and 5-8PM 
and no delay in evening hours*/

--Q2.	Analyze Journey Patterns of Frequent Travelers: 

select Railcard,[Purchase Type],[Ticket Class],[Departure Station],[Arrival Destination],
count(*) as 'Travellers Count' from railway
group by  Railcard,[Purchase Type],[Ticket Class],[Departure Station],[Arrival Destination]
having count(*)>3
order by 6 desc;
/* analysis revealed that frequent travelers typically commuted between London Kings Cross to York
and also in the route to Birmingham New Street from  London Euston and London St Pancras*/

--3.Revenue Loss Due to Delays with Refund Requests:

select sum(price) from railway where [Journey Status]='Delayed' and [Refund Request]='Yes';
-- The total revenue loss due to delayed journeys for which refund requests were made is 26165$
--This highlights the financial impact of delays and the importance of improving punctuality to minimize revenue losses.

--4.Impact of Railcards on Ticket Prices and Journey Delays: 

select 'Yes' as Railcard,avg(price) as Avgprice, 
format(sum(CASE WHEN [Journey Status] = 'Delayed' THEN 1 ELSE 0 END) * 100/count(*),'0.0')+'%' AS DelayRate
from railway where railcard in ('Adult','Senior')
union
select 'No' as Railcard,avg(price) as Avgprice, 
format(sum(CASE WHEN [Journey Status] = 'Delayed' THEN 1 ELSE 0 END) * 100/count(*),'0.0')+'%' AS DelayRate
from railway where railcard in ('None','Disabled')
;
/*Journeys with railcards had an average ticket price of $15 and a delay rate of 9%, while journeys without railcards had an 
average ticket price of $26 and a delay rate of 6%.
The data suggests that railcard holders experience slightly higher delays, possibly due to more frequent travel during peak times
but have less ticket price*/

--5.	Journey Performance by Departure and Arrival Stations: 

select [Departure Station],[Arrival Destination],avg(delay) as AvgDelayMinutues from railway
group by [Departure Station],[Arrival Destination]
having avg(delay) >0
order by 3 desc;

/* The journey from Manchester Piccadilly to Leeds had the most delayed journeys(avg of 1hr delay) followed by London Euston to York
with and avg delay of 36 mins
Identifying stations with higher average delays can help target improvements where they are most needed.*/

--6.	Revenue and Delay Analysis by Railcard and Station

select [Departure Station],[Arrival Destination],[Railcard],count(*) as journeys,avg(delay) as AvgDelayMinutues,sum(price) as Price from railway
group by [Departure Station],[Arrival Destination],[Railcard]
having avg(delay) >0
order by 4 desc;

/*Manchester Piccadilly to Liverpool Lime Street route has the highest journeys with less avg delay and with no railcard.
Liverpool Lime Street to London Euston route, despite having no railcard, generates the highest revenue overall with 3rd highest journey rate.
Senior railcard journeys  have less average delays and generate less revenue.*/

--7.Journey Delay Impact Analysis by Hour of Day

select datepart(hour,[time of Purchase]),AVG(delay) from railway
group by datepart(hour,[time of Purchase]) order by 2 desc;
--peak hour for delay is 9am with an avg delay of 10mins, also between 8pm-5am there is no delay

--BULK INSERT railway
--FROM 'C:\Users\swati\Downloads\railway.csv'
--WITH (
--      FIELDTERMINATOR = ',',
--     ROWTERMINATOR = '\n',
--     FIRSTROW=2
--);
