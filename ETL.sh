#!/bin/sh

# Define variables
MYSQL_HOST='172.21.116.119'
MYSQL_USER='root'
MYSQL_PASSWORD='U4VpcRdo8nCajs7O6Fs4sPB6'
MYSQL_DATABASE='sales'
POSTGRES_HOST='172.21.112.141'
POSTGRES_USER='postgres'
POSTGRES_PASSWORD='eYFfL7KsKcfZ0MGeRKjZuiPp'
POSTGRES_DB='sales_new'
SALES_CSV='/home/project/sales.csv'

# Set PostgreSQL password environment variable
export PGPASSWORD=$POSTGRES_PASSWORD

# Create tables in PostgreSQL
psql --username=$POSTGRES_USER --host=$POSTGRES_HOST --dbname=$POSTGRES_DB <<EOF
DROP TABLE IF EXISTS DimDate;
CREATE TABLE DimDate (
    dateid INTEGER PRIMARY KEY,
    date_value DATE,
    year INTEGER,
    quarter INTEGER,
    month INTEGER,
    day_of_week INTEGER,
    day_of_month INTEGER
);

DROP TABLE IF EXISTS FactSales;
CREATE TABLE FactSales (
    rowid INTEGER PRIMARY KEY,
    product_id INTEGER,
    customer_id INTEGER,
    price NUMERIC(10, 2),
    quantity INTEGER,
    sale_date DATE
);
EOF

# Export data from MySQL to CSV
mysql -h $MYSQL_HOST -u $MYSQL_USER --password=$MYSQL_PASSWORD --database=$MYSQL_DATABASE --execute="SELECT rowid, product_id, customer_id, price, quantity, timestamp FROM sales_data WHERE timestamp >= NOW() - INTERVAL 4 HOUR" --batch --silent > $SALES_CSV

# Replace tabs with commas
tr '\t' ',' < $SALES_CSV > /home/project/temp_sales_commas.csv

# Move the temporary file to the final CSV file
mv /home/project/temp_sales_commas.csv $SALES_CSV

# Load data into FactSales table
psql --username=$POSTGRES_USER --host=$POSTGRES_HOST --dbname=$POSTGRES_DB -c "\COPY FactSales(rowid, product_id, customer_id, price, quantity, sale_date) FROM '$SALES_CSV' DELIMITER ',' CSV HEADER;"

# Load data into DimDate table
psql --username=$POSTGRES_USER --host=$POSTGRES_HOST --dbname=$POSTGRES_DB -c "
INSERT INTO DimDate (dateid, date_value, year, quarter, month, day_of_week, day_of_month)
SELECT DISTINCT
    EXTRACT(EPOCH FROM sale_date) / 86400 AS dateid,
    sale_date AS date_value,
    EXTRACT(YEAR FROM sale_date) AS year,
    EXTRACT(QUARTER FROM sale_date) AS quarter,
    EXTRACT(MONTH FROM sale_date) AS month,
    EXTRACT(DOW FROM sale_date) AS day_of_week,
    EXTRACT(DAY FROM sale_date) AS day_of_month
FROM FactSales;"

# Export data from DimDate and FactSales tables to CSV
psql --username=$POSTGRES_USER --host=$POSTGRES_HOST --dbname=$POSTGRES_DB -c "\COPY DimDate TO '/home/project/dimdate.csv' DELIMITER ',' CSV HEADER;"
psql --username=$POSTGRES_USER --host=$POSTGRES_HOST --dbname=$POSTGRES_DB -c "\COPY FactSales TO '/home/project/factsales.csv' DELIMITER ',' CSV HEADER;"



echo "ETL process completed successfully."
