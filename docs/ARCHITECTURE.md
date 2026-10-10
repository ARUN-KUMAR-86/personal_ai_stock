# System Architecture & Technical Specification

## 1. High-Level Overview

The **Personal AI Stock Intelligence & Android Notification System** is a private, self-hosted quantitative scanning and decision-support platform designed for Linux workstations and Android smartphones.

The system combines automated market scanning, rule-based quantitative strategy evaluation, portfolio risk controls, paper trading, and push notification delivery.

```mermaid
flowchart TD
    subgraph Data Sources
        YF["Yahoo Finance (Delayed Real Data)"]
        GRW["Groww Trade API (Official Live Data)"]
        MCK["Mock Provider (Test/Offline Mode)"]
    end

    subgraph Backend Core [Python / FastAPI / Linux]
        PROV["Market Data Provider Factory"]
        SCAN["Scanner Engine (Batching & Hours Aware)"]
        SCHED["APScheduler (Configurable Intervals)"]
        IND["Technical Indicators (Pandas/NumPy)"]
        STRAT["Strategy Registry (Momentum, Mean Reversion, MACD)"]
        RISK["Risk Management Engine"]
        PORT["Portfolio & Paper Trading Simulator"]
        DEDUP["Alert Deduplication & Cooldown Cache"]
        FCM_NOTIF["Firebase Cloud Messaging Dispatcher"]
        DB[("PostgreSQL / SQLite Storage")]
        API["FastAPI REST / OpenAPI Endpoints"]
    end

    subgraph Mobile Client [Flutter / Android]
        DASH["Dashboard & Session Status"]
        SCN_UI["Scanner & Filter Terminal"]
        DET_UI["Chart & Indicator Deep Dive"]
        NOTIF_UI["Alert History & Push Receiver"]
        PORT_UI["Paper Portfolio & Positions"]
        FND_UI["Broker Margin & Funds"]
        SET_UI["Settings & LAN IP Config"]
    end

    YF --> PROV
    GRW --> PROV
    MCK --> PROV
    PROV --> SCAN
    SCHED --> SCAN
    SCAN --> IND
    IND --> STRAT
    STRAT --> RISK
    RISK --> DEDUP
    DEDUP --> FCM_NOTIF
    DEDUP --> DB
    PORT --> DB
    API <--> DB
    FCM_NOTIF -. Push Alert .-> NOTIF_UI
    API <== HTTP / JSON ==> Mobile Client
```

---

## 2. Component Design

### 2.1 Market Data Layer (`app/providers/`)
- **`BaseMarketDataProvider`**: Abstract base class defining `get_supported_universe`, `get_quote`, `get_historical_ohlcv`, and `get_market_status`.
- **`YahooMarketDataProvider`**: Real provider using `yfinance` for Indian NSE (`.NS`) and BSE (`.BO`) stocks. Flags data as `is_delayed=True` during live market hours to maintain data integrity.
- **`GrowwMarketDataProvider`**: Official integration with Groww Trade API (`growwapi` SDK). Delivers live quotes (`is_live=True`) and margins for subscribed accounts.
- **`MockMarketDataProvider`**: Deterministic test provider explicitly labeled `data_source="TEST_SIMULATED", is_live=False` for offline testing.

### 2.2 Analysis & Quantitative Strategies (`app/analysis/` & `app/strategies/`)
- All indicators are computed in vectorized Pandas/NumPy:
  - **Moving Averages**: SMA (20, 50, 200), EMA (9, 21, 50).
  - **Momentum**: RSI (14, Wilder's smoothed), Rate of Change (ROC 10).
  - **Trend & Inflection**: MACD (12, 26, 9) with histogram.
  - **Volatility & Liquidity**: ATR (14), Relative Volume (RVOL 20d).
  - **Price Levels**: Classical Pivot Points (Pivot, S1, S2, R1, R2), 20-Day Swing Highs/Lows.
- **Strategy Implementations**:
  1. *Momentum Breakout*: High-volume breakout above 20-day highs in confirmed uptrends.
  2. *Mean Reversion Pullback*: Oversold dips into S1/S2 support within structural bull trends.
  3. *MACD Trend Cross*: Bullish histogram momentum expansion above key moving averages.
- Every analysis produces: Signal Type, Strength score (0-100), Stop-Loss, Target, Risk/Reward ratio, Entry condition rule, and Invalidation conditions.

### 2.3 Alert Deduplication & Risk Engine (`app/notifications/` & `app/risk/`)
- **Deduplication Logic**: When an unchanged signal type is generated for the same stock, the notification engine suppresses repeated notifications within a configurable cooldown period (`NOTIFICATION_COOLDOWN_MINUTES=60`).
- **Risk Sizing**: Calculates maximum quantity according to a 2% capital risk rule:
  $$\text{Quantity} = \frac{\text{Capital} \times 0.02}{\text{Entry Price} - \text{Stop Loss}}$$
- Enforces single-stock allocation caps ($\le 10\%$) and portfolio exposure caps ($\le 25\%$).

### 2.4 Mobile Application (`mobile/`)
- Clean dark theme matching professional financial terminals.
- Connects over LAN (`http://192.168.x.x:8000`) or production domain.
- 7 modular screens: Dashboard, Scanner, Stock Details, Notifications, Portfolio, Funds, Settings.
