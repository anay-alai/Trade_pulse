-- sample data for trading platform
USE trading_platform;

-- 1. users 
INSERT INTO users (user_id, full_name, email, password_hash, created_at) VALUES
(1, 'Aarav Sharma',    'aarav.sharma@example.com',    'hash_aarav_x91',  '2026-10-01 09:00:00'),
(2, 'Priya Patil',     'priya.patil@example.com',     'hash_priya_k42',  '2026-10-01 10:15:00'),
(3, 'Rohan Deshmukh',  'rohan.deshmukh@example.com',  'hash_rohan_m77',  '2026-10-02 11:30:00'),
(4, 'Sneha Kulkarni',  'sneha.kulkarni@example.com',  'hash_sneha_q18',  '2026-10-03 14:00:00'),
(5, 'Vikram Joshi',    'vikram.joshi@example.com',    'hash_vikram_z05', '2026-10-05 16:45:00');

-- 2. user_profiles (user 5 is still pending KYC)
INSERT INTO user_profiles (user_id, pan_number, phone, date_of_birth, kyc_status) VALUES
(1, 'ABCPS1234A', '9876500001', '1999-03-14', 'VERIFIED'),
(2, 'BCDPP2345B', '9876500002', '2000-07-21', 'VERIFIED'),
(3, 'CDEPD3456C', '9876500003', '1998-11-05', 'VERIFIED'),
(4, 'DEFPK4567D', '9876500004', '2001-01-30', 'VERIFIED'),
(5, 'EFGPJ5678E', '9876500005', '1997-09-09', 'PENDING');

-- 3. wallets (balances => result after all transactions below)
INSERT INTO wallets (wallet_id, user_id, balance) VALUES
(1, 1, 423540.00),
(2, 2, 179000.00),
(3, 3,  30000.00),
(4, 4,  33000.00),
(5, 5,      0.00);

-- 4. stocks 
INSERT INTO stocks (stock_id, ticker_symbol, company_name, exchange, current_price) VALUES
(1, 'RELIANCE',  'Reliance Industries Ltd', 'NSE', 2900.00),
(2, 'TCS',       'Tata Consultancy Services', 'NSE', 4100.00),
(3, 'INFY',      'Infosys Ltd',             'NSE', 1850.00),
(4, 'HDFCBANK',  'HDFC Bank Ltd',           'NSE', 1650.00),
(5, 'ICICIBANK', 'ICICI Bank Ltd',          'NSE', 1200.00),
(6, 'SBIN',      'State Bank of India',     'NSE',  820.00),
(7, 'ITC',       'ITC Ltd',                 'BSE',  470.00),
(8, 'WIPRO',     'Wipro Ltd',               'NSE',  540.00);

-- 5. stock_price_history 
-- friday's close equals current_price in the stocks table.
INSERT INTO stock_price_history (stock_id, open_price, high_price, low_price, close_price, recorded_at) VALUES
-- RELIANCE
(1, 2820.00, 2860.00, 2800.00, 2850.00, '2026-10-12 15:30:00'),
(1, 2850.00, 2880.00, 2830.00, 2870.00, '2026-10-13 15:30:00'),
(1, 2870.00, 2890.00, 2840.00, 2845.00, '2026-10-14 15:30:00'),
(1, 2845.00, 2910.00, 2840.00, 2895.00, '2026-10-15 15:30:00'),
(1, 2895.00, 2920.00, 2880.00, 2900.00, '2026-10-16 15:30:00'),
-- TCS
(2, 3980.00, 4040.00, 3960.00, 4000.00, '2026-10-12 15:30:00'),
(2, 4000.00, 4060.00, 3990.00, 4050.00, '2026-10-13 15:30:00'),
(2, 4050.00, 4080.00, 4030.00, 4040.00, '2026-10-14 15:30:00'),
(2, 4040.00, 4110.00, 4035.00, 4090.00, '2026-10-15 15:30:00'),
(2, 4090.00, 4120.00, 4070.00, 4100.00, '2026-10-16 15:30:00'),
-- INFY
(3, 1790.00, 1815.00, 1780.00, 1800.00, '2026-10-12 15:30:00'),
(3, 1800.00, 1830.00, 1795.00, 1825.00, '2026-10-13 15:30:00'),
(3, 1825.00, 1840.00, 1810.00, 1815.00, '2026-10-14 15:30:00'),
(3, 1815.00, 1860.00, 1810.00, 1850.00, '2026-10-15 15:30:00'),
(3, 1850.00, 1865.00, 1840.00, 1850.00, '2026-10-16 15:30:00'),
-- SBIN
(6, 795.00, 810.00, 790.00, 800.00, '2026-10-12 15:30:00'),
(6, 800.00, 815.00, 798.00, 812.00, '2026-10-13 15:30:00'),
(6, 812.00, 818.00, 805.00, 808.00, '2026-10-14 15:30:00'),
(6, 808.00, 825.00, 806.00, 818.00, '2026-10-15 15:30:00'),
(6, 818.00, 826.00, 815.00, 820.00, '2026-10-16 15:30:00');

