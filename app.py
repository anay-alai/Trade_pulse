import os
import secrets
from decimal import Decimal, InvalidOperation
from functools import wraps

import mysql.connector
from mysql.connector import pooling
from flask import Flask, abort, flash, redirect, render_template, request, session, url_for

app = Flask(__name__)
app.secret_key = os.getenv("SECRET_KEY", "dev-only-change-in-production")

CFG = dict(
    host=os.getenv("DB_HOST", "localhost"),
    port=int(os.getenv("DB_PORT", "3306")),
    user=os.getenv("DB_USER", "root"),
    password=os.getenv("DB_PASSWORD", ""),
    database=os.getenv("DB_NAME", "trading_db"),
)

# Initialize connection pool with graceful fallback
try:
    POOL = pooling.MySQLConnectionPool(
        pool_name="trade_pulse_pool",
        pool_size=5,
        **CFG
    )
except Exception:
    POOL = None


def get_connection():
    if POOL is not None:
        return POOL.get_connection()
    return mysql.connector.connect(**CFG)


@app.template_filter("money")
def money(v):
    return "{:,.2f}".format(v or 0)


@app.context_processor
def inject_csrf_token():
    if "_csrf_token" not in session:
        session["_csrf_token"] = secrets.token_hex(16)
    return dict(csrf_token=lambda: session["_csrf_token"])


@app.before_request
def check_csrf():
    if request.method == "POST":
        token = request.form.get("_csrf_token")
        if not token or token != session.get("_csrf_token"):
            flash("Invalid or expired session security token. Please try again.", "error")
            return redirect(request.referrer or url_for("dashboard"))


def query(sql, args=(), one=False):
    conn = get_connection()
    try:
        cur = conn.cursor(dictionary=True)
        try:
            cur.execute(sql, args)
            rows = cur.fetchall()
            return (rows[0] if rows else None) if one else rows
        finally:
            cur.close()
    finally:
        conn.close()


def call(proc, args):
    """Run a stored procedure; the procedure itself owns the transaction."""
    conn = get_connection()
    try:
        cur = conn.cursor()
        try:
            res = cur.callproc(proc, args)
            return res
        finally:
            cur.close()
    finally:
        conn.close()


def login_required(f):
    @wraps(f)
    def wrapper(*a, **kw):
        if "uid" not in session:
            return redirect(url_for("login"))
        return f(*a, **kw)
    return wrapper


def admin_required(f):
    @wraps(f)
    def wrapper(*a, **kw):
        if "uid" not in session:
            return redirect(url_for("login"))
        if not session.get("is_admin", False):
            flash("Admin access required for the Exchange desk.", "error")
            return redirect(url_for("dashboard"))
        return f(*a, **kw)
    return wrapper


def run(proc, args, ok_msg):
    try:
        res = call(proc, args)
        flash(ok_msg(res) if callable(ok_msg) else ok_msg, "ok")
        return True
    except mysql.connector.Error as e:
        flash(e.msg or "A database error occurred.", "error")
        return False


@app.route("/", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        user_id_raw = request.form.get("user_id")
        try:
            uid = int(user_id_raw)
        except (TypeError, ValueError):
            flash("Invalid user selected.", "error")
            return redirect(url_for("login"))

        user = query("SELECT user_id, full_name, status FROM users WHERE user_id=%s", (uid,), True)
        if not user:
            flash("Selected user does not exist.", "error")
            return redirect(url_for("login"))

        if user.get("status") != "ACTIVE":
            flash("This account is suspended and cannot log in.", "error")
            return redirect(url_for("login"))

        session["uid"] = user["user_id"]
        session["name"] = user["full_name"]
        # In this demo setup, User #1 (Aarav Sharma) acts as Administrator
        session["is_admin"] = (user["user_id"] == 1)
        return redirect(url_for("dashboard"))

    users = query("SELECT user_id, full_name, email, status FROM users ORDER BY user_id")
    return render_template("login.html", users=users)


@app.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("login"))


@app.route("/profile")
@login_required
def profile():
    uid = session["uid"]
    user = query(
        """SELECT u.user_id, u.full_name, u.email, u.status,
                  up.pan_number, up.kyc_status
           FROM users u LEFT JOIN user_profiles up USING (user_id)
           WHERE u.user_id=%s""",
        (uid,),
        True,
    )
    wallet = query("SELECT * FROM wallets WHERE user_id=%s", (uid,), True)
    return render_template("profile.html", user=user, wallet=wallet)


