#!/bin/sh

# Define variables
MYSQL_HOST='mysql_host'  # Cập nhật với địa chỉ MySQL thực tế
MYSQL_USER='root'
MYSQL_PASSWORD='U4VpcRdo8nCajs7O6Fs4sPB6'
MYSQL_DATABASE='sales'
POSTGRES_HOST='localhost'
POSTGRES_USER='postgres'
POSTGRES_PASSWORD='eYFfL7KsKcfZ0MGeRKjZuiPp'
POSTGRES_DB='sales_new'
SALES_CSV='/home/project/sales.csv'

# Kiểm tra nếu thư mục tồn tại
if [ ! -d "/home/project" ]; then
  echo "Directory /home/project does not exist. Creating it now."
  mkdir -p /home/project
fi

# Trích xuất dữ liệu từ MySQL vào file CSV
mysql -h "$MYSQL_HOST" -P 3306 -u "$MYSQL_USER" --password="$MYSQL_PASSWORD" --database="$MYSQL_DATABASE" --execute="SELECT * FROM sales_data WHERE timestamp >= NOW() - INTERVAL 4 HOUR" --batch --silent > "$SALES_CSV"

# Kiểm tra nếu file sales.csv đã được tạo
if [ ! -f "$SALES_CSV" ]; then
  echo "File $SALES_CSV was not created. Please check your MySQL query and paths."
  exit 1
fi

# Chuyển đổi tab thành dấu phẩy trong file CSV
tr '\t' ',' < "$SALES_CSV" > /home/project/temp_sales_commas.csv

# Kiểm tra nếu file tạm thời đã được tạo
if [ ! -f "/home/project/temp_sales_commas.csv" ]; then
  echo "Temporary file /home/project/temp_sales_commas.csv was not created. Please check your conversion command."
  exit 1
fi

mv /home/project/temp_sales_commas.csv "$SALES_CSV"

# Tải dữ liệu vào PostgreSQL
export PGPASSWORD="$POSTGRES_PASSWORD"
psql --username="$POSTGRES_USER" --host="$POSTGRES_HOST" --dbname="$POSTGRES_DB" -c "\COPY sales_data(rowid, product_id, customer_id, price, quantity, timestamp) FROM '$SALES_CSV' WITH (FORMAT csv, HEADER false, DELIMITER ',')"

# Xóa file CSV sau khi tải dữ liệu (bỏ dấu # nếu cần thiết)
# rm "$SALES_CSV"

# Tải dữ liệu vào bảng DimDate (Cập nhật với truy vấn cụ thể)
psql --username="$POSTGRES_USER" --host="$POSTGRES_HOST" --dbname="$POSTGRES_DB" -c "<replace with query used to populate the dimdate table>"

# Tải dữ liệu vào bảng FactSales (Cập nhật với truy vấn cụ thể)
psql --username="$POSTGRES_USER" --host="$POSTGRES_HOST" --dbname="$POSTGRES_DB" -c "<replace with query used to populate the FactSales table>"

# Xuất bảng DimDate ra file CSV
psql --username="$POSTGRES_USER" --host="$POSTGRES_HOST" --dbname="$POSTGRES_DB" -c "\COPY DimDate TO '/home/project/DimDate.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',')"

# Xuất bảng FactSales ra file CSV
psql --username="$POSTGRES_USER" --host="$POSTGRES_HOST" --dbname="$POSTGRES_DB" -c "\COPY FactSales TO '/home/project/FactSales.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',')"
