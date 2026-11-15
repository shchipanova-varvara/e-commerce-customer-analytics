WITH max_date AS (
  -- Шаг 0: Находим самую последнюю дату заказа в базе данных,
  -- чтобы считать свежесть (Recency) от нее, а не от сегодняшнего дня
  SELECT MAX(order_date) AS max_order_date
  FROM `ecommerce_analytics.orders`
  WHERE status != 'Cancelled'
),

rfm_raw AS (
  -- Шаг 1: Считаем сырые показатели R, F, M для каждого клиента
  SELECT
    o.customer_id,
    DATE_DIFF(m.max_order_date, MAX(o.order_date), DAY) AS recency_days,
    COUNT(DISTINCT o.order_id) AS frequency,
    SUM(oi.quantity * oi.price) AS monetary
  FROM
    `ecommerce_analytics.orders` AS o
  JOIN
    `ecommerce_analytics.order_items` AS oi ON o.order_id = oi.order_id
  CROSS JOIN
    max_date AS m
  WHERE
    o.status != 'Cancelled'
  GROUP BY
    o.customer_id, m.max_order_date
),

rfm_scores AS (
  -- Шаг 2: Начисляем оценки RFM от 1 до 4
  SELECT
    customer_id,
    recency_days,
    frequency,
    monetary,
    -- Recency и Monetary распределяем по 4 квартилям
    NTILE(4) OVER (ORDER BY recency_days DESC) AS r_score,
    
    -- Frequency оцениваем по жестким бизнес-порогам, чтобы избежать искажений 
    -- из-за массы клиентов с одинаковым 1 заказом при работе с NTILE
    CASE 
      WHEN frequency = 1 THEN 1
      WHEN frequency = 2 THEN 2
      WHEN frequency BETWEEN 3 AND 4 THEN 3
      ELSE 4
    END AS f_score,
    
    NTILE(4) OVER (ORDER BY monetary ASC) AS m_score
  FROM
    rfm_raw
),

rfm_segmented AS (
  -- Шаг 3: Переводим цифровые оценки в понятные названия бизнес-сегментов
  SELECT
    customer_id,
    recency_days,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    CASE
      WHEN r_score = 4 AND f_score = 4 AND m_score = 4 THEN 'VIP / Champions'
      WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customers'
      WHEN r_score >= 3 AND f_score <= 2 THEN 'New & Promising'
      WHEN r_score = 2 AND f_score >= 3 THEN 'At Risk Customers'
      WHEN r_score = 2 AND f_score <= 2 THEN 'Hibernating Customers'  -- Спящие (R=2, можно разбудить)
      ELSE 'Lost / Inactive Customers'                             -- Потерянные (R=1, минимальный приоритет)
    END AS segment
  FROM
    rfm_scores
)

-- Шаг 4: Агрегируем результаты и получаем итоговый отчет по сегментам
SELECT
  segment,
  COUNT(customer_id) AS total_customers,
  ROUND(COUNT(customer_id) * 100.0 / SUM(COUNT(customer_id)) OVER(), 2) AS customer_share_pct,
  ROUND(AVG(recency_days), 1) AS avg_recency_days,
  ROUND(AVG(frequency), 1) AS avg_orders_per_customer,
  ROUND(AVG(monetary), 2) AS avg_revenue_per_customer,
  ROUND(SUM(monetary), 2) AS total_segment_revenue
FROM
  rfm_segmented
GROUP BY
  segment
ORDER BY
  total_customers ASC;