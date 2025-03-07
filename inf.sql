
DROP DATABASE IF EXISTS POS;
CREATE DATABASE POS;
USE POS;

CREATE TABLE Product (
        id SERIAL PRIMARY KEY,
        name VARCHAR(128) NOT NULL,
        currentPrice DECIMAL(6,2),
        availableQuantity INTEGER
) ENGINE=InnoDB;

CREATE TABLE City (
        zip DECIMAL(5,0) ZEROFILL PRIMARY KEY,
        city VARCHAR(32) NOT NULL,
        state VARCHAR(4) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE Customer(
        id SERIAL PRIMARY KEY,
        firstName VARCHAR(32),
        lastName VARCHAR(30),
        email VARCHAR(128),
        address1 VARCHAR(100),
        address2 VARCHAR(50),
        phone VARCHAR(32),
        birthdate DATE,
        zip DECIMAL(5,0) ZEROFILL REFERENCES City(zip)
)ENGINE=InnoDB;

CREATE TABLE `Order` (
    id SERIAL PRIMARY KEY,
    datePlaced DATE,
    dateShipped DATE,  
    customer_id BIGINT UNSIGNED REFERENCES Customer(id)
) ENGINE=InnoDB;

CREATE TABLE Orderline (
    order_id BIGINT UNSIGNED REFERENCES `Order`(id),
    product_id BIGINT UNSIGNED REFERENCES Product(id),
    quantity INTEGER,  
    PRIMARY KEY(order_id, product_id)
) ENGINE=InnoDB;

CREATE TABLE PriceHistory (
    id SERIAL PRIMARY KEY,
    oldPrice DECIMAL(6,2),  
    newPrice DECIMAL(6,2),  
    ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    product_id BIGINT UNSIGNED REFERENCES Product(id)
) ENGINE=InnoDB;



