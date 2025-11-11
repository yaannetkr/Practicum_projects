-- 1. Исследовательский анализ данных
-- Вычисляем аномальные по стоимости покупки
select MIN(last_price) as min_price,
MAX(last_price) as max_price
from real_estate.advertisement; 
-- Собираем информацию о квартирах с аномальной стоимостью
select *
from real_estate.advertisement
left join real_estate.flats using(id)
order by last_price;
select *
from real_estate.advertisement
left join real_estate.flats using(id)
order by last_price DESC;
--Считаем количество объявлений
select COUNT(*)
from real_estate.advertisement;
--Узнаём период, в который представлены объявления
select MIN(first_day_exposition) as min_date,
MAX(first_day_exposition) as max_date
from real_estate.advertisement;
--Узнаём распределение объявлений в зависимости от типа населённого пункта
select type,
COUNT(distinct city_id) as count_city,
COUNT(id) as count_advertisement
from real_estate.type
left join real_estate.flats using (type_id)
left join real_estate.city using (city_id)
group by type
order by count_city DESC;
--Собираем информацию по длительности нахождения объявления на сайте (минимальное, максимальное и среднее знаечние, медиана)
select min (days_exposition) as min_days,
max (days_exposition) as max_days,
ROUND(avg (days_exposition)::NUMERIC, 3) as avg_days,
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY days_exposition) AS perc
from real_estate.advertisement;
--Процент проданных объектов недвижимости
select ROUND((select COUNT(days_exposition)
        from real_estate.advertisement
        where days_exposition is NOT null)/COUNT(*)::numeric*100, 3) as perc_bought
from real_estate.advertisement;
--Вычисляем индентификатор города Санкт-Петербург
select *
from real_estate.city;
--Процент квартир, продаваемых в Санкт-Петербурге
select ROUND((select COUNT(id)
        from real_estate.flats 
        where city_id = '6X8I')/COUNT(*)::numeric*100, 3) as perc_flats_SPB
from real_estate.flats;
--Считаем показатели стоимости одного квадратного метра
select ROUND(MIN(last_price/total_area)::numeric, 3) as min_price,
ROUND(MAX(last_price/total_area)::numeric, 3) as max_price,
ROUND(AVG(last_price/total_area)::numeric, 3) as avg_price,
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY last_price/total_area::numeric) AS perc
from real_estate.advertisement
left join real_estate.flats USING(id);
--Минимальное, максимальное, среднее, медианное значение общей площади квартир
select MIN(total_area) as min_area,
MAX(total_area) as max_area,
ROUND(AVG(total_area)::numeric, 3) as avg_area,
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY total_area) AS perc_50,
PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS perc_99
from real_estate.flats;
--Минимальное, максимальное, среднее, медианное значение количества комнат
select MIN(rooms) as min_rooms,
MAX(rooms) as max_rooms,
ROUND(AVG(rooms)::numeric, 3) as avg_rooms,
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS perc_50,
PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS perc_99
from real_estate.flats;
--Минимальное, максимальное, среднее, медианное значение количества балконов
select MIN(balcony) as min_balcony,
MAX(balcony) as max_balcony,
ROUND(AVG(balcony)::numeric, 3) as avg_balcony,
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony) AS perc_50,
PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS perc_99
from real_estate.flats;
--Минимальное, максимальное, среднее, медианное значение высоты потолков
select MIN(ceiling_height) as min_ceiling_height,
MAX(ceiling_height) as max_ceiling_height,
ROUND(AVG(ceiling_height)::numeric, 3) as avg_ceiling_height,
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY ceiling_height) AS perc_50,
PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS perc_99
from real_estate.flats;
--Минимальное, максимальное, среднее, медианное значение этажа
select MIN(floor) as min_floor,
MAX(floor) as max_floor,
ROUND(AVG(floor)::numeric, 3) as avg_floor,
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floor) AS perc_50,
PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY floor) AS perc_99
from real_estate.flats;

-- 2. Решение ad-hoc задач
--Задача 1. Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
--выделим категории ЛенОбл и Санкт-Петербург, а также категории длительности размещения объявлений на сайте
category as (
select case when city_id = '6X8I' then 'Санкт-Петербург' else 'ЛенОбл' end as name_area,
case when days_exposition<=30 then 'месяц'
when days_exposition between 31 and 90 then 'квартал'
when days_exposition between 91 and 180 then 'полгода'
when days_exposition>=181 then 'больше полугода'
else 'не сняты с продажи'
end as duration,
COUNT(id) as count_advertisement,
ROUND(AVG(last_price/total_area)::numeric, 0) as avg_price, --средняя стоимость за квадратный метр
ROUND(AVG(total_area)::numeric, 3) as avg_area, --средняя площадь
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS median_rooms, --медианное значение количества комнат
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony) AS median_balcony, --медианное значение количества балконов
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floor) AS median_floor, --медианное значение этажности квартиры
ROUND(AVG(ceiling_height)::numeric, 3) as avg_ceiling_height, --средняя высота потолка
ROUND(AVG(airports_nearest)::numeric, 3) as avg_airoport,-- среднее расстояние до аэропорта
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY parks_around3000) AS median_parks, --медианное значение количества парков вблизи квартиры
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY ponds_around3000) AS median_ponds --медианное значение количества водоёмов вблизи квартиры
from real_estate.city
left join real_estate.flats USING(city_id)
left join real_estate.advertisement USING(id)
left join real_estate.type using (type_id)
where id IN (SELECT * FROM filtered_id) and type in ('город') and (DATE_TRUNC('year', first_day_exposition) between '2015-01-01' and '2018-12-31')
group by name_area, duration)
-- Выведем объявления без выбросов:
SELECT *,
ROUND(count_advertisement/SUM(count_advertisement) OVER(PARTITION by name_area), 3) as part_of_area -- доля объявлений от всех объявлений в категориях "ЛенОбл" и "Санкт-Петербург"
FROM category;

