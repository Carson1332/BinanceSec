# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Single Jupyter notebook implementing a real-time local order book for Binance USDⓈ-M Futures **NEARUSDT**, printing Level 1, 5, and 10 spreads after each update.

## Dependencies

```
pip install websockets requests
```

Only `websockets` and `requests` are third-party. Python standard library otherwise.

## Running

Open and run `binance_nearusdt_orderbook.ipynb` in Jupyter. The entry point cell uses `await main()` directly (valid in Jupyter's async context — do not wrap in `asyncio.run()`). Stop with Ctrl+C or kernel interrupt.

To run outside Jupyter, replace the entry point cell with:
```python
asyncio.run(main())
```

## Architecture

Two concurrent `asyncio` tasks communicate via a bounded `asyncio.Queue(maxsize=10000)`:

1. **`websocket_receiver`** — connects to `wss://fstream.binance.com/ws/nearusdt@depth@100ms`, deserialises `depthUpdate` events, and enqueues them. Reconnects with exponential backoff on disconnect.

2. **`orderbook_processor`** — initialises the book via `initialise_orderbook`, then applies events from the queue one by one, printing spread metrics after each valid update. Triggers full resync on gap detection.

### Sync Procedure (`initialise_orderbook`)

Follows [Binance's official diff depth sync procedure](https://binance-docs.github.io/apidocs/futures/en/):
1. WebSocket receiver is already running and buffering.
2. Fetch REST snapshot (`GET /fapi/v1/depth?symbol=NEARUSDT&limit=1000`).
3. Discard buffered events where `u < lastUpdateId`.
4. Find first event where `U <= lastUpdateId <= u` to bridge snapshot → stream.
5. If no bridging event exists, retry after 200 ms.

### `LocalOrderBook`

- Stores bids/asks as `Dict[Decimal, Decimal]` (price → quantity).
- `apply_event` enforces the `pu == last_update_id` continuity check; returns `False` on gap, triggering resync.
- Uses `Decimal` with precision 28 to avoid float rounding in spread calculations.
- `metrics()` returns spread percentages at levels 1, 5, 10 plus best bid/ask/mid. Returns `None` if fewer than 10 levels exist on either side.

### Spread Formula

```
spread% = (ask_price - bid_price) / mid_price * 100
```

where `mid_price = (ask_price + bid_price) / 2`, computed at each level independently.

## Output Format

```
Timestamp(UTC+8)        | Spread L1%   | Spread L5%   | Spread L10%  | Best Bid     | Best Ask     | Mid Price
--------------------------------------------------------------------------------------------------------------
2026-05-18 16:23:29.783 | 0.06736275   | 0.60626474   | 1.27989222   | 1.48400000   | 1.48500000   | 1.48450000
```

Timestamps use UTC+8. All prices/spreads formatted to 8 decimal places. Diagnostics (`[INFO]`, `[WARN]`) go to `stderr`.
