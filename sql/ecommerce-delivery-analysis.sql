SELECT
  COUNT(DISTINCT order_id) AS total_pesanan,
  SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) AS pesanan_terlambat,
  ROUND(SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) / COUNT(DISTINCT order_id) * 100, 2) AS persentase_terlambat
FROM `ecommerce_olist.master_orders`;

#Rata-Rata Durasi Pengiriman
SELECT
  ROUND(AVG(actual_delivery_days), 2) AS rata_aktual_hari,
  ROUND(AVG(estimated_delivery_days), 2) AS rata_estimasi_hari
FROM (
  SELECT DISTINCT order_id, actual_delivery_days, estimated_delivery_days
  FROM `ecommerce_olist.master_orders`
);

#Keterlambatan dan Skor Ulasan
SELECT
  CASE WHEN is_late = 1 THEN 'Terlambat' ELSE 'Tepat Waktu' END AS status_pengiriman,
  ROUND(AVG(review_score), 2) AS rata_rata_rating,
  COUNT(DISTINCT order_id) AS total_ulasan
FROM `ecommerce_olist.master_orders`
GROUP BY 1;

#Kinerja Wilayah (Negara Bagian)
SELECT
  customer_state,
  COUNT(DISTINCT order_id) AS total_pesanan,
  ROUND(SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) / COUNT(DISTINCT order_id) * 100, 2) AS persentase_terlambat
FROM `ecommerce_olist.master_orders`
GROUP BY customer_state
ORDER BY persentase_terlambat DESC
LIMIT 5;


#Kinerja Penjual (Seller)
SELECT
  seller_id,
  COUNT(DISTINCT order_id) AS total_pesanan,
  ROUND(SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) / COUNT(DISTINCT order_id) * 100, 2) AS persentase_terlambat
FROM `ecommerce_olist.master_orders`
GROUP BY seller_id
HAVING COUNT(DISTINCT order_id) > 50
ORDER BY persentase_terlambat DESC
LIMIT 5;

#Tren Keterlambatan Bulanan
SELECT
  FORMAT_TIMESTAMP('%Y-%m', order_purchase_timestamp) AS bulan_transaksi,
  COUNT(DISTINCT order_id) AS total_pesanan,
  ROUND(SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) / COUNT(DISTINCT order_id) * 100, 2) AS persentase_terlambat
FROM `ecommerce_olist.master_orders`
GROUP BY FORMAT_TIMESTAMP('%Y-%m', order_purchase_timestamp)
ORDER BY bulan_transaksi;

#Peringkat Wilayah (Window Function)
WITH StateDelay AS (
  SELECT
    customer_state,
    ROUND(SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) / COUNT(DISTINCT order_id) * 100, 2) AS persentase_terlambat
  FROM `ecommerce_olist.master_orders`
  GROUP BY customer_state
)
SELECT
  customer_state,
  persentase_terlambat,
  RANK() OVER (ORDER BY persentase_terlambat DESC) AS peringkat_keterlambatan
FROM StateDelay
ORDER BY peringkat_keterlambatan
LIMIT 5;

#Segmentasi Penjual
WITH SellerMetrics AS (
  SELECT
    seller_id,
    COUNT(DISTINCT order_id) AS total_pesanan,
    SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) AS terlambat
  FROM `ecommerce_olist.master_orders`
  GROUP BY seller_id
  HAVING COUNT(DISTINCT order_id) > 20
)
SELECT
  CASE 
    WHEN (terlambat / total_pesanan) <= 0.05 THEN 'Excellent'
    WHEN (terlambat / total_pesanan) <= 0.15 THEN 'Good'
    ELSE 'Poor'
  END AS segmen_performa,
  COUNT(seller_id) AS jumlah_penjual
FROM SellerMetrics
GROUP BY 1;

#Kategori Produk Paling Lambat
SELECT
  product_id,
  COUNT(DISTINCT order_id) AS frekuensi_beli,
  ROUND(AVG(actual_delivery_days), 2) AS rata_hari_pengiriman
FROM `ecommerce_olist.master_orders`
GROUP BY product_id
HAVING frekuensi_beli > 20
ORDER BY rata_hari_pengiriman DESC
LIMIT 5;


#Ongkos Kirim vs Keterlambatan
SELECT
  CASE WHEN is_late = 1 THEN 'Terlambat' ELSE 'Tepat Waktu' END AS status_pengiriman,
  ROUND(AVG(freight_value), 2) AS rata_rata_ongkir
FROM `ecommerce_olist.master_orders`
GROUP BY 1;

#Rata-Rata Bergerak (Moving Average 3 Bulan)
WITH MonthlyRating AS (
  SELECT
    FORMAT_TIMESTAMP('%Y-%m', order_purchase_timestamp) AS bulan_transaksi,
    AVG(review_score) AS rata_rating
  FROM `ecommerce_olist.master_orders`
  GROUP BY FORMAT_TIMESTAMP('%Y-%m', order_purchase_timestamp)
)
SELECT
  bulan_transaksi,
  ROUND(rata_rating, 2) AS rating_bulanan,
  ROUND(AVG(rata_rating) OVER (ORDER BY bulan_transaksi ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS moving_average_3_bulan
FROM MonthlyRating
ORDER BY bulan_transaksi;

#Waktu Pemrosesan Penjual
SELECT
  ROUND(AVG(TIMESTAMP_DIFF(order_delivered_carrier_date, order_approved_at, DAY)), 2) AS rata_hari_pemrosesan,
  MAX(TIMESTAMP_DIFF(order_delivered_carrier_date, order_approved_at, DAY)) AS maks_hari_pemrosesan
FROM `ecommerce_olist.master_orders`;

#Analisis Pesanan Paling Kecewa (Subquery Terhadap Diri Sendiri)
SELECT
  ROUND(AVG(actual_delivery_days), 2) AS rata_waktu_kirim
FROM `ecommerce_olist.master_orders`
WHERE order_id IN (
  SELECT order_id FROM `ecommerce_olist.master_orders` WHERE review_score = 1
);

#Pertumbuhan Keterlambatan MoM (Month-over-Month)
WITH MonthlyLate AS (
  SELECT
    FORMAT_TIMESTAMP('%Y-%m', order_purchase_timestamp) AS bulan_transaksi,
    SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) AS total_terlambat
  FROM `ecommerce_olist.master_orders`
  GROUP BY FORMAT_TIMESTAMP('%Y-%m', order_purchase_timestamp)
)
SELECT
  bulan_transaksi,
  total_terlambat,
  LAG(total_terlambat) OVER (ORDER BY bulan_transaksi) AS telat_bulan_sebelumnya,
  total_terlambat - LAG(total_terlambat) OVER (ORDER BY bulan_transaksi) AS selisih_pertumbuhan
FROM MonthlyLate
ORDER BY bulan_transaksi;

#Analisis Hari dalam Seminggu
SELECT
  EXTRACT(DAYOFWEEK FROM order_purchase_timestamp) AS hari_ke,
  COUNT(DISTINCT order_id) AS total_pesanan,
  ROUND(SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) / COUNT(DISTINCT order_id) * 100, 2) AS persentase_terlambat
FROM `ecommerce_olist.master_orders`
GROUP BY EXTRACT(DAYOFWEEK FROM order_purchase_timestamp)
ORDER BY persentase_terlambat DESC;

#
#