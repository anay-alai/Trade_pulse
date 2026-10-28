USE trading_db;

CREATE OR REPLACE VIEW v_holdings AS
SELECT p.user_id, s.stock_id, s.ticker_symbol, s.company_name,
       p.total_quantity, p.locked_quantity, p.avg_buy_price, s.current_price,
       ROUND(p.total_quantity * p.avg_buy_price, 2)  AS invested,
       ROUND(p.total_quantity * s.current_price, 2)  AS current_value,
       ROUND(p.total_quantity * (s.current_price - p.avg_buy_price), 2) AS pnl,
       ROUND((s.current_price - p.avg_buy_price) / p.avg_buy_price * 100, 2) AS pnl_pct
FROM portfolio p JOIN stocks s USING (stock_id);

CREATE OR REPLACE VIEW v_order_book AS
SELECT o.order_id, s.ticker_symbol, o.side, o.limit_price, o.quantity, u.full_name, o.created_at
FROM orders o JOIN stocks s USING (stock_id) JOIN users u USING (user_id)
WHERE o.status = 'PENDING';

CREATE OR REPLACE VIEW v_net_worth AS
SELECT u.user_id, u.full_name,
       w.available_balance + w.locked_balance AS cash,
       COALESCE((SELECT SUM(h.current_value) FROM v_holdings h WHERE h.user_id = u.user_id), 0) AS holdings
FROM users u JOIN wallets w USING (user_id);

-- ---- Example analytical queries (also used by the web app) ----
-- Net worth leaderboard (window RANK):
--   SELECT full_name, cash + holdings AS net_worth, RANK() OVER (ORDER BY cash + holdings DESC) AS position FROM v_net_worth;
-- 5-day moving average (window AVG):
--   SELECT recorded_at, price, AVG(price) OVER (ORDER BY recorded_at ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) AS ma5
--   FROM stock_prices WHERE stock_id = 1;
-- Running wallet total (window SUM):
--   SELECT txn_id, amount, SUM(amount) OVER (ORDER BY txn_id) AS running FROM wallet_transactions WHERE wallet_id = 1;
-- Index check:
--   EXPLAIN SELECT * FROM orders WHERE stock_id = 1 AND status = 'PENDING' AND side = 'BUY' ORDER BY limit_price DESC, created_at;
