USE trading_db;

INSERT INTO users (full_name, email, password_hash) VALUES
 ('Aarav Sharma','aarav@example.com',SHA2('password',256)),
 ('Diya Patil','diya@example.com',SHA2('password',256)),
 ('Kabir Mehta','kabir@example.com',SHA2('password',256)),
 ('Meera Iyer','meera@example.com',SHA2('password',256)),
 ('Rohan Desai','rohan@example.com',SHA2('password',256));

INSERT INTO user_profiles (user_id, pan_number, kyc_status) VALUES
 (1,'ABCDE1234F','VERIFIED'),(2,'BCDEF2345G','VERIFIED'),(3,'CDEFG3456H','VERIFIED'),
 (4,'DEFGH4567J','VERIFIED'),(5,'EFGHI5678K','PENDING');

INSERT INTO wallets (user_id, available_balance) VALUES
 (1,500000),(2,250000),(3,150000),(4,300000),(5,100000);
INSERT INTO wallet_transactions (wallet_id, amount, txn_type)
 SELECT wallet_id, available_balance, 'DEPOSIT' FROM wallets;

INSERT INTO stocks (ticker_symbol, company_name, exchange, current_price) VALUES
 ('RELIANCE','Reliance Industries','NSE',2450.00),('TCS','Tata Consultancy Services','NSE',3600.00),
 ('INFY','Infosys','NSE',1500.00),('HDFCBANK','HDFC Bank','NSE',1650.00),
 ('ITC','ITC Limited','NSE',430.00),('SBIN','State Bank of India','NSE',780.00),
 ('TATAMOTORS','Tata Motors','NSE',950.00),('WIPRO','Wipro','NSE',480.00);

-- 30 days of price history generated with a recursive CTE
INSERT INTO stock_prices (stock_id, price, volume, recorded_at)
WITH RECURSIVE d(n) AS (SELECT 1 UNION ALL SELECT n+1 FROM d WHERE n < 30)
SELECT s.stock_id,
       ROUND(s.current_price * (0.95 + 0.10 * RAND(s.stock_id*100 + d.n)), 2),
       FLOOR(10000 + RAND(s.stock_id*7 + d.n) * 90000),
       NOW() - INTERVAL d.n DAY
FROM stocks s CROSS JOIN d;
INSERT INTO stock_prices (stock_id, price, volume, recorded_at)
 SELECT stock_id, current_price, 0, NOW() FROM stocks;

INSERT INTO portfolio (user_id, stock_id, total_quantity, avg_buy_price) VALUES
 (1,1,20,2380.00),(1,2,10,3500.00),(2,3,50,1450.00),(2,5,200,410.00),
 (3,4,40,1600.00),(4,6,100,760.00),(4,7,60,900.00),(5,8,150,470.00);

INSERT INTO watchlists (user_id, name) VALUES (1,'IT stocks'),(2,'Dividends');
INSERT INTO watchlist_items VALUES (1,2),(1,3),(1,8),(2,5),(2,4);
