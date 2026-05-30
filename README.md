# Binance NEARUSDT Futures — Real-Time Local Order Book

Maintains a fully synchronised local order book for Binance USDM Futures **NEARUSDT** using the diff depth WebSocket stream at 100 ms granularity, and continuously prints Level 1, 5, and 10 spread metrics to stdout.

## Requirements

Python 3.10+ and two third-party packages:

```
pip install websockets requests
```

## Running

Open `binance_nearusdt_orderbook.ipynb` in Jupyter and run all cells. The final cell uses `await main()` directly, which works in Jupyter's built-in async context.

To run as a plain Python script, replace the last cell's entry point with:

```python
import asyncio
asyncio.run(main())
```

Stop the program with **Ctrl+C** or a Jupyter kernel interrupt.

## Output

```
Timestamp(UTC+8)        | Spread L1%   | Spread L5%   | Spread L10%  | Best Bid     | Best Ask     | Mid Price
--------------------------------------------------------------------------------------------------------------
2026-05-18 16:23:29.783 | 0.06736275   | 0.60626474   | 1.27989222   | 1.48400000   | 1.48500000   | 1.48450000
```

Timestamps are in UTC+8. All prices and spreads are formatted to 8 decimal places. Diagnostic messages (`[INFO]`, `[WARN]`) are written to stderr.

Spread formula at each level N:

```
spread% = (ask_N - bid_N) / ((ask_N + bid_N) / 2) * 100
```

## Architecture

Two concurrent `asyncio` tasks communicate over a bounded queue (`maxsize=10000`):

| Task | Role |
|---|---|
| `websocket_receiver` | Connects to `wss://fstream.binance.com/ws/nearusdt@depth@100ms`, deserialises `depthUpdate` events, and enqueues them. Reconnects on disconnect with exponential back-off (1 s → 30 s). |
| `orderbook_processor` | Initialises the local book, applies incoming events, and prints spread metrics after every valid update. Triggers full resync on any sequence gap. |

The sync procedure follows the [Binance recommended approach](https://binance-docs.github.io/apidocs/futures/en/): fetch a REST snapshot, discard stale buffered events, find the bridging event where `U <= lastUpdateId <= u`, then apply diffs continuously.

`Decimal` arithmetic with precision 28 is used throughout to avoid float rounding in spread calculations.

## License

MIT — see [LICENSE](LICENSE).
