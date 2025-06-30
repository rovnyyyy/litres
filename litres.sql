-- Расчет MAU по автороам
WITH mau AS (
    SELECT
        c.main_author_id
        , COUNT(DISTINCT a.puid) AS mau
        , EXTRACT(MONTH FROM msk_business_dt_str) AS month
    FROM bookmate.audition AS a
    JOIN bookmate.content AS c
        ON c.main_content_id = a.main_content_id
    WHERE EXTRACT(MONTH FROM msk_business_dt_str) = 11
      AND a.audition_id IS NOT NULL
    GROUP BY c.main_author_id, EXTRACT(MONTH FROM msk_business_dt_str)
)SELECT 
    au.main_author_name
    , m.mau
FROM mau AS m
JOIN bookmate.author AS au
    ON au.main_author_id = m.main_author_id
ORDER BY m.mau DESC
LIMIT 3;

-- Топ-3 произведений с наибольшим MAU в ноябре
WITH mau AS (
    SELECT 
        c.main_content_name
        , c.published_topic_title_list
        , c.main_author_id
        , COUNT(DISTINCT a.puid) AS mau
        , EXTRACT(MONTH FROM msk_business_dt_str) AS month
    FROM bookmate.audition AS a 
    JOIN bookmate.content AS c
        ON c.main_content_id = a.main_content_id
    WHERE EXTRACT(MONTH FROM msk_business_dt_str) = 11
      AND a.audition_id IS NOT NULL
    GROUP BY c.main_author_id, EXTRACT(MONTH FROM msk_business_dt_str), c.main_content_name, c.published_topic_title_list
)
SELECT 
    au.main_author_name
    , m.mau
    , m.main_content_name
    , m.published_topic_title_list
FROM mau AS m
JOIN bookmate.author AS au
    ON au.main_author_id = m.main_author_id
ORDER BY m.mau DESC
LIMIT 3;

-- Пользователи, активные 2 декабря
WITH initial_users AS (
    SELECT DISTINCT
        puid
    FROM
        bookmate.audition
    WHERE
        msk_business_dt_str = '2024-12-02'
),
-- Для каждого действия пользователя: дата активности + максимальная дата активности
user_activity_with_max AS (
    SELECT
        a.puid
        , a.msk_business_dt_str
        , MAX(a.msk_business_dt_str) OVER (PARTITION BY a.puid) AS max_activity_date
    FROM bookmate.audition a
    JOIN initial_users iu
        ON a.puid = iu.puid
    WHERE a.msk_business_dt_str >= '2024-12-02'
),
-- Считаем, через сколько дней пользователь вернулся
days_diff AS (
    SELECT
        puid
        , CAST(msk_business_dt_str AS DATE) - CAST('2024-12-02' AS DATE) AS day_since_install
    FROM user_activity_with_max
),
-- Считаем, сколько пользователей активны на каждый день жизни
daily_retention AS (
    SELECT 
        day_since_install
        , COUNT(DISTINCT puid) AS retained_users
    FROM days_diff
    GROUP BY day_since_install
)
SELECT
    day_since_install
    , retained_users
    , ROUND(retained_users * 1.0 / (SELECT COUNT(*) FROM initial_users), 2) AS retention_rate
FROM daily_retention
ORDER BY day_since_install;

-- Расчет LTV пользователей по городам "Москва" и "Санкт-Петербург"
WITH active_months AS (
    SELECT 
        DISTINCT a.puid
        , DATE_TRUNC('month', a.msk_business_dt_str::date) AS month
        , g.usage_geo_id_name AS city
    FROM bookmate.audition AS a
    JOIN bookmate.geo AS g
        ON g.usage_geo_id = a.usage_geo_id
    WHERE 
        g.usage_geo_id_name IN ('Москва', 'Санкт-Петербург') 
        AND a.audition_id IS NOT NULL
),
total_revenue AS (
    SELECT 
        city
        , COUNT(*) * 399 AS revenue
    FROM active_months
    GROUP BY city
),
total_users AS (
    SELECT 
        g.usage_geo_id_name AS city
        , COUNT(DISTINCT a.puid) AS total_users
    FROM bookmate.audition AS a
    JOIN bookmate.geo AS g
        ON g.usage_geo_id = a.usage_geo_id
    WHERE 
        g.usage_geo_id_name IN ('Москва', 'Санкт-Петербург')
    GROUP BY g.usage_geo_id_name
)
SELECT 
    tr.city
    ,tu.total_users
    , ROUND(1.0 * tr.revenue / tu.total_users, 2) AS ltv
FROM total_revenue AS tr
JOIN total_users AS tu
    ON tr.city = tu.city
ORDER BY ltv DESC;

-- Расчет средней выручки прослушанного часа
WITH monthly_activity AS (
    SELECT
        DATE_TRUNC('month', msk_business_dt_str::date) AS month
        , puid
        , SUM(hours) AS total_hours_per_user
    FROM bookmate.audition
    WHERE msk_business_dt_str::date BETWEEN '2024-09-01' AND '2024-11-30'
    GROUP BY month, puid
),
monthly_mau AS (
    SELECT 
        month
        , COUNT(DISTINCT puid) AS mau
    FROM monthly_activity
    GROUP BY month
),
monthly_hours AS (
    SELECT 
        month
        , SUM(total_hours_per_user) AS hours
    FROM monthly_activity
    GROUP BY month
)
SELECT
    m.month::DATE AS month
    , m.mau
    , ROUND(h.hours, 2) AS hours
    , ROUND((m.mau * 399) / NULLIF(h.hours, 0), 2) AS avg_hour_rev
FROM monthly_mau m
JOIN monthly_hours h ON m.month = h.month
ORDER BY m.month;

-- 2. Подготовка данных для проверки гипотезы
SELECT 
    usage_geo_id_name AS city
    , puid
    , SUM(hours) AS hours
FROM bookmate.audition AS a
JOIN bookmate.geo as g
ON g.usage_geo_id = a.usage_geo_id
WHERE usage_geo_id_name IN ('Москва', 'Санкт-Петербург')
GROUP BY usage_geo_id_name, puid


