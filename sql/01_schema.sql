-- Drop tables if they exist 
DROP TABLE IF EXISTS returns;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    country VARCHAR(60)
);

CREATE TABLE products (
    stock_code VARCHAR(20) PRIMARY KEY,
    description VARCHAR(255)
);

CREATE TABLE orders (
    invoice_no VARCHAR(20) PRIMARY KEY,
    customer_id INT NOT NULL,
    invoice_date DATETIME NOT NULL,
    country VARCHAR(60),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    INDEX idx_orders_customer (customer_id),
    INDEX idx_orders_date (invoice_date)
);

CREATE TABLE order_items (
    item_id INT AUTO_INCREMENT PRIMARY KEY,
    invoice_no VARCHAR(20) NOT NULL,
    stock_code VARCHAR(20) NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    revenue DECIMAL(12,2) NOT NULL,
    FOREIGN KEY (invoice_no) REFERENCES orders(invoice_no),
    FOREIGN KEY (stock_code) REFERENCES products(stock_code),
    INDEX idx_items_stock (stock_code)
);

CREATE TABLE returns (
    return_id INT AUTO_INCREMENT PRIMARY KEY,
    invoice_no VARCHAR(20) NOT NULL,
    customer_id INT NOT NULL,
    stock_code VARCHAR(20) NOT NULL,
    invoice_date DATETIME NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    return_value DECIMAL(12,2) NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (stock_code) REFERENCES products(stock_code),
    INDEX idx_returns_customer (customer_id)
);