-- 6. orders
-- mix of MARKET/LIMIT, BUY/SELL and PENDING/EXECUTED/CANCELLED
INSERT INTO orders (order_id, user_id, stock_id, side, order_type, limit_price, quantity, status, created_at) VALUES
( 1, 1, 1, 'BUY',  'MARKET', NULL,    10, 'EXECUTED',  '2026-10-12 10:00:00'),
( 2, 1, 2, 'BUY',  'MARKET', NULL,     5, 'EXECUTED',  '2026-10-12 10:30:00'),
( 3, 1, 1, 'BUY',  'LIMIT',  2800.00, 10, 'EXECUTED',  '2026-10-13 11:00:00'),
( 4, 1, 3, 'BUY',  'LIMIT',  1800.00, 10, 'PENDING',   '2026-10-16 09:20:00'),
( 5, 1, 6, 'BUY',  'LIMIT',   780.00, 50, 'CANCELLED', '2026-10-14 12:00:00'),
( 6, 2, 3, 'BUY',  'MARKET', NULL,    50, 'EXECUTED',  '2026-10-12 10:10:00'),
( 7, 2, 4, 'BUY',  'MARKET', NULL,    30, 'EXECUTED',  '2026-10-13 10:45:00'),
( 8, 2, 3, 'SELL', 'LIMIT',  1850.00, 20, 'EXECUTED',  '2026-10-15 13:00:00'),
( 9, 3, 6, 'BUY',  'MARKET', NULL,   100, 'EXECUTED',  '2026-10-12 11:15:00'),
(10, 3, 7, 'BUY',  'MARKET', NULL,   200, 'EXECUTED',  '2026-10-13 12:30:00'),
(11, 3, 8, 'BUY',  'LIMIT',   520.00, 40, 'PENDING',   '2026-10-16 10:05:00'),
(12, 4, 2, 'BUY',  'MARKET', NULL,    10, 'EXECUTED',  '2026-10-13 14:10:00'),
(13, 4, 8, 'BUY',  'MARKET', NULL,    50, 'EXECUTED',  '2026-10-14 14:40:00');

-- 7. order_executions (order 3 is filled in two parts)
INSERT INTO order_executions (order_id, exec_price, exec_quantity, executed_at) VALUES
( 1, 2850.00, 10, '2026-10-12 10:00:05'),
( 2, 4000.00,  5, '2026-10-12 10:30:05'),
( 3, 2790.00,  4, '2026-10-13 11:00:10'),
( 3, 2800.00,  6, '2026-10-13 11:02:30'),
( 6, 1800.00, 50, '2026-10-12 10:10:05'),
( 7, 1600.00, 30, '2026-10-13 10:45:05'),
( 8, 1850.00, 20, '2026-10-15 13:00:20'),
( 9,  800.00, 100,'2026-10-12 11:15:05'),
(10,  450.00, 200,'2026-10-13 12:30:05'),
(12, 4050.00, 10, '2026-10-13 14:10:05'),
(13,  530.00, 50, '2026-10-14 14:40:05');

