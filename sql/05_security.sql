USE trading_db;
CREATE ROLE IF NOT EXISTS 'trader_role', 'analyst_role', 'admin_role';

-- Trader role: can view market data, personal portfolio, orders, wallet, and execute trading procedures
GRANT SELECT ON trading_db.stocks             TO 'trader_role';
GRANT SELECT ON trading_db.stock_prices        TO 'trader_role';
GRANT SELECT ON trading_db.wallets            TO 'trader_role';
GRANT SELECT ON trading_db.wallet_transactions TO 'trader_role';
GRANT SELECT ON trading_db.orders             TO 'trader_role';
GRANT SELECT ON trading_db.order_executions   TO 'trader_role';
GRANT SELECT ON trading_db.portfolio          TO 'trader_role';
GRANT SELECT ON trading_db.users              TO 'trader_role';
GRANT SELECT ON trading_db.v_holdings         TO 'trader_role';
GRANT SELECT ON trading_db.v_order_book       TO 'trader_role';
GRANT SELECT ON trading_db.v_net_worth        TO 'trader_role';

GRANT EXECUTE ON PROCEDURE trading_db.sp_deposit      TO 'trader_role';
GRANT EXECUTE ON PROCEDURE trading_db.sp_withdraw     TO 'trader_role';
GRANT EXECUTE ON PROCEDURE trading_db.sp_place_order  TO 'trader_role';
GRANT EXECUTE ON PROCEDURE trading_db.sp_cancel_order TO 'trader_role';

-- Analyst role: read-only access to all database tables and views
GRANT SELECT ON trading_db.* TO 'analyst_role';

-- Admin role: full control
GRANT ALL ON trading_db.* TO 'admin_role';

-- Example: CREATE USER 'app'@'localhost' IDENTIFIED BY 'app_pw';
--          GRANT 'admin_role' TO 'app'@'localhost'; SET DEFAULT ROLE ALL TO 'app'@'localhost';
