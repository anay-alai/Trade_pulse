CREATE DATABASE trading_platform;
USE trading_platform;

-- 1. users table
CREATE TABLE users (
    user_id       INT AUTO_INCREMENT PRIMARY KEY,
    full_name     VARCHAR(100) NOT NULL,
    email         VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. user profiles (1:1 with users)
CREATE TABLE user_profiles (
    profile_id    INT AUTO_INCREMENT PRIMARY KEY,
    user_id       INT NOT NULL UNIQUE,          
    pan_number    CHAR(10) UNIQUE,
    phone         VARCHAR(15),
    date_of_birth DATE,
    kyc_status    ENUM('PENDING','VERIFIED','REJECTED') DEFAULT 'PENDING',
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- 3. wallets  (1:1 with users)
CREATE TABLE wallets (
    wallet_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id   INT NOT NULL UNIQUE,                
    balance   DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    CHECK (balance >= 0),                        
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- 4) wallet transactions  (1:N from wallets)
CREATE TABLE wallet_transactions (
    transaction_id INT AUTO_INCREMENT PRIMARY KEY,
    wallet_id      INT NOT NULL,
    txn_type       ENUM('DEPOSIT','WITHDRAW','BUY','SELL') NOT NULL,
    amount         DECIMAL(15,2) NOT NULL,
    created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (amount > 0),
    FOREIGN KEY (wallet_id) REFERENCES wallets(wallet_id) ON DELETE CASCADE
);

-- 5. stocks
CREATE TABLE stocks (
    stock_id      INT AUTO_INCREMENT PRIMARY KEY,
    ticker_symbol VARCHAR(20)  NOT NULL UNIQUE,
    company_name  VARCHAR(100) NOT NULL,
    exchange      ENUM('NSE','BSE') NOT NULL DEFAULT 'NSE',
    current_price DECIMAL(12,2) NOT NULL,
    CHECK (current_price > 0)
);

-- 6. stock price history (1:N from stocks)
CREATE TABLE stock_price_history (
    history_id  INT AUTO_INCREMENT PRIMARY KEY,
    stock_id    INT NOT NULL,
    open_price  DECIMAL(12,2),
    high_price  DECIMAL(12,2),
    low_price   DECIMAL(12,2),
    close_price DECIMAL(12,2) NOT NULL,
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id) ON DELETE CASCADE
);

-- 7. orders  (users 1:N orders, stocks 1:N orders)
CREATE TABLE orders (
    order_id    INT AUTO_INCREMENT PRIMARY KEY,
    user_id     INT NOT NULL,
    stock_id    INT NOT NULL,
    side        ENUM('BUY','SELL') NOT NULL,
    order_type  ENUM('MARKET','LIMIT') NOT NULL DEFAULT 'MARKET',
    limit_price DECIMAL(12,2) NULL,                 -- only for LIMIT orders
    quantity    INT NOT NULL,
    status      ENUM('PENDING','EXECUTED','CANCELLED') NOT NULL DEFAULT 'PENDING',
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (quantity > 0),
    CHECK ((order_type = 'LIMIT'  AND limit_price > 0) OR
           (order_type = 'MARKET' AND limit_price IS NULL)),
    FOREIGN KEY (user_id)  REFERENCES users(user_id)   ON DELETE CASCADE,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id)
);

-- 8. order_executions  (1:N from orders)
CREATE TABLE order_executions (
    execution_id   INT AUTO_INCREMENT PRIMARY KEY,
    order_id       INT NOT NULL,
    exec_price     DECIMAL(12,2) NOT NULL,
    exec_quantity  INT NOT NULL,
    executed_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (exec_price > 0 AND exec_quantity > 0),
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE
);

-- 9. portfolio  (users N:M stocks, composite PK) 
CREATE TABLE portfolio (
    user_id       INT NOT NULL,
    stock_id      INT NOT NULL,
    quantity      INT NOT NULL DEFAULT 0,
    avg_buy_price DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    PRIMARY KEY (user_id, stock_id),
    CHECK (quantity >= 0),
    FOREIGN KEY (user_id)  REFERENCES users(user_id)   ON DELETE CASCADE,
    FOREIGN KEY (stock_id) REFERENCES stocks(stock_id) ON DELETE CASCADE
);

-- Helpful indexes (foreign keys already get one automatically)
CREATE INDEX idx_price_stock_time ON stock_price_history (stock_id, recorded_at);
CREATE INDEX idx_orders_user_time ON orders (user_id, created_at);

