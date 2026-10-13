# Personal AI Stock Intelligence & Android Notification System

A private, self-hosted quantitative stock scanning and decision-support application built for Linux workstations and Android smartphones.

Automatically scans supported Indian stock markets (NSE / BSE), computes verifiable technical indicators, identifies high-confluence entry and exit opportunities, calculates ATR-based stop-loss and target levels, enforces strict portfolio risk limits, tracks paper trading performance, and dispatches push alerts to your Android phone via Firebase Cloud Messaging.

> [!IMPORTANT]
> **Free Cloud Backend & Android App Ready**:
> - **Zero-Laptop Cloud Operation**: Refer to [`docs/CLOUD_DEPLOYMENT.md`](file:///home/arun/personal-ai-stock/docs/CLOUD_DEPLOYMENT.md) for 1-click Render free-tier deployment, market hours keep-alive, and Firebase setup.
> - **Ready-to-Install Android APK**: [`mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`](file:///home/arun/personal-ai-stock/mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk) or [`/home/arun/Downloads/app-arm64-v8a-release.apk`](file:///home/arun/Downloads/app-arm64-v8a-release.apk) (21.9 MB).
> - **Personal User Guide**: Refer to [`docs/PERSONAL_USER_GUIDE.md`](file:///home/arun/personal-ai-stock/docs/PERSONAL_USER_GUIDE.md) for day-to-day workflow instructions.

---

## 1. System Architecture

```
personal-ai-stock/
├── backend/
│   ├── app/
│   │   ├── api/v1/          # REST endpoints (auth, stocks, scanner, signals, alerts, portfolio, funds, groww, backtest)
│   │   ├── core/            # Configuration, secure JWT auth, redacting logger, exceptions
│   │   ├── database/        # SQLAlchemy engine, session, Base
│   │   ├── models/          # SQLAlchemy ORM models (stocks, candles, signals, scan jobs, alerts, positions, trades)
│   │   ├── schemas/         # Pydantic request/response validation schemas
│   │   ├── providers/       # Market Data Providers (Yahoo Finance, Groww API, Test Simulated)
│   │   ├── scanner/         # Background scheduler (APScheduler), batching, market-hours checker
│   │   ├── analysis/        # Technical indicators (SMA, EMA, RSI, MACD, ATR, RVOL, Pivots)
│   │   ├── strategies/      # Rule-based strategies (Momentum Breakout, Mean Reversion, MACD Cross)
│   │   ├── risk/            # Risk sizing engine (2% capital rule, stop-loss/target checks, exposure cap)
│   │   ├── portfolio/       # Paper trading engine, ledger, transaction costs simulator
│   │   ├── brokers/         # Groww Trade API adapter with manual-trading-first safety gates
│   │   ├── notifications/   # FCM push notification dispatcher with cooldown & deduplication
│   │   └── backtesting/     # Historical simulation engine without lookahead bias
│   ├── tests/               # Pytest suite (20 automated unit and integration tests)
│   ├── requirements.txt     # Python dependencies
│   ├── Dockerfile           # Backend container
│   └── pytest.ini           # Test configuration
├── mobile/
│   ├── lib/
│   │   ├── models/          # Dart models (MarketStatus, StockSummary, StockSignal, StockAlert, Portfolio)
│   │   ├── services/        # ApiService, StorageService, FCM handler
│   │   ├── state/           # AppState (ChangeNotifier provider)
│   │   ├── widgets/         # SignalPill, MarketBadge, StatCard
│   │   ├── screens/         # Dashboard, Scanner, StockDetail, Notifications, Portfolio, Funds, Settings
│   │   └── main.dart        # Flutter entrypoint with dark trading theme
│   ├── android/             # Android native Gradle configuration & Manifest
│   └── pubspec.yaml         # Flutter dependencies
├── deployment/
│   └── docker-compose.yml   # Multi-container setup (PostgreSQL 16 + FastAPI)
├── scripts/
│   ├── run_backend.sh       # One-click backend startup script
│   ├── run_scanner_manual.py# Manual CLI stock scanner utility
│   └── test_notification.py # CLI test alert generator
├── docs/                    # Architecture, Groww API, Firebase, and Strategy guides
├── .env.example             # Documented environment variables template
├── .gitignore
└── README.md
```

---

## 2. Key Features

- **Dedicated Trading Control Dashboard**: Real-time overview of Groww connection, account balance, available funds, configurable trading budget (₹100, ₹300, ₹400, custom), open position capital, and today's P/L.
- **Secure Single Groww Connection**: Initial 1-time credential setup with encrypted storage, daily session renewal (addressing Groww API daily token expiration), Disconnect/Switch Account safeguards, and strict account verification (`GROWW-ARUN-PRIMARY`) before every trade.
- **Pre-Trade Notification & 1-Tap Approval**: Every potential entry or exit dispatches an Android push notification with suggested investment, quantity, reason, risk, stop-loss, and target. Zero trades are submitted without explicit owner approval.
- **Rule-Based Profit Realization & Bank Withdrawal**: Realize trading gains automatically or via approval, with separate configurable rules for moving profits to your bank account while safeguarding invested principal.
- **Gemini 1.5 Pro AI Research Engine**: Multi-dimensional stock evaluation analyzing Technicals, Fundamentals, News & Events, Risk Profile, and Trade Evaluation with automated fallback tiers (`gemini-1.5-pro` -> `gemini-2.5-flash` -> `gemini-1.5-flash` -> Quantitative Model).
- **Multi-Provider Market Data Layer**: Real quotes and historical candles for Indian NSE and BSE stocks via Yahoo Finance, official Groww Trade API, and deterministic Test Simulated mode.
- **Transparent Quantitative Strategies**: Explicit rule confluences (Trend Momentum Breakout, Mean Reversion Pullback in Uptrend, MACD Bullish Crossover).
- **Paper Trading Engine & Safety Gates**: Track simulated positions, average buy prices, transaction fees (brokerage + STT + GST), and realized/unrealized P&L without risking real capital.
- **Android Push Notifications**: High-priority alert dispatch via Firebase Cloud Messaging (FCM) with cooldown deduplication.

---

## 3. Prerequisites

### Linux Workstation (Ubuntu / Debian / Fedora)
- **Python**: 3.10+ (tested on Python 3.12.3)
- **Git**
- **Java**: OpenJDK 17 or 21 (for Android builds)
- **Flutter SDK**: 3.19+ (optional for APK builds; pre-configured project files provided)
- **Docker & Docker Compose** (optional, for containerized PostgreSQL deployment)

---

## 4. Quick Start (Linux Workstation)

### Step 1: Clone & Configure Environment
```bash
cd /home/arun/personal-ai-stock
cp .env.example backend/.env
```
Edit `backend/.env` to configure your preferences. By default, it uses zero-configuration SQLite (`sqlite:///./stock_intel.db`) and Yahoo Finance (`MARKET_DATA_PROVIDER="yahoo"`).

### Step 2: Set Up Python Virtual Environment
```bash
cd /home/arun/personal-ai-stock/backend
python3 -m venv venv
./venv/bin/pip install --upgrade pip
./venv/bin/pip install -r requirements.txt
```

### Step 3: Run Automated Test Suite
```bash
cd /home/arun/personal-ai-stock/backend
PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 ./venv/bin/pytest tests -v
```
*All 20 tests pass verifying technical indicators, strategies, risk sizing, portfolio paper trading, and REST API endpoints.*

### Step 4: Start the Backend Server
```bash
cd /home/arun/personal-ai-stock
./scripts/run_backend.sh
```
The FastAPI backend will start on `http://0.0.0.0:8000`.
- **Interactive OpenAPI/Swagger Docs**: Open `http://localhost:8000/docs` in your browser.
- **Health Check**: `http://localhost:8000/api/v1/health`
- **Market Status**: `http://localhost:8000/api/v1/market-status`

---

## 5. Running a Manual Market Scan

You can trigger an immediate scan from the terminal:
```bash
cd /home/arun/personal-ai-stock
./backend/venv/bin/python scripts/run_scanner_manual.py
```
This utility:
1. Queries the NSE universe.
2. Downloads historical candles from Yahoo Finance.
3. Evaluates strategy confluences.
4. Calculates stop-loss and targets.
5. Displays actionable `BUY WATCH`, `HOLD`, and `SELL/EXIT WATCH` alerts on your terminal.

---

## 6. Mobile Application (Android Phone)

### Connecting Your Android Phone to the Linux Backend
When running on an Android phone, `localhost` refers to the phone itself, **not** your Linux computer.
1. Find your Linux workstation's local IP address on Wi-Fi:
   ```bash
   ip -br addr show | grep -E 'wlan0|wlp|eth0'
   # Example output: 192.168.1.105
   ```
2. In the Flutter App, navigate to **More > App Settings & LAN IP**.
3. Set the Backend Server URL to:
   ```
   http://192.168.1.105:8000
   ```
4. Tap **Save & Test** to confirm connectivity.

### Building the Android APK
On your Linux machine with Flutter SDK installed:
```bash
cd /home/arun/personal-ai-stock/mobile
flutter pub get
flutter build apk --release
```
The installable release APK will be generated at:
```
mobile/build/app/outputs/flutter-apk/app-release.apk
```

### Installing APK on Your Android Phone
1. Connect your Android phone to your Linux computer via USB with USB Debugging enabled:
   ```bash
   adb install -r mobile/build/app/outputs/flutter-apk/app-release.apk
   ```
2. Or transfer the `app-release.apk` file to your phone via Google Drive, WhatsApp, or local transfer, and tap the APK to install.

---

## 7. Firebase Cloud Messaging (FCM) Setup

1. Create a Firebase project at [https://console.firebase.google.com/](https://console.firebase.google.com/).
2. Add an Android app with package name `com.personal.aistock`.
3. Download `google-services.json` and place it in `mobile/android/app/google-services.json`.
4. In Firebase Console, go to **Project Settings > Service accounts > Generate new private key**.
5. Save the JSON file on your Linux machine and set its path in `backend/.env`:
   ```bash
   FCM_SERVICE_ACCOUNT_PATH="/home/arun/personal-ai-stock/backend/serviceAccountKey.json"
   ```
6. Test notification flow:
   ```bash
   ./backend/venv/bin/python scripts/test_notification.py
   ```

---

## 8. Groww Trade API Integration

1. Review official Groww documentation at [https://groww.in/trade-api/docs/](https://groww.in/trade-api/docs/).
2. Obtain your API Access Token from the Groww developer console.
3. Configure in `backend/.env`:
   ```bash
   GROWW_API_AUTH_TOKEN="your_jwt_auth_token"
   ```
4. For security, automated real-money order execution is disabled (`GROWW_ORDER_EXECUTION_ENABLED=false`). Use signals to manually execute trades in the Groww app, while synchronizing margins and open positions.

---

## 9. Docker Compose Deployment (Production)

To run the backend with a dedicated PostgreSQL database in Docker:
```bash
cd /home/arun/personal-ai-stock/deployment
docker-compose up -d
```
Inspect logs:
```bash
docker-compose logs -f backend
```
# personal_ai_stock