@app.route("/watchlist", methods=["GET", "POST"])
@login_required
def watchlist():
    uid = session["uid"]
    if request.method == "POST":
        action = request.form.get("action", "").strip()

        if action == "create":
            name = request.form.get("name", "").strip()
            if not name:
                flash("Please provide a watchlist name.", "error")
                return redirect(url_for("watchlist"))
            try:
                query(
                    "INSERT INTO watchlists (user_id, name) VALUES (%s, %s)",
                    (uid, name),
                )
                flash(f"Watchlist '{name}' created.", "ok")
            except mysql.connector.IntegrityError:
                flash("A watchlist with that name already exists.", "error")
            return redirect(url_for("watchlist"))

        if action == "add_stock":
            try:
                stock_id = int(request.form.get("stock_id", "0"))
                watchlist_id = int(request.form.get("watchlist_id", "0"))
            except (TypeError, ValueError):
                flash("Invalid watchlist selection.", "error")
                return redirect(url_for("watchlist"))

            if not stock_id or not watchlist_id:
                flash("Select both a watchlist and a stock.", "error")
                return redirect(url_for("watchlist"))

            try:
                query(
                    "INSERT INTO watchlist_items (watchlist_id, stock_id) VALUES (%s, %s)",
                    (watchlist_id, stock_id),
                )
                flash("Stock added to watchlist.", "ok")
            except mysql.connector.IntegrityError:
                flash("This stock is already in the selected watchlist.", "error")
            return redirect(url_for("watchlist"))

        if action == "remove_stock":
            try:
                stock_id = int(request.form.get("stock_id", "0"))
                watchlist_id = int(request.form.get("watchlist_id", "0"))
            except (TypeError, ValueError):
                flash("Invalid selection.", "error")
                return redirect(url_for("watchlist"))
            query(
                "DELETE FROM watchlist_items WHERE watchlist_id=%s AND stock_id=%s",
                (watchlist_id, stock_id),
            )
            flash("Stock removed from watchlist.", "ok")
            return redirect(url_for("watchlist"))

        if action == "delete":
            try:
                watchlist_id = int(request.form.get("watchlist_id", "0"))
            except (TypeError, ValueError):
                flash("Invalid watchlist selection.", "error")
                return redirect(url_for("watchlist"))
            query("DELETE FROM watchlists WHERE watchlist_id=%s AND user_id=%s", (watchlist_id, uid))
            flash("Watchlist deleted.", "ok")
            return redirect(url_for("watchlist"))

        flash("Invalid watchlist action.", "error")
        return redirect(url_for("watchlist"))

    watchlists = query(
        """SELECT w.watchlist_id, w.name,
                  COUNT(wi.stock_id) AS item_count
           FROM watchlists w
           LEFT JOIN watchlist_items wi USING (watchlist_id)
           WHERE w.user_id=%s
           GROUP BY w.watchlist_id, w.name
           ORDER BY w.name""",
        (uid,),
    )
    items = query(
        """SELECT w.watchlist_id, w.name, s.stock_id, s.ticker_symbol, s.company_name
           FROM watchlists w
           LEFT JOIN watchlist_items wi ON wi.watchlist_id = w.watchlist_id
           LEFT JOIN stocks s ON s.stock_id = wi.stock_id
           WHERE w.user_id=%s
           ORDER BY w.name, s.ticker_symbol""",
        (uid,),
    )
    all_stocks = query("SELECT stock_id, ticker_symbol, company_name FROM stocks ORDER BY ticker_symbol")
    return render_template("watchlist.html", watchlists=watchlists, items=items, all_stocks=all_stocks)


@app.route("/dashboard")
@login_required
def dashboard():
    uid = session["uid"]
    wallet = query("SELECT * FROM wallets WHERE user_id=%s", (uid,), True)
    holdings = query("SELECT * FROM v_holdings WHERE user_id=%s ORDER BY current_value DESC", (uid,))
    orders = query("""SELECT o.*, s.ticker_symbol, e.executed_price, e.executed_at
                      FROM orders o
                      JOIN stocks s USING (stock_id)
                      LEFT JOIN order_executions e USING (order_id)
                      WHERE o.user_id=%s
                      ORDER BY o.order_id DESC LIMIT 15""", (uid,))
    invested = sum((h["invested"] for h in holdings), Decimal(0))
    value = sum((h["current_value"] for h in holdings), Decimal(0))
    return render_template("dashboard.html", wallet=wallet, holdings=holdings, orders=orders,
                           invested=invested, value=value, pnl=value - invested)


@app.route("/market")
@login_required
def market():
    return render_template("market.html", stocks=query("SELECT * FROM stocks ORDER BY ticker_symbol"))


@app.route("/stock/<int:stock_id>")
@login_required
def stock(stock_id):
    s = query("SELECT * FROM stocks WHERE stock_id=%s", (stock_id,), True)
    if not s:
        abort(404)
    history = query("""SELECT recorded_at, price,
                              ROUND(AVG(price) OVER (ORDER BY recorded_at ROWS BETWEEN 4 PRECEDING AND CURRENT ROW), 2) AS ma5
                       FROM stock_prices WHERE stock_id=%s ORDER BY recorded_at DESC LIMIT 12""", (stock_id,))
    held = query("SELECT * FROM v_holdings WHERE user_id=%s AND stock_id=%s", (session["uid"], stock_id), True)
    watchlists = query(
        """SELECT w.watchlist_id, w.name
           FROM watchlists w
           WHERE w.user_id=%s
           ORDER BY w.name""",
        (session["uid"],),
    )
    return render_template("stock.html", s=s, history=history, held=held, watchlists=watchlists)


