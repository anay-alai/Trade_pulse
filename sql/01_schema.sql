DROP DATABASE IF EXISTS trading_db;
CREATE DATABASE trading_db CHARACTER SET utf8mb4;
USE trading_db;

CREATE TABLE users (
  user_id INT AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(100) NOT NULL,
  email VARCHAR(120) NOT NULL UNIQUE,
  password_hash CHAR(64) NOT NULL,
  status ENUM('ACTIVE','SUSPENDED') NOT NULL DEFAULT 'ACTIVE',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE user_profiles (
  user_id INT PRIMARY KEY,
  pan_number CHAR(10) NOT NULL UNIQUE,
  kyc_status ENUM('PENDING','VERIFIED','REJECTED') NOT NULL DEFAULT 'PENDING',
  FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE wallets (
  wallet_id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL UNIQUE,
  available_balance DECIMAL(15,2) NOT NULL DEFAULT 0 CHECK (available_balance >= 0),
  locked_balance DECIMAL(15,2) NOT NULL DEFAULT 0 CHECK (locked_balance >= 0),
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE wallet_transactions (
  txn_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  wallet_id INT NOT NULL,
  amount DECIMAL(15,2) NOT NULL COMMENT 'signed: + credit, - debit',
  txn_type ENUM('DEPOSIT','WITHDRAWAL','STOCK_BUY','STOCK_SELL') NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_wt_wallet (wallet_id, created_at),
  FOREIGN KEY (wallet_id) REFERENCES wallets(wallet_id)
) ENGINE=InnoDB;

CREATE TABLE stocks (
  stock_id INT AUTO_INCREMENT PRIMARY KEY,
  ticker_symbol VARCHAR(15) NOT NULL UNIQUE,
  company_name VARCHAR(100) NOT NULL,
  exchange ENUM('NSE','BSE') NOT NULL DEFAULT 'NSE',
  current_price DECIMAL(12,2) NOT NULL CHECK (current_price > 0),
  is_tradable BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

CREATE TABLE stock_prices (
  price_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  stock_id INT NOT NULL,
  price DECIMAL(12,2) NOT NULL,
  volume BIGINT NOT NULL DEFAULT 0,
  recorded_at DATETIME NOT NULL,
  INDEX idx_price_time (stock_id, recorded_at),
  FOREIGN KEY (stock_id) REFERENCES stocks(stock_id)
) ENGINE=InnoDB;

CREATE TABLE orders (
  order_id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  stock_id INT NOT NULL,
  side ENUM('BUY','SELL') NOT NULL,
  order_type ENUM('MARKET','LIMIT') NOT NULL,
  limit_price DECIMAL(12,2) NULL,
  quantity INT NOT NULL CHECK (quantity > 0),
  filled_quantity INT NOT NULL DEFAULT 0,
  status ENUM('PENDING','FILLED','CANCELLED') NOT NULL DEFAULT 'PENDING',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (filled_quantity <= quantity),
  CHECK (order_type = 'MARKET' OR limit_price IS NOT NULL),
  INDEX idx_book (stock_id, status, side, limit_price, created_at),
  INDEX idx_user_orders (user_id, created_at),
  FOREIGN KEY (user_id) REFERENCES users(user_id),
  FOREIGN KEY (stock_id) REFERENCES stocks(stock_id)
) ENGINE=InnoDB;

CREATE TABLE order_executions (
  execution_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  order_id INT NOT NULL,
  executed_price DECIMAL(12,2) NOT NULL,
  executed_quantity INT NOT NULL,
  executed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (order_id) REFERENCES orders(order_id)
) ENGINE=InnoDB;

CREATE TABLE portfolio (
  user_id INT NOT NULL,
  stock_id INT NOT NULL,
  total_quantity INT NOT NULL DEFAULT 0 CHECK (total_quantity >= 0),
  locked_quantity INT NOT NULL DEFAULT 0 CHECK (locked_quantity >= 0),
  avg_buy_price DECIMAL(12,2) NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, stock_id),
  CHECK (locked_quantity <= total_quantity),
  FOREIGN KEY (user_id) REFERENCES users(user_id),
  FOREIGN KEY (stock_id) REFERENCES stocks(stock_id)
) ENGINE=InnoDB;

CREATE TABLE watchlists (
  watchlist_id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  name VARCHAR(50) NOT NULL,
  UNIQUE (user_id, name),
  FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE watchlist_items (
  watchlist_id INT NOT NULL,
  stock_id INT NOT NULL,
  PRIMARY KEY (watchlist_id, stock_id),
  FOREIGN KEY (watchlist_id) REFERENCES watchlists(watchlist_id) ON DELETE CASCADE,
  FOREIGN KEY (stock_id) REFERENCES stocks(stock_id)
) ENGINE=InnoDB;

CREATE TABLE audit_log (
  log_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  entity VARCHAR(30) NOT NULL,
  entity_id INT NOT NULL,
  action VARCHAR(30) NOT NULL,
  old_value VARCHAR(60),
  new_value VARCHAR(60),
  logged_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;
