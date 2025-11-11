/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Курочкина Анна 
 * Дата: 31.03.2025
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
-- Считаем общее количество пользователей, количество пользователей, которые совершили покупку и долю этих пользователей от общего числа игроков
SELECT COUNT(id) AS count_users,
SUM(payer) AS payer_users,
ROUND(AVG(payer), 4) AS avg_payer_users
FROM fantasy.users;
-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
-- Выводим название расы, количество платящих клиентов в разрере расы, общее количество игроков, которые играют за каждую расу, и считаем долю платящих игроков. Группируем по полю "раса". Изменяем тип данных при подсчёте доли, так как резульат находится в диапазоне от 0 до 1. 
SELECT race,
SUM(payer) AS payer_users,
COUNT(id) AS count_users,
ROUND(SUM(payer)::NUMERIC/COUNT(id), 4) AS payer_race
FROM fantasy.users 
LEFT JOIN fantasy.race ON users.race_id=race.race_id
GROUP BY race
ORDER BY payer_users DESC;
-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
-- Считаем количество совершённых покупок, общую сумму покупок, вычисляем минимальное, максимальное и среднее значение стоимости покупки, вычисляем медиану и стандартное отклонение стоимости покупки
SELECT COUNT(transaction_id) AS count_transaction,
SUM(amount) AS sum_amount,
MIN(amount) AS min_amount,
MAX(amount) AS max_amount,
AVG(amount)::NUMERIC(5, 2) AS avg_amount,
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS perc,
ROUND(STDDEV(amount)::NUMERIC, 2) AS stand_dev
FROM fantasy.events
WHERE amount>0;
-- 2.2: Аномальные нулевые покупки:
-- Считаем количество покупок с нулевой стоимостью, вычисляем их долю от общего числа покупок
SELECT SUM(CASE WHEN amount=0 THEN 1 ELSE 0 END) AS zero_count_amount,
SUM(CASE WHEN amount=0 THEN 1 ELSE 0 END)/COUNT(*)::NUMERIC AS part_zero_amount
FROM fantasy.events;
--Вычисляем, какие предметы были куплены за 0 у.е., сколько раз и сколько уникальных пользователей совершили такую покупку
SELECT game_items,
COUNT(amount) AS count_zero_amount,
COUNT(DISTINCT id) AS users_count
FROM fantasy.events
LEFT JOIN fantasy.items ON items.item_code=events.item_code
WHERE amount=0
GROUP BY game_items;
-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
--считаем количество всех покупок и суммарную стоимость всех покупок, где стоимость не равно нулю
SELECT CASE WHEN users.payer=0 THEN 'non-payers' ELSE 'payers' END AS payers,
COUNT(DISTINCT events.id) AS count_users, --количество покупателей 
ROUND(COUNT(transaction_id)/COUNT(DISTINCT events.id)::NUMERIC, 3) AS avg_users_bought, --количество событий делим на количество покупателей для подсчёта среднего количества покупок на одного покупателя
ROUND(SUM(amount)::NUMERIC/COUNT(DISTINCT events.id), 3) AS avg_sum_amount --средняя суммарная стоимость покупок на одного игрока
FROM fantasy.users
LEFT JOIN fantasy.events USING (id)
WHERE amount>0
GROUP BY payers;
--считаем количество игроков, среднее количество покупок и среднюю суммарную стоимость покупок в разрезе расы
WITH users_events AS (SELECT id, 
                      COUNT(transaction_id) AS count_events,
                      SUM(amount) AS sum_user_amount
                      FROM fantasy.events 
                      WHERE amount>0
                      GROUP BY id)
