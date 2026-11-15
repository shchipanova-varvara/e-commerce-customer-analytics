WITH order_totals AS (
  -- Шаг 1: Считаем честный тотал для каждого отдельного заказа
  SELECT
    o.order_id,
    o.customer_id,
    o.order_date,
    c.country,
    SUM(oi.quantity * oi.price) AS order_revenue
  FROM
    `ecommerce_analytics.orders` AS o
  JOIN
    `ecommerce_analytics.customers` AS c ON o.customer_id = c.customer_id
  JOIN
    `ecommerce_analytics.order_items` AS oi ON o.order_id = oi.order_id
  WHERE
    (o.status != 'Cancelled' OR o.status IS NULL)
  GROUP BY
    o.order_id, o.customer_id, o.order_date, c.country
)

-- Шаг 2: Агрегируем по месяцу и стране для получения честного AOV
SELECT
  DATE_TRUNC(order_date, MONTH) AS order_month,
  country,
  COUNT(DISTINCT order_id) AS total_orders,
  COUNT(DISTINCT customer_id) AS total_customers,
  ROUND(SUM(order_revenue), 2) AS total_revenue,
  ROUND(AVG(order_revenue), 2) AS avg_order_value -- Честный AOV
FROM
  order_totals
GROUP BY
  1, 2
ORDER BY
  order_month DESC,
  total_revenue DESC;