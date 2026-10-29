# Trade Pulse – Project Documentation

## 1. Project Overview

Trade Pulse is a MySQL-backed stock trading simulation built using Python and Flask. The project demonstrates how database-centric business logic can enforce real-world trading rules through relational constraints, transactions, stored procedures, triggers, and views.

The application is designed as a DBMS learning project rather than a production-ready exchange platform. It models a simplified stock market where:

- users hold wallet balances
- users can place buy/sell orders
- orders are validated and executed by database procedures
- cash and share locks are maintained automatically
- portfolio and net worth are derived from views
- audit logs track key changes

The project is intentionally centered around database logic. In the Flask app, the Python layer acts mostly as a thin interface to the database.

## 2. Project Objective

The primary objective of this project is to demonstrate:

- schema design using relational database principles
- constraints and integrity rules
- transactions and ACID behavior
- stored procedures for business logic
- triggers for auditing and validation
- views for analytical reporting
- concurrency control and locking
- application integration with a database-backed backend

This is an ideal example of a DBMS-first application where the database owns the system’s correctness.

## 3. Project Structure

```text
.
├── app.py
├── README.md
├── requirements.txt
├── PROJECT_DOCUMENTATION.md
├── .gitignore
├── sql/
│   ├── 01_schema.sql
│   ├── 02_seed.sql
│   ├── 03_routines.sql
│   ├── 04_views_queries.sql
│   └── 05_security.sql
├── static/
│   └── style.css
├── templates/
│   ├── 404.html
│   ├── 500.html
│   ├── admin.html
│   ├── base.html
│   ├── dashboard.html
│   ├── leaderboard.html
│   ├── login.html
│   ├── market.html
│   ├── stock.html
│   └── wallet.html
└── .venv/
```

## 4. Technology Stack

- Python 3
- Flask
- MySQL 8.0+
- mysql-connector-python
- HTML/CSS templates

## 5. System Architecture

The system has a classic 3-layer structure:

### 5.1 Presentation Layer

The Flask app renders pages using Jinja templates stored in the `templates/` directory.

Key pages:

- login
- dashboard
- market
- stock detail
- wallet
- leaderboard
- admin

### 5.2 Application Layer

`app.py` handles:

- request routing
- session management
- CSRF token validation
- login authorization flow
- calling database procedures
- rendering templates with database data

### 5.3 Database Layer

The database layer is the real source of business logic. All important validations and state changes happen inside MySQL through:

- schema constraints
- transactions
- stored procedures
- triggers
- views

This architecture is intentional: the database acts as the system of record.

## 6. Core Business Model

The application models a simplified stock exchange.

### Users

Each user has:

- identifier
- name
- email
- password hash
- status (ACTIVE or SUSPENDED)
- profile details

### Wallets

Each user has a wallet with:

- available_balance
- locked_balance
- transaction history

Wallet balances are important because they enforce fund availability during trading.

### Stocks

Each stock has:

- ticker symbol
- company name
- exchange
- current price
- tradability marker

### Orders

Every order has:

- user_id
- stock_id
- side (BUY / SELL)
- type (MARKET / LIMIT)
- limit price
- quantity
- filled quantity
- status (PENDING / FILLED / CANCELLED)

### Portfolio

Portfolio represents the user’s holdings in stocks.

It tracks:

- total_quantity
- locked_quantity
- average buy price

This is the basis for holdings, P&L, and stock positions.

## 7. ER Diagram Coverage in the Project

The schema implements the essential logical model. The project covers the major entities and relationships from the ER diagram.

### 7.1 Main Entities

- `users`
- `user_profiles`
- `wallets`
- `wallet_transactions`
- `stocks`
- `stock_prices`
- `orders`
- `order_executions`
- `portfolio`
- `watchlists`
- `watchlist_items`
- `audit_log`

### 7.2 Key Relationships

