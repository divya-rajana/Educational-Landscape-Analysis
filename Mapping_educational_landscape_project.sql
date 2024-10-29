create database mapping_educational_landscape_project;
use mapping_educational_landscape_project;

create table engineering_colleges
(College_name text,
Disticts text,
States text,
Ownership text,
Fees varchar(30),
Btech_courses varchar(30),
Mtech_courses varchar(30),
Rating varchar(20));

select * from engineering_colleges;

-- changing column names
alter table engineering_colleges 
change column `BTech_Courses` `Btech_course` varchar(50),
change column `MTech_Courses` `Mtech_Course` varchar(50);

-- No of rows in the dataset
select count(*) from engineering_colleges;
select count(distinct College_Name) from engineering_colleges;

-- checking for Null values
select count(*) from engineering_colleges 
where 
fees is null and btech_course is null and mtech_course is null and rating is null;

-- removing null values
delete from engineering_colleges
where 
fees is null and btech_course is null and mtech_course is null and rating is null;

delete  from engineering_colleges 
where btech_course is null and mtech_course is null;

delete from engineering_colleges
where fees is null and rating is null;

delete from engineering_colleges
where fees is null or rating is null;

-- Replacing string 
update engineering_colleges
set btech_course = concat(substring(Btech_Course, locate('(', Btech_Course) + 1, locate(' ', Btech_Course, locate('(', Btech_Course)) - locate('(', Btech_Course) - 1), ' Courses')
where Btech_Course regexp 'B.E /B.Tech \\([0-9]+ Courses\\)';

update engineering_colleges
set mtech_course = concat(substring(mtech_Course, locate('(', mtech_Course) + 1, locate(' ', mtech_Course, locate('(', mtech_Course)) - locate('(', mtech_Course) - 1), ' Courses')
where mtech_Course regexp 'M.E /M.Tech. \\([0-9]+ Courses\\)';

-- changing string to decimal values
select states,max(Fees_in_INR) from 
(select states,cast(replace(Fees, ' L', '') as decimal(10,0)) * 100000 AS Fees_in_INR
FROM engineering_colleges
WHERE Fees LIKE '% L')a group by states;

select states,max(Fees_in_INR) from 
(select states, CAST(REPLACE(Fees, ' K', '') AS DECIMAL(10,0)) * 1000 AS Fees_in_INR
FROM engineering_colleges
WHERE Fees LIKE '% K')a group by states;

update engineering_colleges
set Fees = cast(replace(Fees, 'L', '') as decimal(10,0)) * 100000
where Fees like '% L';

update engineering_colleges
set Fees = cast(replace(Fees, 'K', '') as decimal(10,0)) * 1000
where Fees like '% K';

select states,fees from engineering_colleges where fees is not null;
select states, max(fees) from engineering_colleges group by states;

-- List of colleges from Specific state
select college_name,ownership,districts,Btech_course,mtech_course,fees,rating
from engineering_colleges 
where states = " Andhra Pradesh";

-- List of colleges by ownership
select college_name,states
from engineering_colleges
where ownership = "Private";

-- Top colleges by rating
select college_name,states,rating
from engineering_colleges
where rating > 4.5 order by rating desc;

-- Colleges offering both B.tech and M.tech courses
select college_name,states,btech_course,mtech_course 
from engineering_colleges
where btech_course and Mtech_Course is not null;

-- Average Fees of colleges by states and ownership
select states,round(avg(fees),0) as Average_fees
from engineering_colleges
group by states order by average_fees desc;

select ownership,round(avg(fees),0) as Average_fees
from engineering_colleges
group by Ownership order by average_fees desc;

-- List of colleges based on affordablility
select college_name, 
case 
when fees <= 500000 then "affordable"
when fees between 500000 and 800000 then "Little Expensive"
when fees >= 800000 then "Expensive" 
else "unkown"
end as Affordability 
from engineering_colleges 
where rating > 4.5;

-- Best affordable colleges
select college_name,states,ownership,fees,btech_course
from engineering_colleges
where fees <= 500000 and rating > 4.5;