SELECT race,
CASE WHEN payer=0 THEN 'non-payers' ELSE 'payers' END AS payers,
COUNT(DISTINCT events.id) AS count_users, --количество покупателей 
ROUND(COUNT(transaction_id)/COUNT(DISTINCT events.id)::NUMERIC, 3) AS avg_users_bought, --количество событий делим на количество покупателей для подсчёта среднего количества покупок на одного покупателя
ROUND(SUM(amount)::NUMERIC/COUNT(DISTINCT events.id), 3) AS avg_sum_amount --считаем среднюю суммарную стоимость покупок  на одного покупателя
FROM fantasy.users
LEFT JOIN fantasy.events USING (id)
LEFT JOIN users_events ON events.id=users_events.id
LEFT JOIN fantasy.race ON race.race_id=users.race_id
WHERE amount>0
GROUP BY race, payers;
-- 2.4: Популярные эпические предметы:
-- Выводим названия предметов, считаем количество покупок каждого предмета, считаем долю покупок от общего количество покупок в игре, считаем долю пользователей, купивших предмет, от общего числа пользователей
SELECT game_items,
COUNT(transaction_id) AS count_items_sales,
COUNT(transaction_id)::NUMERIC/(SELECT COUNT(transaction_id) AS all_sales
FROM fantasy.events
WHERE amount>0) AS part_of_sales,
COUNT(DISTINCT id)::NUMERIC/(SELECT COUNT(DISTINCT id) AS all_users
FROM fantasy.events
WHERE amount>0) AS part_of_users
FROM fantasy.items 
LEFT JOIN fantasy.events ON events.item_code=items.item_code
WHERE amount>0
GROUP BY game_items
ORDER BY count_items_sales DESC;
--смотрим, какие предметы ни разу не были куплены игроками
SELECT game_items,
COUNT(transaction_id) AS zero_sales
FROM fantasy.items 
LEFT JOIN fantasy.events USING (item_code)
GROUP BY game_items
HAVING COUNT(transaction_id)=0;
-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
WITH count_race_users AS (SELECT race,
                          COUNT(id) AS count_users
                          FROM fantasy.users 
                          LEFT JOIN fantasy.race ON users.race_id=race.race_id
                          GROUP BY race), --считаем количество игроков за каждую расу
payer_users AS (SELECT race,
                COUNT(DISTINCT users.id) AS count_payer_users
                FROM fantasy.users 
                LEFT JOIN fantasy.race ON users.race_id=race.race_id
                LEFT JOIN fantasy.events ON events.id=users.id
                WHERE payer=1 AND amount>0
                GROUP BY race), --считаем количество платящих игроков среди покупателей за каждую расу
payer_race_users AS (SELECT race,
                     COUNT(DISTINCT id) AS count_buyer
                     FROM fantasy.events
                     LEFT JOIN fantasy.users USING (id)
                     LEFT JOIN fantasy.race ON users.race_id=race.race_id
                     WHERE amount>0
                     GROUP BY race), --считаем количество покупателей в каждой расе
all_bought AS (SELECT race,
               COUNT(transaction_id) AS count_bought,
               AVG(amount) AS avg_amount,
               SUM(amount) AS sum_amount
               FROM fantasy.events 
               LEFT JOIN fantasy.users ON users.id=events.id
               LEFT JOIN fantasy.race ON users.race_id=race.race_id
               WHERE amount>0
               GROUP BY race) --считаем общее количество покупок, среднюю стоимость одной покупки и сумму всех покупок без учёта покупок с нулевой стоимостью
--выводим расы персонажей, для каждой расы выводим количество игроков, количество покупателей, долю покупателей от общего количества игроков, долю платящих от совершивших покупки игроков, среднее количество покупок на одного игрока, среднюю стоимость одной покупки, среднюю суммарную стоимость всех покупок на одного игрока
SELECT count_race_users.race,
count_users,
count_buyer,
ROUND(count_buyer::NUMERIC/count_users, 4) AS part_buyer_of_all_users, --количество покупателей делим на количество всех игроков за расу и получаем долю покупателей
ROUND(count_payer_users/count_buyer::NUMERIC, 4) AS part_of_payers, --доля платящих покупателей от покупателей в разрезе рас
ROUND(count_bought/count_buyer::NUMERIC, 4) AS avg_count_bought, --среднее количество покупок на одного покупателя
ROUND(avg_amount::NUMERIC, 4) AS avg_amount, --средняя стоимость одной покупки
ROUND(sum_amount::NUMERIC/count_buyer::NUMERIC, 4) AS avg_sum_amount --средняя суммарная стоимость покупок на одного покупателя
FROM payer_race_users
LEFT JOIN count_race_users ON count_race_users.race=payer_race_users.race
LEFT JOIN all_bought ON all_bought.race=payer_race_users.race
LEFT JOIN payer_users ON payer_race_users.race=payer_users.race
GROUP BY count_race_users.race, count_users, count_buyer, avg_amount, sum_amount, count_bought, payer_users, payer_users.count_payer_users
ORDER BY count_users DESC;
-- Задача 2: Частота покупок
-- Напишите ваш запрос здесь