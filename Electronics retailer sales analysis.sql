
-- 1. data standardlization: 
-- 1.1 'customers': capital each word of cities

SELECT * FROM `electronic retailer`.customers;

update customers
set city= 
concat(
left(substring_index(city,' ',1),1),
lower(substring(substring_index(city,' ',1),2,length(substring_index(city,' ',1)))),
' ',
left(substring_index(city,' ','-1'),1),
lower(substring(substring_index(city,' ',-1),2,length(substring_index(city,' ',-1)))));

-- 1.2 'customers': update date format

update customers
set birthday=str_to_date(birthday,'%m/%d/%Y');

-- 1.3 'products': remove $ from the values

update products
set unit_cost_usd=substring(unit_cost_usd,2);

update products
set unit_price_usd=substring(unit_price_usd,2);

-- 1.4 create 'subcategory' table and 'category' table, remove some removable repetitive values from 'products' table

create table subcategory
select distinct
subcategorykey,
subcategory,
categoryKey
from products;

create table category
select distinct
categorykey,
category
from products;

alter table products
drop column category,
drop column categorykey,
drop column subcategory;

-- 1.5 'exchange_rates' update date format, add identity column for 'exchange rate' table, add trackable column for further exchange currency calculation

update exchange_rates
set date=str_to_date(date,'%m/%d/%Y');

alter table exchange_rates
add column exchange_rate_id int after `date`,
add column echange_currency varchar(25) after `exchange`;

update exchange_rates
set echange_currency=concat(`date`,' ',currency);

-- 1.6 'sales': add identity column, update date formate, transfer empty value in 'delivery date' column to null, add trackable column for further exchange currency calculation

alter table sales
add column order_id int after order_number;

update sales
set order_date=str_to_date(order_date,'%m/%d/%Y');
update sales
set delivery_date=nullif(delivery_date,'');

update sales
set delivery_date= str_to_date(delivery_date,'%m/%d/%Y');

alter table sales
add column exchange_currency varchar(25) after currency_code;

update sales
set exchange_currency = concat(order_date, ' ',currency_code);

-- 1.7 'store' update date formate, transfer empty value in 'square meter' column to null
update store
set open_date=str_to_date(open_date,'%m/%d/%Y');

update store
set square_meters=nullif(square_meters,'');

-- 2 total orders, order lines trend analysis 
-- 2.1 total orders
select 
count(distinct order_number)
from sales;

-- total order: '26326'

-- 2.2 order quantity trend (year and month)
select
year(order_date) as yr,
month(order_date) as mo,
sum(quantity) as total_qty
from sales
group by 1,2;

-- 2.3 order quantity trend(category), exclude truncated year 2021
select 
year(order_date)as yr,
d.category as category,
sum(a.quantity) as order_qty
from sales a
left join products b
on a.productid=b.productid
left join subcategory c
on b.subcategoryid=c.subcategoryid 
left join category d
on c.categoryid=d.categoryid
where year(order_date)<'2021'
group by 1,2;

-- 3. revenue trend analysis
-- 3.1 revenue trend (year and month)
select
year(order_date)as yr,
month(order_date) as mon,
round(sum(a.quantity*b.unit_price_usd),2) as total_rev
from sales a
left join products b
on a.productid=b.productid
group by 1,2;

-- 3.2 categoty performance (revenue-usd)& stored procedure

delimiter //
create procedure categ_rev()
begin 

select 
year(order_date)as yr,
d.category as category,
round(sum(a.quantity*b.unit_price_usd),2) as total_rev_category
from sales a
left join products b
on a.productid=b.productid
left join subcategory c
on b.subcategoryid=c.subcategoryid 
left join category d
on c.categoryid=d.categoryid
where year(order_date) <'2021'
group by 1,2;

end //
delimiter ;

call categ_rev();

-- 3.3 revenue-local currency
select
c.currency,
round(sum(case when year(order_date)='2016' then a.quantity*b.unit_price_usd*c.`exchange`else null end),2) as '2016',
round(sum(case when year(order_date)='2017' then a.quantity*b.unit_price_usd*c.`exchange`else null end),2) as '2017',
round(sum(case when year(order_date)='2018' then a.quantity*b.unit_price_usd*c.`exchange`else null end),2) as '2018',
round(sum(case when year(order_date)='2019' then a.quantity*b.unit_price_usd*c.`exchange`else null end),2) as '2019',
round(sum(case when year(order_date)='2020' then a.quantity*b.unit_price_usd*c.`exchange`else null end),2) as '2020'
from sales a
left join products b
on a.productid=b.productid
left join exchange_rates c
on a.exchange_currency=c.exchange_currency
group by 1;

-- 3.4 store performance (country level)
select
year(order_date)as yr,
c.country,
round(sum(a.quantity*b.unit_price_usd),2) as total_rev
from sales a
left join products b
on a.productid=b.productid
left join store c
on a.storeid=c.storeid
where year(order_date) <'2021'
group by 1,2;

-- 4. multiple item order, the advice of the cross-sell products
select*
from products;

create temporary table multiple_item_order
select 
a.order_id,
a.order_number,
a.line_item,
b.productid,
b.product_name
from sales a 
left join products b
on a.productid=b.productid
where line_item>'1';
drop table multiple_item_order;

create temporary table cross_sell_orderlist
select
a.order_number,
c.productid,
c.product_name
from multiple_item_order a
left join sales b
on a.order_number=b.order_number
left join products c
on b.productid=c.productid;

-- e.g.productid 57
select
productid,
product_name,
count(distinct order_number)as frequence
from(
select distinct
a.order_number,
b.productid,
c. product_name
from cross_sell_orderlist a
left join sales b
on a.order_number=b.order_number
left join products c
on b.productid=c.productid
where a.productid='57') as cross_sell_57
group by 1,2
order by 3 desc;

-- 5. average order value (category and subcategory)
select
year(order_date)as yr,
d.category,
c.subcategory,
round(avg(a.quantity*b.unit_price_usd),2) as avg_rev
from sales a
left join products b
on a.productid=b.productid
left join subcategory c
on b.subcategoryid=c.subcategoryid 
left join category d
on c.categoryid=d.categoryid
where year(order_date) <'2021'
group by 1,2,3;

-- 6. delivery time analysis=>line chart
-- 6.1 online shopping delivery trend (year)
select
year(order_date),
ceiling(round(avg(datediff(delivery_date,order_date)),1)) as avg_delivery_days
from sales
where storeid='67'
group by 1;

-- 6.2 top 5 products with slowest delivery
select
productid,
ceiling(round(avg(datediff(delivery_date,order_date)),1)) as avg_delivery_days
from sales
where storeid='67'
group by 1
order by 2 desc
Limit 5;

-- 7. color preference by product
select 
b.productid,
b.product_name,
b.color,
sum(a.quantity) as qty
from sales a
left join products b
on a.productid=b.productid
group by 1,2,3
order by 1,4;


-- 8. ABC value product judgement (driving the revenue)
-- A 20% items->80% value; B 30% items->15% value; C 50% items->5% value

select
a.productid,
sum(a.quantity*(b.unit_price_usd-b.unit_cost_usd))as total_profit,
sum(a.quantity*(b.unit_price_usd-b.unit_cost_usd))/'32662688.38'*100 as pct
from sales a
left join products b
on a.productid=b.productid
group by 1
order by 2 desc;
-- total profit, '32662688.38'(clause-with rollup)




