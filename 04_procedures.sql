-- ============================================================
-- STORED PROCEDURES: place_buy_order, place_sell_order
-- Kept simple on purpose:
--   * Only MARKET orders: executed immediately at current_price
--   * Each procedure is ONE transaction (all steps succeed or none do)
-- ============================================================
USE trading_platform;

DROP PROCEDURE IF EXISTS place_buy_order;
DROP PROCEDURE IF EXISTS place_sell_order;

DELIMITER $$

-- ------------------------------------------------------------
-- BUY: place_buy_order(user_id, stock_id, quantity)
-- Steps: validate -> create order -> record execution
--        -> deduct wallet -> log transaction -> update portfolio
-- ------------------------------------------------------------
CREATE PROCEDURE place_buy_order(
    IN p_user_id  INT,
    IN p_stock_id INT,
    IN p_qty      INT
)
proc: BEGIN
    DECLARE v_kyc       VARCHAR(10);
    DECLARE v_price     DECIMAL(12,2);
    DECLARE v_cost      DECIMAL(15,2);
    DECLARE v_wallet_id INT;
    DECLARE v_balance   DECIMAL(15,2);
    DECLARE v_order_id  INT;

    -- If ANY SQL error happens, undo everything done so far
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'ERROR: something went wrong, transaction rolled back' AS message;
    END;

    -- ---------- 1. Validation (nothing is changed yet) ----------
    IF p_qty IS NULL OR p_qty <= 0 THEN
        SELECT 'FAILED: quantity must be greater than 0' AS message;
        LEAVE proc;
    END IF;

    SELECT kyc_status INTO v_kyc FROM user_profiles WHERE user_id = p_user_id;
    IF v_kyc IS NULL OR v_kyc <> 'VERIFIED' THEN
        SELECT 'FAILED: user KYC is not verified' AS message;
        LEAVE proc;
    END IF;

    SELECT current_price INTO v_price FROM stocks WHERE stock_id = p_stock_id;
    IF v_price IS NULL THEN
        SELECT 'FAILED: stock not found' AS message;
        LEAVE proc;
    END IF;

    SET v_cost = v_price * p_qty;

    -- ---------- 2. Transaction starts ----------
    START TRANSACTION;

    -- FOR UPDATE locks this wallet row so no one else can change it meanwhile
    SELECT wallet_id, balance INTO v_wallet_id, v_balance
    FROM wallets WHERE user_id = p_user_id FOR UPDATE;

    IF v_balance < v_cost THEN
        ROLLBACK;
        SELECT 'FAILED: insufficient wallet balance' AS message;
        LEAVE proc;
    END IF;

    -- a) create the order
    INSERT INTO orders (user_id, stock_id, side, order_type, quantity, status)
    VALUES (p_user_id, p_stock_id, 'BUY', 'MARKET', p_qty, 'EXECUTED');
    SET v_order_id = LAST_INSERT_ID();

    -- b) record how it was executed
    INSERT INTO order_executions (order_id, exec_price, exec_quantity)
    VALUES (v_order_id, v_price, p_qty);

    -- c) deduct money from the wallet
    UPDATE wallets SET balance = balance - v_cost WHERE wallet_id = v_wallet_id;

    -- d) log it in the wallet ledger
    INSERT INTO wallet_transactions (wallet_id, txn_type, amount)
    VALUES (v_wallet_id, 'BUY', v_cost);

    -- e) update holdings
    IF EXISTS (SELECT 1 FROM portfolio
               WHERE user_id = p_user_id AND stock_id = p_stock_id) THEN
        -- already holds this stock: new average = total cost / total quantity
        UPDATE portfolio
        SET avg_buy_price = (quantity * avg_buy_price + v_cost) / (quantity + p_qty),
            quantity      = quantity + p_qty
        WHERE user_id = p_user_id AND stock_id = p_stock_id;
    ELSE
        INSERT INTO portfolio (user_id, stock_id, quantity, avg_buy_price)
        VALUES (p_user_id, p_stock_id, p_qty, v_price);
    END IF;

    COMMIT;   -- all five changes become permanent together
    SELECT 'SUCCESS: buy order executed' AS message,
           v_order_id AS order_id, v_price AS price, v_cost AS total_cost;
END$$

-- ------------------------------------------------------------
-- SELL: place_sell_order(user_id, stock_id, quantity)
-- Steps: validate -> create order -> record execution
--        -> reduce portfolio -> credit wallet -> log transaction
-- ------------------------------------------------------------
CREATE PROCEDURE place_sell_order(
    IN p_user_id  INT,
    IN p_stock_id INT,
    IN p_qty      INT
)
proc: BEGIN
    DECLARE v_price     DECIMAL(12,2);
    DECLARE v_amount    DECIMAL(15,2);
    DECLARE v_wallet_id INT;
    DECLARE v_held      INT;
    DECLARE v_order_id  INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'ERROR: something went wrong, transaction rolled back' AS message;
    END;

    -- ---------- 1. Validation ----------
    IF p_qty IS NULL OR p_qty <= 0 THEN
        SELECT 'FAILED: quantity must be greater than 0' AS message;
        LEAVE proc;
    END IF;

    SELECT current_price INTO v_price FROM stocks WHERE stock_id = p_stock_id;
    IF v_price IS NULL THEN
        SELECT 'FAILED: stock not found' AS message;
        LEAVE proc;
    END IF;

    SET v_amount = v_price * p_qty;

    -- ---------- 2. Transaction starts ----------
    START TRANSACTION;

    SELECT quantity INTO v_held
    FROM portfolio
    WHERE user_id = p_user_id AND stock_id = p_stock_id FOR UPDATE;

    IF v_held IS NULL OR v_held < p_qty THEN
        ROLLBACK;
        SELECT 'FAILED: not enough shares to sell' AS message;
        LEAVE proc;
    END IF;

    SELECT wallet_id INTO v_wallet_id FROM wallets WHERE user_id = p_user_id;

    -- a) create the order
    INSERT INTO orders (user_id, stock_id, side, order_type, quantity, status)
    VALUES (p_user_id, p_stock_id, 'SELL', 'MARKET', p_qty, 'EXECUTED');
    SET v_order_id = LAST_INSERT_ID();

    -- b) record execution
    INSERT INTO order_executions (order_id, exec_price, exec_quantity)
    VALUES (v_order_id, v_price, p_qty);

    -- c) reduce holdings (remove the row if nothing is left)
    IF v_held = p_qty THEN
        DELETE FROM portfolio WHERE user_id = p_user_id AND stock_id = p_stock_id;
    ELSE
        UPDATE portfolio SET quantity = quantity - p_qty
        WHERE user_id = p_user_id AND stock_id = p_stock_id;
    END IF;

    -- d) credit the wallet
    UPDATE wallets SET balance = balance + v_amount WHERE wallet_id = v_wallet_id;

    -- e) log it in the ledger
    INSERT INTO wallet_transactions (wallet_id, txn_type, amount)
    VALUES (v_wallet_id, 'SELL', v_amount);

    COMMIT;
    SELECT 'SUCCESS: sell order executed' AS message,
           v_order_id AS order_id, v_price AS price, v_amount AS total_amount;
END$$

DELIMITER ;
