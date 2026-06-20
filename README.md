# Binance NEARUSDT Futures — Market-Data Capture System

A production-shaped pipeline that ingests two Binance USDM Futures WebSocket streams, maintains a validated local order book, and persists raw diffs, periodic snapshots, derived metrics, and detector events to MySQL. An offline replay harness reconstructs book state from stored data and asserts integrity.

## Architecture

```
aggTrade ──┐
           ├─► WS receiver ─► bounded queue ─► book processor ─┬─► write queue ─► batched MySQL writer
depth@100ms┘  (reconnect,                     (apply diff,     ├─► detectors ─► detections table
              gap detect)                     validate seq)    └─► observability (structured status lines)

            stored data ─► replay harness ─► integrity assertion ─► offline analytics
```

## Requirements

Python 3.10+, Docker, and:

```
pip install websockets requests aiomysql pandas scipy matplotlib
```

## Quickstart

```bash
# Start the database
docker compose up -d

# Run the notebook (Jupyter)
# Open binance_nearusdt_orderbook.ipynb and run all cells in Part 1
```

To run outside Jupyter replace the entry-point cell with `asyncio.run(main())`.

Stop the capture with Ctrl+C or a Jupyter kernel interrupt.

## Database Schema

Four tables in `marketdata`:

| Table | Purpose |
|---|---|
| `depth_updates` | Append-only raw diff events with `E`, `T`, `recv_time`, and sequence IDs — used for replay |
| `book_snapshots` | Top-20 depth snapshot written every ~1 s — seeds the replay harness |
| `metrics` | Derived per-event L1/L5/L10 spreads, mid, weighted mid, imbalance |
| `detections` | One row per detector firing (data-quality and microstructure events) |

Prices are stored as `DECIMAL(18,8)` — MySQL `FLOAT` loses precision at the 8th decimal place, which corrupts spread comparisons on low-priced assets.

## Persistence Design

The DB writer is a dedicated async coroutine consuming from its own `asyncio.Queue(maxsize=5000)`. It buffers rows and flushes via `executemany` on a count-or-timer threshold (500 rows or 250 ms, whichever first).

A naïve per-row `INSERT` saturates the DB connection under 100 ms update load. Batching amortises the round-trip cost. If the write queue fills, the processor drops the row and logs a warning rather than stalling — book correctness takes priority over data completeness.

## Detection Layer

**Data-quality detectors** (correctness):
- `crossed_book` — `best_bid >= best_ask` after applying an event
- `sequence_gap` — `pu != last_update_id`; triggers a full resync
- `stale_book` — no `depthUpdate` received for > 500 ms

**Microstructure/event detectors**:
- `regime_wide` / `regime_tight` — L1 spread z-score outside ±2σ / -1σ over a 300-event rolling window (~30 s)
- `depth_wall` — a price level within the top 20 carries > 3× the mean quantity of all shallower levels
- `imbalance_spike` — `|imbalance| > 0.80`

## Observability

Every 5 s the processor emits a structured JSON status line to stderr:

```json
{"ts":1750000000000,"level":"MONITOR","component":"obs","msg":"sym=NEARUSDT","eps":9.8,"q_depth":4,"q_writer":11,"net_p95_ms":43.2,"local_p95_ms":0.4}
```

Latency decomposition:
- `exchange_internal = E - T` — Binance internal processing
- `network = recv - E` — gateway to local Python (includes clock skew without NTP)
- `local_processing = applied - recv` — `json.loads` + `apply_event`

## Replay and Integrity

Part 2 of the notebook reconstructs the order book from stored `book_snapshots` + `depth_updates` and asserts zero sequence gaps. A passing assertion proves the captured data is sufficient to rebuild exact book state offline — the foundation for backtesting and analytics.

## Offline Analytics

Part 3 loads the `metrics` table into pandas and produces:

1. **Imbalance → next-tick mid OLS** — estimates the predictive power of the weighted-mid lean (Cont-Kukanov-Stoikov 2014). Expected R² ≈ 0.05–0.30 at 100 ms.
2. **Lag-1 autocorrelation + Roll's implied spread** — negative `rho1` confirms bid-ask bounce (Roll 1984). Roll spread and observed L1 spread are compared.
3. **Spread time series with regime bands** — WIDE/TIGHT episodes plotted against the rolling ±2σ envelope.

## License

MIT — see [LICENSE](LICENSE).
