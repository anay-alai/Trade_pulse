-- ============================================================
-- DEMO SCRIPT (run after 02_sample_data.sql and 04_procedures.sql)
-- Run it block by block while presenting.
-- User ids: 1 Aarav, 2 Priya, 3 Rohan, 4 Sneha, 5 Vikram
-- Stock ids: 1 RELIANCE, 2 TCS, 3 INFY, 4 HDFCBANK, 5 ICICIBANK,
--            6 SBIN, 7 ITC, 8 WIPRO
-- ============================================================
USE trading_platform;

-- ------------------------------------------------------------
-- BLOCK 1: BEFORE  (Rohan: balance 30000, holds SBIN 100 + ITC 200)
-- ------------------------------------------------------------
SELECT balance FROM wallets WHERE user_id = 3;
SELECT stock_id, quantity, avg_buy_price FROM portfolio WHERE user_id = 3;

-- ------------------------------------------------------------
-- BLOCK 2: SUCCESSFUL BUY - new stock (Rohan buys 10 WIPRO @ 540 = 5400)
-- Expect: balance 24600, new portfolio row for WIPRO
-- ------------------------------------------------------------
CALL place_buy_order(3, 8, 10);

-- ------------------------------------------------------------
-- BLOCK 3: SUCCESSFUL BUY - stock already held (10 more SBIN @ 820 = 8200)
-- Expect: balance 16400, SBIN quantity 110, avg price recalculated (801.82)
-- ------------------------------------------------------------
CALL place_buy_order(3, 6, 10);

SELECT balance FROM wallets WHERE user_id = 3;
SELECT stock_id, quantity, avg_buy_price FROM portfolio WHERE user_id = 3;

-- ------------------------------------------------------------
-- BLOCK 4: FAILED BUYS (nothing should change - rollback / no changes)
-- ------------------------------------------------------------
-- 4a. Insufficient balance: Sneha (33000) tries 100 RELIANCE = 290000
CALL place_buy_order(4, 1, 100);

-- 4b. KYC not verified: Vikram tries to buy
CALL place_buy_order(5, 1, 1);

-- Proof that nothing changed for Sneha: balance still 33000, no new order
SELECT balance FROM wallets WHERE user_id = 4;
SELECT COUNT(*) AS sneha_orders FROM orders WHERE user_id = 4;   -- still 2

-- ------------------------------------------------------------
-- BLOCK 5: SUCCESSFUL SELL (Priya sells 10 of her 30 INFY @ 1850 = 18500)
-- Expect: balance 197500, INFY quantity 20
-- ------------------------------------------------------------
SELECT balance FROM wallets WHERE user_id = 2;
CALL place_sell_order(2, 3, 10);
SELECT balance FROM wallets WHERE user_id = 2;
SELECT stock_id, quantity FROM portfolio WHERE user_id = 2 AND stock_id = 3;

-- ------------------------------------------------------------
-- BLOCK 6: FAILED SELL (Aarav owns only 5 TCS, tries to sell 50)
-- ------------------------------------------------------------
CALL place_sell_order(1, 2, 50);

-- ------------------------------------------------------------
-- BLOCK 7: AFTER - view the records the procedures created
-- ------------------------------------------------------------
-- New orders and executions (order ids 14 onwards)
SELECT o.order_id, o.user_id, o.stock_id, o.side, o.quantity, o.status,
       e.exec_price, e.exec_quantity
FROM orders o
JOIN order_executions e ON e.order_id = o.order_id
WHERE o.order_id > 13;

-- Wallet ledger entries created by the procedures
SELECT * FROM wallet_transactions WHERE transaction_id > 15;

-- ------------------------------------------------------------
-- BLOCK 8: CONSISTENCY CHECK - ledger must still match every wallet
-- (stored_balance and ledger_balance should be equal in every row)
-- ------------------------------------------------------------
SELECT w.wallet_id, w.balance AS stored_balance,
       COALESCE(SUM(CASE WHEN t.txn_type IN ('DEPOSIT','SELL') THEN t.amount
                         ELSE -t.amount END), 0) AS ledger_balance
FROM wallets w
LEFT JOIN wallet_transactions t ON t.wallet_id = w.wallet_id
GROUP BY w.wallet_id, w.balance;
