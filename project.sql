-- ============================================================
-- STOCK TRADING PLATFORM — RELATIONAL SCHEMA
-- Derived from the enhanced ER design (Chen notation version)
-- Target DBMS: MySQL 8.0+
-- ============================================================

CREATE DATABASE IF NOT EXISTS trading_platform
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE trading_platform;

-- ------------------------------------------------------------
-- 1. USERS  (core identity entity)
-- ------------------------------------------------------------
CREATE TABLE users (
    user_id        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    full_name      VARCHAR(100) NOT NULL,
    email          VARCHAR(255) NOT NULL,
    phone          VARCHAR(15),
    password_hash  VARCHAR(255) NOT NULL,
    account_status ENUM('PENDING_KYC','ACTIVE','SUSPENDED','CLOSED')
                   NOT NULL DEFAULT 'PENDING_KYC',
    created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                   ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_users_email (email),
    UNIQUE KEY uq_users_phone (phone)
);

-- ------------------------------------------------------------
-- 2. USER_PROFILES  (1:1 with USERS — [OWNS_PROFILE])
-- ------------------------------------------------------------
CREATE TABLE user_profiles (
    profile_id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id         INT UNSIGNED NOT NULL,
    pan_number      CHAR(10),              -- Indian PAN is exactly 10 chars
    date_of_birth   DATE,
    address_line    VARCHAR(255),
    city            VARCHAR(50),
    state           VARCHAR(50),
    pincode         CHAR(6),
    bank_account_no VARCHAR(20),
    ifsc_code       CHAR(11),
    kyc_status      ENUM('PENDING','VERIFIED','REJECTED')
                    NOT NULL DEFAULT 'PENDING',
    kyc_verified_at DATETIME NULL,
    UNIQUE KEY uq_profile_user (user_id),          -- enforces the 1:1
    UNIQUE KEY uq_profile_pan (pan_number),
    CONSTRAINT fk_profile_user FOREIGN KEY (user_id)
        REFERENCES users(user_id) ON DELETE CASCADE
);

-- ------------------------------------------------------------
-- 3. WALLETS  (1:1 with USERS — [OWNS_WALLET])
--    locked_balance = funds reserved for pending BUY limit orders
-- ------------------------------------------------------------
CREATE TABLE wallets (
    wallet_id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id           INT UNSIGNED NOT NULL,
    available_balance DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    locked_balance    DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    currency          CHAR(3) NOT NULL DEFAULT 'INR',
    updated_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                      ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_wallet_user (user_id),           -- enforces the 1:1
    CONSTRAINT chk_wallet_available CHECK (available_balance >= 0),
    CONSTRAINT chk_wallet_locked    CHECK (locked_balance >= 0),
    CONSTRAINT fk_wallet_user FOREIGN KEY (user_id)
        REFERENCES users(user_id) ON DELETE CASCADE
);

-- ------------------------------------------------------------
-- 4. STOCKS  (static metadata, separated from live price ticks)
-- ------------------------------------------------------------
CREATE TABLE stocks (
    stock_id       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    ticker_symbol  VARCHAR(20) NOT NULL,
    company_name   VARCHAR(100) NOT NULL,
    exchange       ENUM('NSE','BSE','NASDAQ','NYSE') NOT NULL DEFAULT 'NSE',
    current_price  DECIMAL(12,2) NOT NULL,
    is_tradable    BOOLEAN NOT NULL DEFAULT TRUE,
    last_updated   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                   ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_stock_symbol (ticker_symbol),
    CONSTRAINT chk_stock_price CHECK (current_price > 0)
);

-- ------------------------------------------------------------
-- 5. STOCK_PRICE_HISTORY  (1:N with STOCKS — [TRACKS_HISTORY])
--    OHLCV data for charts / backtesting
-- ------------------------------------------------------------
CREATE TABLE stock_price_history (
    history_id   BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    stock_id     INT UNSIGNED NOT NULL,
    open_price   DECIMAL(12,2),
    high_price   DECIMAL(12,2),
    low_price    DECIMAL(12,2),
    close_price  DECIMAL(12,2) NOT NULL,
    volume       BIGINT UNSIGNED NOT NULL DEFAULT 0,
    recorded_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_price_stock_time (stock_id, recorded_at),
    CONSTRAINT fk_price_stock FOREIGN KEY (stock_id)
        REFERENCES stocks(stock_id) ON DELETE CASCADE
);

