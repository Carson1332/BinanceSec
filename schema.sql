-- Raw diff events, append-only. Used for replay and audit.
-- Prices stored as JSON strings to preserve exact Decimal representation.
CREATE TABLE IF NOT EXISTS depth_updates (
  id         BIGINT       AUTO_INCREMENT PRIMARY KEY,
  symbol     VARCHAR(20)  NOT NULL,
  recv_time  BIGINT       NOT NULL,
  event_time BIGINT       NOT NULL,
  trade_time BIGINT       NOT NULL,
  first_uid  BIGINT       NOT NULL,
  final_uid  BIGINT       NOT NULL,
  prev_uid   BIGINT       NOT NULL,
  bids       JSON         NOT NULL,
  asks       JSON         NOT NULL,
  INDEX idx_sym_ts (symbol, recv_time)
);

-- Periodic top-20 depth snapshots (~1 s cadence). Used to seed replay.
CREATE TABLE IF NOT EXISTS book_snapshots (
  id        BIGINT      AUTO_INCREMENT PRIMARY KEY,
  symbol    VARCHAR(20) NOT NULL,
  ts        BIGINT      NOT NULL,
  last_uid  BIGINT      NOT NULL,
  bids      JSON        NOT NULL,
  asks      JSON        NOT NULL,
  INDEX idx_sym_ts (symbol, ts)
);

-- Derived metrics written at every valid book update.
-- Prices as DECIMAL(18,8) — avoid float imprecision at the column level.
CREATE TABLE IF NOT EXISTS metrics (
  id           BIGINT        AUTO_INCREMENT PRIMARY KEY,
  symbol       VARCHAR(20)   NOT NULL,
  ts           BIGINT        NOT NULL,
  spread_l1    DECIMAL(18,8),
  spread_l5    DECIMAL(18,8),
  spread_l10   DECIMAL(18,8),
  mid          DECIMAL(18,8),
  weighted_mid DECIMAL(18,8),
  imbalance    DECIMAL(10,6),
  INDEX idx_sym_ts (symbol, ts)
);

-- One row per detector firing (data-quality and microstructure events).
CREATE TABLE IF NOT EXISTS detections (
  id      BIGINT      AUTO_INCREMENT PRIMARY KEY,
  symbol  VARCHAR(20) NOT NULL,
  ts      BIGINT      NOT NULL,
  kind    VARCHAR(50) NOT NULL,
  detail  JSON,
  INDEX idx_sym_ts (symbol, ts)
);