- users to profiles: one-to-one
- users to wallets: one-to-one
- wallets to wallet transactions: one-to-many
- stocks to stock price history: one-to-many
- users to orders: one-to-many
- orders to executions: one-to-many
- users to portfolio entries: one-to-many
- stocks to portfolio entries: one-to-many
- users to watchlists: one-to-many
- watchlists to watchlist items: one-to-many

### 7.3 Database Integrity Features

The schema enforces integrity through:

- primary keys
- foreign keys
- unique constraints
- check constraints
- enum validations
- cascade rules

Examples:

- wallet balances cannot be negative
- stock prices must be positive
- order quantity must be > 0
- limit price must be positive if provided
- locked quantity cannot exceed total quantity
- only tradable stocks can be inserted into orders

## 8. Schema Design Details

The database creation script is in `sql/01_schema.sql`.

### 8.1 `users`

Stores core authentication and profile metadata.

Important fields:

- `user_id`
- `full_name`
- `email`
- `password_hash`
- `status`
- `created_at`

### 8.2 `user_profiles`

Stores extra user metadata such as PAN and KYC status.

### 8.3 `wallets`

Stores financial account state for each user.

Fields:

- `available_balance`
- `locked_balance`
- `updated_at`

The design keeps funds in two buckets:

- available balance: usable cash
- locked balance: reserved for pending orders

This prevents double-spending of the same money.

### 8.4 `wallet_transactions`

Every wallet movement is recorded here.

Transaction types include:

- DEPOSIT
- WITHDRAWAL
- STOCK_BUY
- STOCK_SELL

This provides a ledger for financial traceability.

### 8.5 `stocks`

Represents tradable securities.

Fields include:

- ticker symbol
- company name
- exchange
- current_price
- is_tradable

### 8.6 `stock_prices`

Stores historical prices for each stock with time stamps and volume.

This is used for:

- price trend analysis
- moving average queries
- chart generation
- execution logic

### 8.7 `orders`

Stores order requests.

Important business fields:

- `side`
- `order_type`
- `limit_price`
- `quantity`
- `filled_quantity`
- `status`
- `created_at`

### 8.8 `order_executions`

Stores details when an order is filled.

This table records:

- executed price
- executed quantity
- execution timestamp

### 8.9 `portfolio`

This table stores the user’s current share positions.

It tracks how many shares are currently owned and how much money is locked in pending sell orders.

### 8.10 `watchlists` and `watchlist_items`

Used for user-defined watchlists of favorite stocks.

### 8.11 `audit_log`

Stores system actions and changes to important entities such as:

- wallet balance changes
- order status changes
- stock price changes

## 9. Seed Data and Demo Setup

The project seeds users, wallets, stocks, price history, and portfolio records in `sql/02_seed.sql`.

This data is designed to make the UI and demo flows immediately usable.

Example seeded users:

- Aarav Sharma
- Diya Patil
- Kabir Mehta
- Meera Iyer
- Rohan Desai

The default admin is user 1, Aarav.

Example seeded stocks:

- RELIANCE
- TCS
- INFY
- HDFCBANK
- ITC
- SBIN
- TATAMOTORS
- WIPRO

## 10. Business Logic in Stored Procedures

The business logic is concentrated in `sql/03_routines.sql`.

### 10.1 `sp_deposit`

Adds cash to a user wallet.

Business rules:

- amount must be > 0
- wallet must exist
- transaction is recorded in wallet ledger

### 10.2 `sp_withdraw`

Withdraws cash from a user wallet.

Business rules:

- amount must be > 0
- user must have enough available balance
- transaction is logged

### 10.3 `sp_execute_order`

Internal procedure used to fill an order when it qualifies.

This procedure

- fetches the order under lock
- checks stock price against order type and side
- updates wallet balances
- updates portfolio
- inserts execution records
- marks order as FILLED

### 10.4 `sp_place_order`

This is the main trading procedure.

Inputs:

- user
- stock
- side
- type
- quantity
- limit price
- output order id

What it does:

- validates user and stock
- checks account status
- checks tradability
- validates enough available funds or share quantity
- reserves funds or locks shares
- inserts new order
- immediately attempts execution if conditions are met
- commits transaction as a single ACID unit