-- Задача 2. Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
--считаем кол-во публикаций по месяцам, узнаём среднюю стоимость за квадратный метр и среднюю площадь квартир
start_advertisement as (select EXTRACT(month from first_day_exposition::date) as start_month, 
                        COUNT(id) as count_open_advertisement,
                        ROUND(AVG(last_price/total_area)::numeric, 3) as avg_price,
                        ROUND(AVG(total_area)::numeric, 3) as avg_area
                        from real_estate.advertisement
                        left join real_estate.flats USING(id)
                        left join real_estate.type USING(type_id)
                        where id IN (SELECT * FROM filtered_id) and (DATE_TRUNC('year', first_day_exposition) between '2015-01-01' and '2018-12-31') and type in ('город')
                        group by start_month
                        order by start_month),
--считаем кол-во снятия публикаций по месяцам
end_advertisement as (select extract(month from ((first_day_exposition+days_exposition::int)::date)) as end_month,
                      COUNT(id) as count_end_advertisement
                      from real_estate.advertisement
                      left join real_estate.flats USING(id)
                      left join real_estate.type USING(type_id)
                      where id IN (SELECT * FROM filtered_id) and (DATE_TRUNC('year', first_day_exposition) between '2015-01-01' and '2018-12-31') and type in ('город') and days_exposition is not NULL
                      group by end_month
                      order by end_month)
select start_advertisement.start_month as num_month,
case when start_advertisement.start_month = 1 then 'Январь'
when start_advertisement.start_month = 2 then 'Февраль'
when start_advertisement.start_month = 3 then 'Март'
when start_advertisement.start_month = 4 then 'Апрель'
when start_advertisement.start_month = 5 then 'Май'
when start_advertisement.start_month = 6 then 'Июнь'
when start_advertisement.start_month = 7 then 'Июль'
when start_advertisement.start_month = 8 then 'Август'
when start_advertisement.start_month = 9 then 'Сентябрь'
when start_advertisement.start_month = 10 then 'Октябрь'
when start_advertisement.start_month = 11 then 'Ноябрь'
else 'Декабрь'
end as month,
count_open_advertisement,
ROUND(count_open_advertisement/(select COUNT(id) 
                          from real_estate.advertisement
                          left join real_estate.flats USING(id)
                          left join real_estate.type USING(type_id)
                          where id IN (SELECT * FROM filtered_id) and (DATE_TRUNC('year', first_day_exposition) between '2015-01-01' and '2018-12-31') and type in ('город'))::numeric*100, 2) as perc_opened_advertisment, --процент открытых объявлений за месяц от всех открытых объявлений 
DENSE_RANK() OVER(ORDER BY count_open_advertisement DESC) as rank_count_open, --ранжируем месяцы по количеству размещения объявлений
count_end_advertisement,
ROUND(count_end_advertisement/(select COUNT(id) 
                          from real_estate.advertisement
                          left join real_estate.flats USING(id)
                          left join real_estate.type USING(type_id)
                          where id IN (SELECT * FROM filtered_id) and (DATE_TRUNC('year', first_day_exposition) between '2015-01-01' and '2018-12-31') and type in ('город') and days_exposition is not NULL)::numeric*100, 2) as perc_closed_advertisment, --процент закрытых объявлений за месяц от всех закрытых объявлений 
DENSE_RANK() OVER(ORDER BY count_end_advertisement DESC) as rank_count_end, --ранжируем месяцы по количеству закрытия объявлений
avg_price,
avg_area
from start_advertisement
left join end_advertisement on end_advertisement.end_month=start_advertisement.start_month
group by start_advertisement.start_month, count_open_advertisement, count_end_advertisement, avg_price, avg_area
order by num_month;

--Задача 3. Анализ рынка недвижимости Ленобласти
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
closed_advertisement as (select city,
                         count(flats.id) as count_closed_advertisement
                         from real_estate.city
                         left join real_estate.flats using (city_id)
                         left join real_estate.advertisement USING(id)
                         where id IN (SELECT * FROM filtered_id) and city_id <> '6X8I' and days_exposition is not null and (DATE_TRUNC('year', first_day_exposition) between '2015-01-01' and '2018-12-31')
                         group by city)
select city,
count(flats.id) as count_all_advertisement, --количество объявлений 
ROUND(count_closed_advertisement/count(flats.id)::numeric, 3) as part_of_closed, --доля снятых с публикации объявлений
ROUND(AVG(last_price/total_area)::numeric, 3) as avg_price,
ROUND(AVG(total_area)::numeric, 3) as avg_area,
ROUND(avg (days_exposition)::NUMERIC, 3) as avg_days
from real_estate.city
left join real_estate.flats using (city_id)
left join closed_advertisement USING(city)
left join real_estate.advertisement USING(id)
where id IN (SELECT * FROM filtered_id) and city_id <> '6X8I' and (DATE_TRUNC('year', first_day_exposition) between '2015-01-01' and '2018-12-31')
group by city, closed_advertisement.count_closed_advertisement
order by count_all_advertisement DESC
limit 15; --ТОП-15 по количеству объявлений