-- Number of courses offered by each college
select College_Name, States, Btech_Course, Rating
from engineering_colleges where btech_course is not null
order by cast(SUBSTRING_INDEX(Btech_Course, ' Courses', 1) as unsigned) desc;

-- window Function 
select *, dense_rank() over (partition by ownership order by fees desc) from engineering_colleges;

-- zone wise number of colleges list
drop view zone_wise_list;

create view zone_wise_list as
select college_name,Districts,states,ownership,fees,btech_course,mtech_course,rating,
case  
when lower(trim(states)) in ('Punjab', 'Haryana', 'Himachal Pradesh', 'Jammu and Kashmir', 'Uttarakhand', 'Delhi','Uttar Pradesh') then 'North'
When lower(trim(states)) in ('Karnataka', 'Tamil Nadu', 'Kerala', 'Andhra Pradesh', 'Telangana') then 'South'
When lower(trim(states)) in ('West Bengal', 'Bihar', 'Odisha', 'Jharkhand') then 'East'
When lower(trim(states)) in ('Maharashtra', 'Gujarat', 'Rajasthan', 'Goa') then 'West'
When lower(trim(states)) in ('Madhya Pradesh', 'Chhattisgarh') then 'Central'
When lower(trim(states)) in ('Assam', 'Arunachal Pradesh', 'Manipur', 'Meghalaya', 'Mizoram', 'Nagaland', 'Sikkim', 'Tripura') then 'North-East'
else 'Union Territory'
end as zone
from engineering_colleges;

select states,zone,count(college_name) as no_of_colleges 
from zone_wise_list 
group by zone,states 
order by no_of_colleges desc;

-- Number of colleges by ownership in each zone
select ownership,zone,count(college_name) as no_of_colleges 
from zone_wise_list 
group by ownership,zone 
order by no_of_colleges desc;

-- Average Fees and rating zone wise
select ownership,round(avg(fees),0) as Average_fee, floor(avg(rating)) as average_rating,zone 
from zone_wise_list 
group by ownership,zone order by ownership;

-- Zone wise best colleges
select college_name,states,zone,ownership,fees,btech_course,rating
from zone_wise_list
where fees < 500000 and rating > 4.5 order by zone desc;

-- calculating proxy ranking score to estimate rank range
## Considering rating 50%,fee 30% and ownership 10% weighatge to calculate proxy ranking score
select 
    college_name, states, rating, fees, ownership,
    round((0.5 * (rating / 5)) + 
    (0.3 * (1 - (fees / (select max(fees) from engineering_colleges)))) +
    (case when ownership = 'Government' then 0.1 else 0.05 end) +
    (case
        when Btech_course is not null then 0.1
		when Mtech_course is not null then 0.1
        else 0.05
    end),2) as proxy_ranking_score
from engineering_colleges
order by proxy_ranking_score desc;

-- colleges List based on estimated student EMCET rank using proxy ranking score
drop procedure list_clgs;
delimiter //

create procedure list_clgs(in input_rank int)
begin
    select 
        college_name, rating, fees, ownership, proxy_ranking_score,
        case 
            when proxy_ranking_score > 0.8 then '1-5000'
            when proxy_ranking_score between 0.6 and 0.8 then '5001-15000'
            else '15001 and above'
        end as estimated_rank_range
    from (
        select 
            college_name, rating, fees, ownership,
            round((0.5 * (rating / 5)) + 
            (0.3 * (1 - (fees / (select max(fees) from engineering_colleges)))) +
            (case when ownership = 'Government' then 0.1 else 0.05 end) +
            (case 
                when Btech_course is not null then 0.1
                when Mtech_course is not null then 0.1
                else 0.05
            end),2) as proxy_ranking_score
        from engineering_colleges
    ) as ranked_colleges
    where 
        (input_rank between 1 and 5000 and proxy_ranking_score > 0.8) or
        (input_rank between 5001 and 15000 and proxy_ranking_score between 0.6 and 0.8) or
        (input_rank > 15000 and proxy_ranking_score < 0.6)
    order by proxy_ranking_score desc;
end //
delimiter ;
call list_clgs(15589);