This is the heart of the project.

### 10.5 `sp_cancel_order`

Cancels a pending order.

If the order is a buy order, its locked balance is released.
If it is a sell order, the locked share quantity is released.

### 10.6 `sp_update_price`

Updates stock price and then checks all pending orders against the new value.

This is used by the Exchange desk to trigger fills when prices become favorable.

The procedure:

- updates stock price
- logs price history
- scans pending orders for the given stock
- executes any eligible ones in the same transaction

## 11. Triggers

The triggers in `03_routines.sql` enforce auditing and business validation.

### 11.1 `trg_orders_tradable`

Prevents placing orders on a non-tradable stock.

### 11.2 `trg_wallet_audit`

Logs changes to wallet balances in `audit_log`.

### 11.3 `trg_order_status_audit`

Logs when an order changes status.

### 11.4 `trg_stock_price_audit`

Logs stock price changes.

These triggers demonstrate event-driven database monitoring and accountability.

## 12. Views

The views in `sql/04_views_queries.sql` provide derived data for the application and reporting.

### 12.1 `v_holdings`

Shows each user’s stock holdings with:

- invested amount
- current value
- pnl
- pnl percentage

This is used in the dashboard and stock pages.

### 12.2 `v_order_book`

Shows currently pending orders with ticker, side, limit price, quantity, and user.

This powers the admin order book view.

### 12.3 `v_net_worth`

Computes:

- cash balance
- holdings value
- total net worth

This is used for leaderboard rankings.

## 13. Analytical Queries Included

The view file also contains examples for analytics, such as:

- moving average over stock prices
- running wallet totals using window functions
- ranking for net worth leaderboard
- EXPLAIN plans to inspect index usage

This helps demonstrate SQL analytic capabilities beyond basic CRUD.

## 14. Flask Application Design

The Flask app is in `app.py`.

### 14.1 Session management

The app uses Flask sessions to track:

- `uid`
- `name`
- `is_admin`
- CSRF token

### 14.2 login_required decorator

Protects pages so only logged-in users can access them.

### 14.3 admin_required decorator

Restricts admin features to a specific user.

### 14.4 Database helper functions

The app includes:

- `get_connection()`
- `query()` for SELECT queries
- `call()` for stored procedures
- `run()` for safe procedure execution with feedback

### 14.5 Request flow

When a user places an order:

1. form data is read
2. validation rules are checked in Python
3. procedure `sp_place_order` is called
4. MySQL validates and executes the trade
5. result is returned to Flask
6. flash message is shown to the user
7. redirect occurs

This design keeps the app simple while letting the database enforce correctness.

## 15. Key Application Flows

### 15.1 Login

The login page lists users and lets the user select one.

Important note:

- there is no actual password verification
- user selection acts as a simulated login

This is intentionally simplified for the demo.

### 15.2 Dashboard

Shows:

- wallet state
- holdings
- recent orders
- invested value
- current value
- profit/loss

### 15.3 Market Page

Shows the list of stocks for browsing and trading.

### 15.4 Stock Detail Page

Shows:

- current stock information
- recent price history
- user holdings in that stock

### 15.5 Wallet Page

Allows deposit/withdrawal and shows transaction history.

### 15.6 Leaderboard

Shows a ranking based on net worth.

### 15.7 Admin Page

Allows the admin user to update stock prices and view the order book and audit log.

## 16. Security Model

The app has a basic security setup, but it is not production-grade.

### 16.1 Application security

- session-based login
- CSRF token validation for POST requests
- admin guard on sensitive routes

### 16.2 Database security

`sql/05_security.sql` defines roles such as:

- `trader_role`
- `analyst_role`
- `admin_role`

These roles are granted permissions such as SELECT and EXECUTE for specific database objects.

### 16.3 Security limitations

The project does not include:

- password hashing in a secure application context
- secure user authentication with password verification
- role tables and user-role assignments in the application layer
- production-grade secret management
- protected environment variable management for deployment

