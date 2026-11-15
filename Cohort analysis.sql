WITH user_cohorts AS (
  -- Шаг 1: Определяем месяц первой покупки для каждого клиента (его "когорту")
  SELECT
    customer_id,
    DATE_TRUNC(MIN(order_date), MONTH) AS cohort_month
  FROM
    `ecommerce_analytics.orders`
  WHERE
    status != 'Cancelled'
    -- ОТСЕКАЕМ ТЕКУЩИЙ НЕЗАВЕРШЕННЫЙ МЕСЯЦ:
    -- Берем только заказы до первого числа текущего месяца, чтобы не занижать Retention
    AND DATE_TRUNC(order_date, MONTH) < DATE_TRUNC(CURRENT_DATE(), MONTH)
  GROUP BY
    customer_id
),

customer_activities AS (
  -- Шаг 2: Сопоставляем все покупки клиентов с их когортой и считаем смещение в месяцах
  SELECT
    o.customer_id,
    uc.cohort_month,
    DATE_TRUNC(o.order_date, MONTH) AS order_month,
    DATE_DIFF(DATE_TRUNC(o.order_date, MONTH), uc.cohort_month, MONTH) AS month_number
  FROM
    `ecommerce_analytics.orders` AS o
  JOIN
    user_cohorts AS uc
      ON o.customer_id = uc.customer_id
  WHERE
    o.status != 'Cancelled'
    -- ОТСЕКАЕМ ТЕКУЩИЙ НЕЗАВЕРШЕННЫЙ МЕСЯЦ:
    -- Исключаем повторные покупки текущего месяца для корректности расчетов
    AND DATE_TRUNC(o.order_date, MONTH) < DATE_TRUNC(CURRENT_DATE(), MONTH)
),

cohort_size AS (
  -- Шаг 3: Считаем общий исходный размер каждой когорты (на Месяц 0)
  SELECT
    cohort_month,
    COUNT(DISTINCT customer_id) AS total_cohort_customers
  FROM
    user_cohorts
  GROUP BY
    cohort_month
)

-- Шаг 4: Главный расчет — считаем количество вернувшихся клиентов и % удержания (Retention)
SELECT
  ca.cohort_month,
  cs.total_cohort_customers AS cohort_size,
  ca.month_number,
  COUNT(DISTINCT ca.customer_id) AS active_customers,
  ROUND(COUNT(DISTINCT ca.customer_id) * 100.0 / cs.total_cohort_customers, 2) AS retention_rate_pct
FROM
  customer_activities AS ca
JOIN
  cohort_size AS cs
    ON ca.cohort_month = cs.cohort_month
GROUP BY
  ca.cohort_month,
  cs.total_cohort_customers,
  ca.month_number
ORDER BY
  ca.cohort_month ASC,
  ca.month_number ASC;