@app.post("/order")
@login_required
def order():
    f = request.form
    try:
        stock_id = int(f.get("stock_id", 0))
        quantity = int(f.get("quantity", 0))
        side = f.get("side", "").strip().upper()
        order_type = f.get("order_type", "").strip().upper()
    except (TypeError, ValueError):
        flash("Invalid order submission parameters.", "error")
        return redirect(url_for("dashboard"))

    if side not in ("BUY", "SELL"):
        flash("Invalid order side. Must be BUY or SELL.", "error")
        return redirect(url_for("dashboard"))

    if order_type not in ("MARKET", "LIMIT"):
        flash("Invalid order type. Must be MARKET or LIMIT.", "error")
        return redirect(url_for("dashboard"))

    if quantity <= 0:
        flash("Quantity must be a positive integer.", "error")
        return redirect(url_for("dashboard"))

    limit = None
    if order_type == "LIMIT":
        raw_limit = f.get("limit_price", "").strip()
        try:
            limit = Decimal(raw_limit)
            if limit <= 0:
                raise InvalidOperation
        except (InvalidOperation, ValueError, TypeError):
            flash("Please enter a valid positive limit price.", "error")
            return redirect(url_for("stock", stock_id=stock_id))

    args = [session["uid"], stock_id, side, order_type, quantity, limit, 0]

    def msg(res):
        if res and len(res) > 6 and res[6]:
            row = query("SELECT status FROM orders WHERE order_id=%s", (res[6],), True)
            st = row["status"] if row else "PLACED"
            return f"Order #{res[6]} {'filled' if st == 'FILLED' else 'placed and waiting for your price'}."
        return "Order submitted successfully."

    run("sp_place_order", args, msg)
    return redirect(url_for("dashboard"))


@app.post("/cancel/<int:order_id>")
@login_required
def cancel(order_id):
    run("sp_cancel_order", [order_id, session["uid"]], f"Order #{order_id} cancelled.")
    return redirect(url_for("dashboard"))


@app.route("/wallet", methods=["GET", "POST"])
@login_required
def wallet():
    uid = session["uid"]
    if request.method == "POST":
        action = request.form.get("action", "").strip()
        if action not in ("deposit", "withdraw"):
            flash("Invalid wallet action.", "error")
            return redirect(url_for("wallet"))

        raw_amt = request.form.get("amount", "").strip()
        try:
            amt = Decimal(raw_amt)
            if amt <= 0:
                raise InvalidOperation
        except (InvalidOperation, ValueError, TypeError):
            flash("Please enter a valid positive amount.", "error")
            return redirect(url_for("wallet"))

        run("sp_deposit" if action == "deposit" else "sp_withdraw", [uid, amt],
            "Funds added." if action == "deposit" else "Withdrawal done.")
        return redirect(url_for("wallet"))

    w = query("SELECT * FROM wallets WHERE user_id=%s", (uid,), True)
    ledger = query("""SELECT t.txn_id, t.txn_type, t.amount, t.created_at,
                             SUM(t.amount) OVER (ORDER BY t.txn_id) AS running
                      FROM wallet_transactions t JOIN wallets w USING (wallet_id)
                      WHERE w.user_id=%s ORDER BY t.txn_id DESC LIMIT 30""", (uid,))
    return render_template("wallet.html", w=w, ledger=ledger)


@app.route("/leaderboard")
@login_required
def leaderboard():
    rows = query("""SELECT full_name, cash, holdings, cash + holdings AS net_worth,
                           RANK() OVER (ORDER BY cash + holdings DESC) AS position
                    FROM v_net_worth ORDER BY position""")
    return render_template("leaderboard.html", rows=rows)


@app.route("/admin", methods=["GET", "POST"])
@admin_required
def admin():
    if request.method == "POST":
        try:
            sid = int(request.form.get("stock_id", 0))
            price = Decimal(request.form.get("price", "0").strip())
            if price <= 0:
                raise InvalidOperation
        except (ValueError, TypeError, InvalidOperation):
            flash("Please enter a valid positive price.", "error")
            return redirect(url_for("admin"))

        run("sp_update_price", [sid, price], "Price updated. Any pending orders that now qualify were filled.")
        return redirect(url_for("admin"))

    return render_template("admin.html",
        stocks=query("SELECT * FROM stocks ORDER BY ticker_symbol"),
        book=query("SELECT * FROM v_order_book ORDER BY ticker_symbol, side, limit_price"),
        audit=query("SELECT * FROM audit_log ORDER BY log_id DESC LIMIT 15"))


@app.errorhandler(404)
def not_found(e):
    return render_template("404.html"), 404


@app.errorhandler(500)
def server_error(e):
    return render_template("500.html"), 500


if __name__ == "__main__":
    app.run(debug=os.getenv("FLASK_DEBUG", "0") == "1")
