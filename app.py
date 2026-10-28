import os
from decimal import Decimal
from functools import wraps

import mysql.connector
from flask import Flask, flash, redirect, render_template, request, session, url_for

app = Flask(__name__)
app.secret_key = "dev-only-change-me"

CFG = dict(
    host=os.getenv("DB_HOST", "localhost"),
    user=os.getenv("DB_USER", "root"),
    password=os.getenv("DB_PASSWORD", "mumbai"),
    database=os.getenv("DB_NAME", "trading_db"),
)


@app.template_filter("money")
def money(v):
    return "{:,.2f}".format(v or 0)


def query(sql, args=(), one=False):
    conn = mysql.connector.connect(**CFG)
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute(sql, args)
        rows = cur.fetchall()
        return (rows[0] if rows else None) if one else rows
    finally:
        conn.close()


def call(proc, args):
    """Run a stored procedure; the procedure itself owns the transaction."""
    conn = mysql.connector.connect(**CFG)
    try:
        cur = conn.cursor()
        return cur.callproc(proc, args)
    finally:
        conn.close()


def login_required(f):
    @wraps(f)
    def wrapper(*a, **kw):
        if "uid" not in session:
            return redirect(url_for("login"))
        return f(*a, **kw)
    return wrapper


def run(proc, args, ok_msg):
    try:
        res = call(proc, args)
        flash(ok_msg(res) if callable(ok_msg) else ok_msg, "ok")
    except mysql.connector.Error as e:
        flash(e.msg, "error")


@app.route("/", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        session["uid"] = int(request.form["user_id"])
        session["name"] = query("SELECT full_name FROM users WHERE user_id=%s", (session["uid"],), True)["full_name"]
        return redirect(url_for("dashboard"))
    return render_template("login.html", users=query("SELECT user_id, full_name, email FROM users"))


@app.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("login"))


@app.route("/dashboard")
@login_required
def dashboard():
    uid = session["uid"]
    wallet = query("SELECT * FROM wallets WHERE user_id=%s", (uid,), True)
    holdings = query("SELECT * FROM v_holdings WHERE user_id=%s ORDER BY current_value DESC", (uid,))
    orders = query("""SELECT o.*, s.ticker_symbol FROM orders o JOIN stocks s USING (stock_id)
                      WHERE o.user_id=%s ORDER BY o.order_id DESC LIMIT 15""", (uid,))
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
    history = query("""SELECT recorded_at, price,
                              ROUND(AVG(price) OVER (ORDER BY recorded_at ROWS BETWEEN 4 PRECEDING AND CURRENT ROW), 2) AS ma5
                       FROM stock_prices WHERE stock_id=%s ORDER BY recorded_at DESC LIMIT 12""", (stock_id,))
    held = query("SELECT * FROM v_holdings WHERE user_id=%s AND stock_id=%s", (session["uid"], stock_id), True)
    return render_template("stock.html", s=s, history=history, held=held)


@app.post("/order")
@login_required
def order():
    f = request.form
    limit = Decimal(f["limit_price"]) if f["order_type"] == "LIMIT" and f.get("limit_price") else None
    args = [session["uid"], int(f["stock_id"]), f["side"], f["order_type"], int(f["quantity"]), limit, 0]

    def msg(res):
        st = query("SELECT status FROM orders WHERE order_id=%s", (res[6],), True)["status"]
        return f"Order #{res[6]} {'filled' if st == 'FILLED' else 'placed and waiting for your price'}."
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
        action = request.form["action"]
        amt = Decimal(request.form["amount"])
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
@login_required
def admin():
    if request.method == "POST":
        sid, price = int(request.form["stock_id"]), Decimal(request.form["price"])
        run("sp_update_price", [sid, price], "Price updated. Any pending orders that now qualify were filled.")
        return redirect(url_for("admin"))
    return render_template("admin.html",
        stocks=query("SELECT * FROM stocks ORDER BY ticker_symbol"),
        book=query("SELECT * FROM v_order_book ORDER BY ticker_symbol, side, limit_price"),
        audit=query("SELECT * FROM audit_log ORDER BY log_id DESC LIMIT 15"))


if __name__ == "__main__":
    app.run(debug=True)
