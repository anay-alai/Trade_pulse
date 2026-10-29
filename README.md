# Trade Pulse – a stock trading platform in MySQL

A Zerodha/Groww-style DBMS project. Users hold a wallet, place market or limit orders, and see holdings and P&L.
The business rules live in the database (procedures, triggers, constraints); Flask + plain HTML/CSS is a thin layer on top.

## Run it
```bash
# 1. Database (MySQL 8.0.16+)
for f in sql/0*.sql; do mysql -u root -p < "$f"; done

# 2. Web app
pip install -r requirements.txt
export DB_USER=root DB_PASSWORD=yourpassword      # optional: DB_HOST, DB_NAME, DB_PORT
python app.py                                      # http://127.0.0.1:5000
```

## Where each DBMS concept lives
| Concept | Location |
|---|---|
| ER to relational, 3NF | `sql/01_schema.sql` (13 tables, junction tables for portfolio and watchlist items) |
| Constraints (PK, FK, UNIQUE, CHECK, ENUM) | `01_schema.sql`, e.g. balance >= 0, locked qty <= total qty, price > 0 |
| Transactions / ACID, row locks (`FOR UPDATE`) | `sp_place_order`, `sp_cancel_order`, `sp_update_price` |
| Stored procedures, cursor, error handlers (`SIGNAL`) | `03_routines.sql` |
| Triggers | tradable-stock check, wallet, order, and stock price audit trail |
| Views | `v_holdings`, `v_order_book`, `v_net_worth` in `04_views_queries.sql` |
| Window functions, recursive CTE 5-point moving average, running ledger total, seed price history |
| Indexing | composite `idx_book` on orders, `idx_user_orders_desc`; test with `EXPLAIN` (see end of `04`) |
| Security | roles and `GRANT` in `05_security.sql` |

## Business rules
- **Market order:** fills immediately at the current price.
- **Limit order:** fills now if the price already qualifies, otherwise it waits. Cash (buy) or shares (sell) are locked meanwhile.
- **Exchange desk page:** changing a price runs `sp_update_price`, which records history and fills every waiting order that now qualifies, all in one transaction.
- **Locks:** `available + locked` is always the user's total cash, so funds cannot be spent twice.

## Demo script
1. Log in as Aarav (Admin), open RELIANCE, place a market buy of 5. Watch wallet, holdings, executed price, and the audit log change together.
2. Place a limit buy of 10 at a price below the current one. Cash moves to "held for open orders".
3. Open the Exchange desk and drop RELIANCE to that price. The waiting order fills, and any price improvement is refunded.
4. Try to sell more shares than you own, or buy with too little cash: the procedure rejects it and rolls back.
5. Concurrency: in two `mysql` sessions run `CALL sp_place_order(...)` for the same user at once. The second waits on the wallet row lock.

## Known simplifications
Demo login has no password check (hashes are stored for the schema). Orders fill in full against the current price rather than matching user to user. The Exchange desk is restricted to Admin users (User #1 Aarav by default).