-- ------------------------------------------------------------
-- 6. ORDERS  (1:N from USERS — [PLACES_ORDER],
--             1:N from STOCKS — [TARGETS_STOCK])
-- ------------------------------------------------------------
CREATE TABLE orders (
    order_id        BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id         INT UNSIGNED NOT NULL,
    stock_id        INT UNSIGNED NOT NULL,
    side            ENUM('BUY','SELL') NOT NULL,
    order_type      ENUM('MARKET','LIMIT') NOT NULL,
    limit_price     DECIMAL(12,2) NULL,     -- NULL for market orders
    quantity        INT UNSIGNED NOT NULL,
    filled_quantity INT UNSIGNED NOT NULL DEFAULT 0,
    status          ENUM('PENDING','PARTIALLY_FILLED','FILLED',
                         'CANCELLED','REJECTED')
                    NOT NULL DEFAULT 'PENDING',
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP,
    KEY idx_orders_user (user_id, created_at),      -- order history lookups
    KEY idx_orders_match (stock_id, status, side),  -- matching engine lookups
    CONSTRAINT chk_order_qty    CHECK (quantity > 0),
    CONSTRAINT chk_order_limit  CHECK (
        (order_type = 'LIMIT'  AND limit_price > 0) OR
        (order_type = 'MARKET' AND limit_price IS NULL)
    ),
    CONSTRAINT chk_order_filled CHECK (filled_quantity <= quantity),
    CONSTRAINT fk_order_user  FOREIGN KEY (user_id)
        REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_order_stock FOREIGN KEY (stock_id)
        REFERENCES stocks(stock_id)
);

-- ------------------------------------------------------------
-- 7. ORDER_EXECUTIONS  (1:N with ORDERS — [EXECUTES_AS])
--    Immutable audit log; handles partial fills
-- ------------------------------------------------------------
CREATE TABLE order_executions (
    execution_id      BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_id          BIGINT UNSIGNED NOT NULL,
    executed_price    DECIMAL(12,2) NOT NULL,
    executed_quantity INT UNSIGNED NOT NULL,
    executed_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_exec_order (order_id),
    CONSTRAINT chk_exec CHECK (executed_price > 0 AND executed_quantity > 0),
    CONSTRAINT fk_exec_order FOREIGN KEY (order_id)
        REFERENCES orders(order_id) ON DELETE CASCADE
);

-- ------------------------------------------------------------
-- 8. PORTFOLIO  (associative entity: USERS N:M STOCKS)
--    locked_quantity = shares reserved for pending SELL limit orders
-- ------------------------------------------------------------
CREATE TABLE portfolio (
    user_id         INT UNSIGNED NOT NULL,
    stock_id        INT UNSIGNED NOT NULL,
    total_quantity  INT UNSIGNED NOT NULL DEFAULT 0,
    locked_quantity INT UNSIGNED NOT NULL DEFAULT 0,
    avg_buy_price   DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, stock_id),
    KEY idx_portfolio_stock (stock_id),     -- "who holds stock X" queries
    CONSTRAINT chk_pf_qty    CHECK (total_quantity >= 0),
    CONSTRAINT chk_pf_locked CHECK (locked_quantity <= total_quantity),
    CONSTRAINT fk_pf_user  FOREIGN KEY (user_id)
        REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_pf_stock FOREIGN KEY (stock_id)
        REFERENCES stocks(stock_id) ON DELETE CASCADE
);

-- ------------------------------------------------------------
-- 9. WATCHLISTS  (1:N from USERS — [HAS_WATCHLIST])
-- ------------------------------------------------------------
CREATE TABLE watchlists (
    watchlist_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id      INT UNSIGNED NOT NULL,
    name         VARCHAR(50) NOT NULL,
    created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_user_watchlist_name (user_id, name),
    CONSTRAINT fk_wl_user FOREIGN KEY (user_id)
        REFERENCES users(user_id) ON DELETE CASCADE
);

-- ------------------------------------------------------------
-- 10. WATCHLIST_ITEMS  (associative entity: WATCHLISTS N:M STOCKS)
-- ------------------------------------------------------------
CREATE TABLE watchlist_items (
    watchlist_id INT UNSIGNED NOT NULL,
    stock_id     INT UNSIGNED NOT NULL,
    added_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (watchlist_id, stock_id),
    CONSTRAINT fk_wi_list  FOREIGN KEY (watchlist_id)
        REFERENCES watchlists(watchlist_id) ON DELETE CASCADE,
    CONSTRAINT fk_wi_stock FOREIGN KEY (stock_id)
        REFERENCES stocks(stock_id) ON DELETE CASCADE
);

-- ------------------------------------------------------------
-- 11. WALLET_TRANSACTIONS  (1:N from WALLETS — [LOGS_TRANS])
--     Ledger. amount: + = credit, - = debit
--     (ORDER_LOCK / ORDER_UNLOCK added to support locked_balance)
-- ------------------------------------------------------------
CREATE TABLE wallet_transactions (
    transaction_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    wallet_id      INT UNSIGNED NOT NULL,
    txn_type       ENUM('DEPOSIT','WITHDRAWAL','ORDER_LOCK',
                        'ORDER_UNLOCK','STOCK_BUY','STOCK_SELL') NOT NULL,
    amount         DECIMAL(15,2) NOT NULL,
    balance_after  DECIMAL(15,2) NULL,      -- audit snapshot
    order_id       BIGINT UNSIGNED NULL,    -- link to order, if any
    description    VARCHAR(255),
    created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_txn_wallet_time (wallet_id, created_at),
    CONSTRAINT chk_txn_amount CHECK (amount <> 0),
    CONSTRAINT fk_txn_wallet FOREIGN KEY (wallet_id)
        REFERENCES wallets(wallet_id) ON DELETE CASCADE,
    CONSTRAINT fk_txn_order  FOREIGN KEY (order_id)
        REFERENCES orders(order_id) ON DELETE SET NULL
);