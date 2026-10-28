USE trading_db;
DELIMITER $$

-- ---------- TRIGGERS ----------
CREATE TRIGGER trg_orders_tradable BEFORE INSERT ON orders FOR EACH ROW
BEGIN
  DECLARE v_tradable BOOLEAN;
  SELECT is_tradable INTO v_tradable FROM stocks WHERE stock_id = NEW.stock_id;
  IF v_tradable IS NOT TRUE THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'This stock is not tradable or does not exist';
  END IF;
END$$

CREATE TRIGGER trg_wallet_audit AFTER UPDATE ON wallets FOR EACH ROW
BEGIN
  IF OLD.available_balance <> NEW.available_balance THEN
    INSERT INTO audit_log (entity, entity_id, action, old_value, new_value)
    VALUES ('WALLET', NEW.wallet_id, 'BALANCE_CHANGE', OLD.available_balance, NEW.available_balance);
  END IF;
END$$

CREATE TRIGGER trg_order_status_audit AFTER UPDATE ON orders FOR EACH ROW
BEGIN
  IF OLD.status <> NEW.status THEN
    INSERT INTO audit_log (entity, entity_id, action, old_value, new_value)
    VALUES ('ORDER', NEW.order_id, 'STATUS_CHANGE', OLD.status, NEW.status);
  END IF;
END$$

CREATE TRIGGER trg_stock_price_audit AFTER UPDATE ON stocks FOR EACH ROW
BEGIN
  IF OLD.current_price <> NEW.current_price THEN
    INSERT INTO audit_log (entity, entity_id, action, old_value, new_value)
    VALUES ('STOCK', NEW.stock_id, 'PRICE_CHANGE', OLD.current_price, NEW.current_price);
  END IF;
END$$

-- ---------- WALLET ----------
CREATE PROCEDURE sp_deposit(IN p_user INT, IN p_amount DECIMAL(15,2))
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  IF p_amount <= 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Amount must be positive'; END IF;
  START TRANSACTION;
  UPDATE wallets SET available_balance = available_balance + p_amount WHERE user_id = p_user;
  IF ROW_COUNT() = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Wallet not found'; END IF;
  INSERT INTO wallet_transactions (wallet_id, amount, txn_type)
    SELECT wallet_id, p_amount, 'DEPOSIT' FROM wallets WHERE user_id = p_user;
  COMMIT;
END$$

CREATE PROCEDURE sp_withdraw(IN p_user INT, IN p_amount DECIMAL(15,2))
BEGIN
  DECLARE v_avail DECIMAL(15,2);
  DECLARE v_found BOOLEAN DEFAULT TRUE;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_found = FALSE;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  IF p_amount <= 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Amount must be positive'; END IF;
  START TRANSACTION;
  SELECT available_balance INTO v_avail FROM wallets WHERE user_id = p_user FOR UPDATE;
  IF NOT v_found OR v_avail IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Wallet not found';
  END IF;
  IF v_avail < p_amount THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient available balance';
  END IF;
  UPDATE wallets SET available_balance = available_balance - p_amount WHERE user_id = p_user;
  INSERT INTO wallet_transactions (wallet_id, amount, txn_type)
    SELECT wallet_id, -p_amount, 'WITHDRAWAL' FROM wallets WHERE user_id = p_user;
  COMMIT;
END$$