This is a learning project, not a real financial system.

## 17. Concurrency and Transaction Handling

One of the strongest parts of this project is its use of database transactions.

Examples:

- `sp_place_order` wraps the full order process in a transaction
- `sp_update_price` updates a stock and then fills waiting orders
- `sp_withdraw` checks sufficient funds under lock
- `sp_cancel_order` releases reserved funds or shares safely

Because MySQL is used with locking and transaction boundaries, the project demonstrates how database consistency is preserved under concurrent operations.

## 18. Why This Project Is Valuable

This project is a good example of how a database can be used as the real source of application behavior.

It demonstrates:

- data integrity enforcement at the database level
- business logic placement in SQL instead of only application code
- multi-table consistency
- order lifecycle handling
- audit and traceability
- transaction correctness under concurrency

This is exactly the kind of design students and developers should study when learning DBMS systems.

## 19. Known Simplifications and Limitations

This project is intentionally simplified.

### 19.1 No real authentication

There is no actual password verification in the app layer. The current system selects a user from a list and treats that as a login.

### 19.2 No real matching engine

Orders do not match against counterparty orders in a sophisticated market-making sense. The system is a simplified model where a trade is validated and executed against current market price.

### 19.3 Hardcoded configuration

The Flask app uses default database credentials and a development secret key.

### 19.4 Limited scalability

This is designed for a classroom/demo environment rather than high-volume financial infrastructure.

### 19.5 Basic admin model

The admin check is based on fixed user ID logic rather than a full role-based access control system.

## 20. Execution Flow: How the App Works End-to-End

A typical user flow:

1. User opens the app and selects an account.
2. Flask reads the selected user ID.
3. The app queries the database for wallet, holdings, and order data.
4. The user places a BUY or SELL order.
5. Python validates form data.
6. Stored procedure `sp_place_order` runs in MySQL.
7. Database checks account status, stock validity, funds, and share holdings.
8. The order is inserted and potentially executed immediately.
9. Relevant wallet, portfolio, and execution tables are updated.
10. The user sees updated values in the dashboard.

This is a strong example of DB-driven app logic.

## 21. What Makes It a Good DBMS Project

This project is especially strong in the following areas:

- transactional correctness
- procedural SQL logic
- schema normalization and modeling
- constraint-driven data quality
- business rule enforcement at database level
- auditability
- analytics via views

It is highly educational because the project shows that business rules are not just application code—they can live in the database, where they are harder to bypass and easier to reason about consistently.

## 22. What It Still Needs for Production

To make the project production-ready, the following items would need to be added:

- real login with password hashing and verification
- proper role-based permissions for users
- safer configuration via environment files and secret management
- test suite for SQL procedures and validation logic
- API layer or better modular backend structure
- security review and hardening
- containerization and deployment configuration
- monitoring and logging infrastructure
- better support for real exchange matching rules

## 23. Conclusion

Trade Pulse is a well-structured DBMS-driven stock trading simulation that successfully demonstrates how relational databases can model and enforce trading rules. It combines schema design, constraints, transactions, procedures, triggers, and views into a cohesive project.

It is particularly strong as a learning project because it shows how critical business logic can be embedded in the database, making operations consistent, auditable, and controlled.

However, it is still a demo project, not a full production trading platform, because several important real-world features such as authentication, role management, deployment security, and scalable market matching are simplified.

## 24. Summary Judgment

- Academic value: excellent
- Database design quality: strong
- Business logic quality: strong
- Production readiness: limited
- Overall rating: very good DBMS project, not yet production-grade software

## 25. Relevant Files

- `app.py` — Flask app and routing logic
- `sql/01_schema.sql` — database schema
- `sql/02_seed.sql` — demo data
- `sql/03_routines.sql` — procedures and triggers
- `sql/04_views_queries.sql` — views and analytics
- `sql/05_security.sql` — role-based database permissions
- `templates/` — UI screens
- `static/style.css` — styling

This document should help you understand both the technical implementation and the intended learning value of the project.