-- 8. portfolio (holdings after all executed orders)
-- user 1 RELIANCE => (10x2850 + 4x2790 + 6x2800) / 20 = 2823.00
-- user 2 INFY => bought 50, sold 20 -> 30 left
-- stock 5 (ICICIBANK) has no holders on purpose
INSERT INTO portfolio (user_id, stock_id, quantity, avg_buy_price) VALUES
(1, 1,  20, 2823.00),
(1, 2,   5, 4000.00),
(2, 3,  30, 1800.00),
(2, 4,  30, 1600.00),
(3, 6, 100,  800.00),
(3, 7, 200,  450.00),
(4, 2,  10, 4050.00),
(4, 8,  50,  530.00);

-- 9. wallet_transactions (ledger; amount is always positive, txn_type tells the direction)
INSERT INTO wallet_transactions (wallet_id, txn_type, amount, created_at) VALUES
-- user 1: 500000 - 28500 - 20000 - 27960 = 423540
(1, 'DEPOSIT', 500000.00, '2026-10-01 09:30:00'),
(1, 'BUY',      28500.00, '2026-10-12 10:00:05'),
(1, 'BUY',      20000.00, '2026-10-12 10:30:05'),
(1, 'BUY',      27960.00, '2026-10-13 11:02:30'),
-- user 2: 300000 - 90000 - 48000 + 37000 - 20000 = 179000
(2, 'DEPOSIT',  300000.00, '2026-10-01 10:30:00'),
(2, 'BUY',       90000.00, '2026-10-12 10:10:05'),
(2, 'BUY',       48000.00, '2026-10-13 10:45:05'),
(2, 'SELL',      37000.00, '2026-10-15 13:00:20'),
(2, 'WITHDRAW',  20000.00, '2026-10-16 17:00:00'),
-- user 3: 200000 - 80000 - 90000 = 30000
(3, 'DEPOSIT',  200000.00, '2026-10-02 12:00:00'),
(3, 'BUY',       80000.00, '2026-10-12 11:15:05'),
(3, 'BUY',       90000.00, '2026-10-13 12:30:05'),
-- user 4: 100000 - 40500 - 26500 = 33000
(4, 'DEPOSIT',  100000.00, '2026-10-03 14:30:00'),
(4, 'BUY',       40500.00, '2026-10-13 14:10:05'),
(4, 'BUY',       26500.00, '2026-10-14 14:40:05');
-- user 5 (pending KYC): no transactions, balance 0

-- sanity checks
-- row counts: users 5, profiles 5, wallets 5, stocks 8, history 20,
-- orders 13, executions 11, portfolio 8, wallet_transactions 15
SELECT 'users' AS tbl, COUNT(*) AS rows_cnt FROM users
UNION ALL SELECT 'user_profiles', COUNT(*) FROM user_profiles
UNION ALL SELECT 'wallets', COUNT(*) FROM wallets
UNION ALL SELECT 'stocks', COUNT(*) FROM stocks
UNION ALL SELECT 'stock_price_history', COUNT(*) FROM stock_price_history
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_executions', COUNT(*) FROM order_executions
UNION ALL SELECT 'portfolio', COUNT(*) FROM portfolio
UNION ALL SELECT 'wallet_transactions', COUNT(*) FROM wallet_transactions;

-- Ledger check: computed balance must equal wallets.balance
SELECT w.wallet_id, w.balance AS stored_balance,
       COALESCE(SUM(CASE WHEN t.txn_type IN ('DEPOSIT','SELL') THEN t.amount
                         ELSE -t.amount END), 0) AS ledger_balance
FROM wallets w
LEFT JOIN wallet_transactions t ON t.wallet_id = w.wallet_id
GROUP BY w.wallet_id, w.balance;