-- ---------- ORDER EXECUTION (internal; caller owns the transaction) ----------
CREATE PROCEDURE sp_execute_order(IN p_order INT)
main: BEGIN
  DECLARE v_user, v_stock, v_qty INT;
  DECLARE v_side VARCHAR(4);
  DECLARE v_type VARCHAR(6);
  DECLARE v_limit, v_cur, v_reserve DECIMAL(12,2);
  DECLARE v_ok BOOLEAN DEFAULT FALSE;
  DECLARE v_found BOOLEAN DEFAULT TRUE;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_found = FALSE;

  SELECT user_id, stock_id, side, order_type, limit_price, quantity
    INTO v_user, v_stock, v_side, v_type, v_limit, v_qty
    FROM orders WHERE order_id = p_order AND status = 'PENDING' FOR UPDATE;
  IF NOT v_found OR v_stock IS NULL THEN LEAVE main; END IF;

  SELECT current_price INTO v_cur FROM stocks WHERE stock_id = v_stock;
  IF NOT v_found OR v_cur IS NULL THEN LEAVE main; END IF;

  IF v_type = 'MARKET' THEN SET v_ok = TRUE;
  ELSEIF v_side = 'BUY'  AND v_cur <= v_limit THEN SET v_ok = TRUE;
  ELSEIF v_side = 'SELL' AND v_cur >= v_limit THEN SET v_ok = TRUE;
  END IF;
  IF NOT v_ok THEN LEAVE main; END IF;

  IF v_side = 'BUY' THEN
    SET v_reserve = IFNULL(v_limit, v_cur);
    -- release the reservation, refund any price improvement
    UPDATE wallets SET locked_balance = locked_balance - v_qty * v_reserve,
                       available_balance = available_balance + v_qty * (v_reserve - v_cur)
      WHERE user_id = v_user;
    INSERT INTO wallet_transactions (wallet_id, amount, txn_type)
      SELECT wallet_id, -v_qty * v_cur, 'STOCK_BUY' FROM wallets WHERE user_id = v_user;
    INSERT INTO portfolio (user_id, stock_id, total_quantity, avg_buy_price)
      VALUES (v_user, v_stock, v_qty, v_cur)
      ON DUPLICATE KEY UPDATE
        avg_buy_price = (total_quantity * avg_buy_price + v_qty * v_cur) / (total_quantity + v_qty),
        total_quantity = total_quantity + v_qty;
  ELSE
    UPDATE portfolio SET total_quantity = total_quantity - v_qty,
                         locked_quantity = locked_quantity - v_qty
      WHERE user_id = v_user AND stock_id = v_stock;
    UPDATE wallets SET available_balance = available_balance + v_qty * v_cur WHERE user_id = v_user;
    INSERT INTO wallet_transactions (wallet_id, amount, txn_type)
      SELECT wallet_id, v_qty * v_cur, 'STOCK_SELL' FROM wallets WHERE user_id = v_user;
    DELETE FROM portfolio WHERE user_id = v_user AND stock_id = v_stock AND total_quantity = 0;
  END IF;

  INSERT INTO order_executions (order_id, executed_price, executed_quantity) VALUES (p_order, v_cur, v_qty);
  UPDATE orders SET filled_quantity = v_qty, status = 'FILLED' WHERE order_id = p_order;
END$$

-- ---------- PLACE ORDER (one ACID transaction) ----------
CREATE PROCEDURE sp_place_order(IN p_user INT, IN p_stock INT, IN p_side VARCHAR(4),
    IN p_type VARCHAR(6), IN p_qty INT, IN p_limit DECIMAL(12,2), OUT o_order INT)
