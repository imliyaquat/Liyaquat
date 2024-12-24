--ad hoc requests

--1

select 
city_name,
total_trips,
avg_fare_per_km,
avg_fare_per_trip,
round(
	total_trips*100.0/
	sum(total_trips) over(),2) as pct_contribution_to_total_trips  --5
from
(
select 
dc.city_name,  
count(f.trip_id) as total_trips,
	sum(fare_amount) /
	sum(distance_travelled_km) as avg_fare_per_km,
sum(fare_amount) /
count(f.trip_id) as avg_fare_per_trip
	from fact_trips f
join dim_city dc on dc.city_id = f.city_id
	group by dc.city_name
)
	order by 5 desc
;



------2

with actual_trips as
(
select 
city_id, 
date_trunc('month',date)::date as month,
count(trip_id) as actual_trips
from fact_trips f
group by 1,2
)
select 
c.city_name, 
to_char(a.month,'mm') as month_name, 
a.actual_trips::int, 
t.total_target_trips,
case when t.total_target_trips < a.actual_trips 
	 then 'Above Target' 
	 else 'Below Target' 
	 end as performance_status,
round(
	 abs(t.total_target_trips - a.actual_trips)*100.0/
	 t.total_target_trips,2) as percentage_difference
from actual_trips a
	join dim_city c on a.city_id = c.city_id
	join monthly_target_trips t on a.city_id= t.city_id and a.month = t.month
order by 1,2;

--3

with category_level_repeat_passengers as
(
select 
city_id, trip_count, 
	sum(repeat_passenger_count) as repeat_passengers 
from dim_repeat_trip_distribution a
	group by city_id, trip_count
),
city_level_repeat_passengers as
(
select city_id, 
	sum(repeat_passengers) as all_repeat_passengers 
from fact_passenger_summary
	group by city_id
)
select 
	dc.city_name,
round(sum(100*case when cr.trip_count like '2-%' then cr.repeat_passengers end)/
	  min(ct.all_repeat_passengers),1) as two_trips,
round(sum(100*case when cr.trip_count like '3-%' then cr.repeat_passengers end)/
	  max(ct.all_repeat_passengers),0) as three_trips,
round(sum(100*case when cr.trip_count like '4-%' then cr.repeat_passengers end)/
	  avg(ct.all_repeat_passengers),0) as four_trips,
round(sum(100*case when cr.trip_count like '5-%' then cr.repeat_passengers end)/
	  max(ct.all_repeat_passengers),0) as five_trips,
round(sum(100*case when cr.trip_count like '6-%' then cr.repeat_passengers end)/
	  max(ct.all_repeat_passengers),0) as six_trips,
round(sum(100*case when cr.trip_count like '7-%' then cr.repeat_passengers end)/
	  max(ct.all_repeat_passengers),0) as seven_trips,
round(sum(100*case when cr.trip_count like '8-%' then cr.repeat_passengers end)/
	  max(ct.all_repeat_passengers),0) as eight_trips,
round(sum(100*case when cr.trip_count like '9-%' then cr.repeat_passengers end)/
	  max(ct.all_repeat_passengers),0) as nine_trips,
round(sum(100*case when cr.trip_count like '10-%' then cr.repeat_passengers end)/
	  max(ct.all_repeat_passengers),0) as ten_trips
from category_level_repeat_passengers cr
	join city_level_repeat_passengers ct on cr.city_id= ct.city_id
	join dim_city dc on dc.city_id = cr.city_id
group by dc.city_name;


--4


select 
city_name, 
new_passengers,
case when rn <= 3 then 'Top 3'
	 when (select count(city_id) from dim_city) - rn < 3 then 'Bottom 3'
	 else ''
	 end as status
from
(
select 
dc.city_name, 
new_passengers,
rank() over(order by new_passengers desc) as rn
from
(
select
city_id, 
	sum(new_passengers) as new_passengers 
from fact_passenger_summary
	group by city_id
	) aa
join dim_city dc 
	on aa.city_id = dc.city_id
);




--5 highest revenue month for each city

select  
city_name, 
month_name as highest_revenue_month, 
round(
month_revenue/100000.0,1) as revenue_in_lac, 
	 round(
	 month_revenue*100/city_revnue,1) as pct_contribution
from
(
select *,
rank() over(partition by city_name order by month_revenue desc) as rn,
	 sum(month_revenue) over(partition by city_name) as city_revnue
from
(
select 
dc.city_name,
to_char(date,'Mon') as month_name,
	sum(fare_amount) as month_revenue
from fact_trips f
	join dim_city dc on dc.city_id = f.city_id
group by 1,2
	order by 1
)
)
where rn = 1
	order by 4 desc; 



--6

with monthly_repeat_passengers as
(
select 
city_id,
date_part('month',month) as month,
total_passengers,
repeat_passengers,
round(
	 repeat_passengers * 100.0/
	 total_passengers,2) as monthly_repeat_passenger_rate
from fact_passenger_summary
),
city_repeat_passengers as
(
select 
city_id,
round(
	 sum(repeat_passengers) * 100.0/
	 sum(total_passengers),2) as city_repeat_passenger_rate
from fact_passenger_summary
group by city_id
)
select 
dc.city_name, 
mr.month, 
mr.total_passengers, 
mr.repeat_passengers, 
mr.monthly_repeat_passenger_rate, 
cr.city_repeat_passenger_rate  
	from monthly_repeat_passengers mr
join city_repeat_passengers cr on mr.city_id = cr.city_id
join dim_city dc on dc.city_id = cr.city_id
	order by dc.city_name, mr.month;