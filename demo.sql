-- Active: 1693414321705@@127.0.0.1@5432@dvdrental@public

------------------------------------------------------------
-- 1. Query
------------------------------------------------------------
SELECT c.customer_id, c.first_name, c.last_name, ca.category_id, ca.name AS category_name, COUNT(f.film_id) AS film_count, SUM(p.amount) AS amount
FROM customer AS c
JOIN rental AS r ON c.customer_id = r.customer_id
JOIN inventory AS i ON r.inventory_id = i.inventory_id
JOIN film AS f ON i.film_id = f.film_id
JOIN film_category AS fc ON f.film_id = fc.film_id
JOIN category AS ca ON fc.category_id = ca.category_id
JOIN payment AS p ON r.rental_id = p.rental_id
GROUP BY c.customer_id, c.first_name, c.last_name, ca.category_id, ca.name
ORDER BY c.customer_id, c.first_name, c.last_name, ca.category_id, ca.name


------------------------------------------------------------
-- 2. Create View
------------------------------------------------------------
CREATE VIEW report_view AS
SELECT c.customer_id, c.first_name, c.last_name, ca.category_id, ca.name AS category_name, COUNT(f.film_id) AS film_count, SUM(p.amount) AS amount
FROM customer AS c
JOIN rental AS r ON c.customer_id = r.customer_id
JOIN inventory AS i ON r.inventory_id = i.inventory_id
JOIN film AS f ON i.film_id = f.film_id
JOIN film_category AS fc ON f.film_id = fc.film_id
JOIN category AS ca ON fc.category_id = ca.category_id
JOIN payment AS p ON r.rental_id = p.rental_id
GROUP BY c.customer_id, c.first_name, c.last_name, ca.category_id, ca.name
ORDER BY c.customer_id, c.first_name, c.last_name, ca.category_id, ca.name

------------------------------------------------------------
-- 3. Create Materialized View
------------------------------------------------------------
CREATE MATERIALIZED VIEW report_materialized_view AS
SELECT c.customer_id, c.first_name, c.last_name, ca.category_id, ca.name AS category_name, COUNT(f.film_id) AS film_count, SUM(p.amount) AS amount
FROM customer AS c
JOIN rental AS r ON c.customer_id = r.customer_id
JOIN inventory AS i ON r.inventory_id = i.inventory_id
JOIN film AS f ON i.film_id = f.film_id
JOIN film_category AS fc ON f.film_id = fc.film_id
JOIN category AS ca ON fc.category_id = ca.category_id
JOIN payment AS p ON r.rental_id = p.rental_id
GROUP BY c.customer_id, c.first_name, c.last_name, ca.category_id, ca.name
ORDER BY c.customer_id, c.first_name, c.last_name, ca.category_id, ca.name


------------------------------------------------------------
-- 4. EXPAIN ANALYZE
------------------------------------------------------------
EXPLAIN ANALYZE
SELECT *
FROM report_view

EXPLAIN ANALYZE
SELECT *
FROM report_materialized_view

------------------------------------------------------------
-- 5. REFRESH MATERIALIZED VIEW (NO CONCURRENTLY OPTION)
------------------------------------------------------------
REFRESH MATERIALIZED VIEW report_materialized_view

------------------------------------------------------------
-- 6. REFRESH MATERIALIZED VIEW (WITH CONCURRENTLY OPTION)
------------------------------------------------------------
REFRESH MATERIALIZED VIEW CONCURRENTLY report_materialized_view

------------------------------------------------------------
-- 7. CREATE UNIQUE INDEX
------------------------------------------------------------

-- 7.1 One or more unique indexes must exist in the materialized view for the CONCURRENTLY option to be executed.
--     CONCURRENTLY オプションを実行するためには、マテリアライズドビューに1つ以上のユニークインデックスが存在する必要がある。
CREATE UNIQUE INDEX idx__report_materialized_view_customer_id_category_id ON report_materialized_view (customer_id, category_id)

-- 7.2 Check index
SELECT
    tablename,
    indexname,
    indexdef
FROM
    pg_indexes
WHERE
    schemaname = 'public'
    and tablename = 'report_materialized_view'
ORDER BY
    tablename,
    indexname;

-- 7.3 REFRESH MATERIALIZED VIEW (WITH CONCURRENTLY OPTION)
REFRESH MATERIALIZED VIEW CONCURRENTLY report_materialized_view


------------------------------------------------------------
-- 8. AUTO REFRESH USING PG_CRON
------------------------------------------------------------

-- 8.1 Enable pg_cron extension
CREATE EXTENSION pg_cron;

-- 8.2 Create cron job (Refresh materialized view every minute)
SELECT cron.schedule ('refresh__report_materialized_view', '* * * * *', 'REFRESH MATERIALIZED VIEW CONCURRENTLY report_materialized_view');

-- 8.3 Create cron job (Purging the pg_cron history table)
-- 
-- > The cron.job_run_details table contains a history of cron jobs that can become very large over time.
-- > We recommend that you schedule a job that purges this table. 
-- 
-- > cron.job_run_details テーブルには、時間の経過とともに非常に大きくなる可能性がある cron ジョブの履歴が含まれています。
-- > そのため、このテーブルをクリアにするジョブをスケジュールすることをお勧めします。
SELECT cron.schedule('purge__pg_cron_history_table', '* * * * *', $$DELETE FROM cron.job_run_details WHERE end_time < now() - interval '2 minutes'$$);