BEGIN
  DECLARE v_cur, v_need, v_avail DECIMAL(15,2);
  DECLARE v_free INT;
  DECLARE v_user_status VARCHAR(20);
  DECLARE v_tradable BOOLEAN;
  DECLARE v_found BOOLEAN DEFAULT TRUE;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_found = FALSE;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  IF p_qty <= 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quantity must be positive'; END IF;
  IF p_side NOT IN ('BUY', 'SELL') THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Side must be BUY or SELL'; END IF;
  IF p_type NOT IN ('MARKET', 'LIMIT') THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Order type must be MARKET or LIMIT'; END IF;
  IF p_type = 'LIMIT' AND (p_limit IS NULL OR p_limit <= 0) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Limit orders need a positive limit price';
  END IF;

  START TRANSACTION;
  SELECT status INTO v_user_status FROM users WHERE user_id = p_user;
  IF NOT v_found OR v_user_status IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User not found'; END IF;
  IF v_user_status <> 'ACTIVE' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User account is not active'; END IF;

  SET v_found = TRUE;
  SELECT current_price, is_tradable INTO v_cur, v_tradable FROM stocks WHERE stock_id = p_stock;
  IF NOT v_found OR v_cur IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock not found'; END IF;
  IF NOT v_tradable THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'This stock is not tradable'; END IF;

  IF p_side = 'BUY' THEN
    SET v_need = p_qty * IF(p_type = 'MARKET', v_cur, p_limit);
    SET v_found = TRUE;
    SELECT available_balance INTO v_avail FROM wallets WHERE user_id = p_user FOR UPDATE;
    IF NOT v_found OR v_avail IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Wallet not found'; END IF;
    IF v_avail < v_need THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient funds'; END IF;
    UPDATE wallets SET available_balance = available_balance - v_need,
                       locked_balance = locked_balance + v_need WHERE user_id = p_user;
  ELSE
    SELECT COALESCE(SUM(total_quantity - locked_quantity), 0) INTO v_free
      FROM portfolio WHERE user_id = p_user AND stock_id = p_stock FOR UPDATE;
    IF v_free < p_qty THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient shares to sell';
    END IF;
    UPDATE portfolio SET locked_quantity = locked_quantity + p_qty
      WHERE user_id = p_user AND stock_id = p_stock;
  END IF;

  INSERT INTO orders (user_id, stock_id, side, order_type, limit_price, quantity)
    VALUES (p_user, p_stock, p_side, p_type, IF(p_type = 'LIMIT', p_limit, NULL), p_qty);
  SET o_order = LAST_INSERT_ID();
  CALL sp_execute_order(o_order);   -- fills immediately if the price allows
  COMMIT;
END$$

CREATE PROCEDURE sp_cancel_order(IN p_order INT, IN p_user INT)
BEGIN
  DECLARE v_stock, v_qty INT;
  DECLARE v_side VARCHAR(4);
  DECLARE v_limit, v_refund DECIMAL(12,2);
  DECLARE v_found BOOLEAN DEFAULT TRUE;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_found = FALSE;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  START TRANSACTION;
  SELECT stock_id, side, limit_price, quantity INTO v_stock, v_side, v_limit, v_qty
    FROM orders WHERE order_id = p_order AND user_id = p_user AND status = 'PENDING' FOR UPDATE;
  IF NOT v_found OR v_stock IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No pending order found'; END IF;

  IF v_side = 'BUY' THEN
    SET v_refund = v_qty * IFNULL(v_limit, 0);
    UPDATE wallets SET locked_balance = locked_balance - v_refund,
                       available_balance = available_balance + v_refund WHERE user_id = p_user;
  ELSE
    UPDATE portfolio SET locked_quantity = locked_quantity - v_qty
      WHERE user_id = p_user AND stock_id = v_stock;
  END IF;
  UPDATE orders SET status = 'CANCELLED' WHERE order_id = p_order;
  COMMIT;
END$$

-- ---------- PRICE UPDATE: records history, then fills pending orders that now qualify ----------
CREATE PROCEDURE sp_update_price(IN p_stock INT, IN p_price DECIMAL(12,2))
BEGIN
  DECLARE v_done INT DEFAULT 0;
  DECLARE v_id INT;
  DECLARE cur CURSOR FOR
    SELECT order_id FROM orders WHERE stock_id = p_stock AND status = 'PENDING' ORDER BY created_at, order_id;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  IF p_price <= 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Price must be positive'; END IF;

  START TRANSACTION;
  UPDATE stocks SET current_price = p_price WHERE stock_id = p_stock;
  IF ROW_COUNT() = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock not found'; END IF;

  INSERT INTO stock_prices (stock_id, price, volume, recorded_at) VALUES (p_stock, p_price, 0, NOW());
  OPEN cur;
  fill: LOOP
    SET v_done = 0;
    FETCH cur INTO v_id;
    IF v_done = 1 THEN LEAVE fill; END IF;
    CALL sp_execute_order(v_id);
  END LOOP;
  CLOSE cur;
  COMMIT;
END$$

DELIMITER ;
