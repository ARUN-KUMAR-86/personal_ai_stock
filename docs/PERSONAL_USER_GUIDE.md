# Personal AI Stock Intelligence: Personal User Guide

Welcome to your personal AI Stock Intelligence system. This application is custom-built exclusively for your private trading decision-support on the Indian stock markets (NSE).

---

## 1. Quick APK Installation on Your Android Phone

The release binaries have been compiled and verified:

| File | Size | Recommended Device |
| :--- | :--- | :--- |
| **`app-arm64-v8a-release.apk`** | **~21.9 MB** | **All modern Android phones (Recommended)** |
| **`app-release.apk`** | **~52 MB** | Universal (compatible with any Android architecture) |

**Binaries Path:**  
[`mobile/build/app/outputs/flutter-apk/`](file:///home/arun/personal-ai-stock/mobile/build/app/outputs/flutter-apk/)

### Installation Methods:

#### Method A: Direct USB Installation via ADB
If your phone is connected to your computer with USB Debugging enabled:
```bash
adb install -r /home/arun/personal-ai-stock/mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

#### Method B: Transfer via Google Drive, Telegram, or USB Cable
1. Copy `app-arm64-v8a-release.apk` to your phone via USB cable or upload it to your Google Drive / Telegram Saved Messages.
2. Tap the `.apk` file on your phone.
3. If prompted by Android, enable **"Allow from this source"** in settings.
4. Tap **Install** and open **AI Stock Intel**.

---

## 2. Connecting the App to the Backend Server

When opening the app for the first time, go to the **Settings** tab (gear icon at the bottom right) to configure your server URL:

### Option 1: 24/7 Free Cloud Deployment (Recommended)
Deploy the backend using the included blueprints:
- **Render.com**: Push your repository to GitHub, link to Render using the included [`render.yaml`](file:///home/arun/personal-ai-stock/render.yaml).
- **Fly.io**: Run `fly launch` using the included [`fly.toml`](file:///home/arun/personal-ai-stock/fly.toml).
- Enter your cloud URL in Settings (e.g. `https://my-stock-intel.onrender.com`), then tap **Save & Test**.

### Option 2: Local Wi-Fi Network
If you want to run the backend on your laptop while on the same Wi-Fi as your phone:
1. Start the backend:
   ```bash
   cd /home/arun/personal-ai-stock/backend
   source venv/bin/activate
   uvicorn app.main:app --host 0.0.0.0 --port 8000
   ```
2. Find your laptop's local IP (e.g. `192.168.1.15`).
3. In the mobile app Settings, enter `http://192.168.1.15:8000` and tap **Save & Test**.

> [!NOTE]
> Do not use `localhost` or `127.0.0.1` on your phone, as those point to the phone itself.

---

## 3. Daily Trading Workflow

### 1. Market Monitoring & AI Scanner
- The scanner runs in the background every 15 minutes during market hours (09:15 to 15:30 IST).
- You can trigger an instant scan anytime by tapping the **"Scan Now"** button on the Dashboard or the radar icon in the Scanner.

### 2. Priority AI Opportunities & Investment Thesis
- When high-confidence confluence signals are generated, they appear at the top of your Dashboard under **"PRIORITY AI OPPORTUNITIES"**.
- Tap **"Review Opportunity & Enter Amount (₹)"** to view:
  - **4-Cell Technical Confluence Matrix**: Trend, momentum, volume profile, and ATR volatility.
  - **AI Investment Thesis**: Narrative explanation, upcoming catalysts, and key risk factors.
  - **Re-analyze Button**: On-demand thesis refresh against current market data.

### 3. Star-Marked Watchlist
- Tap the ⭐ icon next to any stock in the Scanner, or in the top-right corner of the stock detail view, to pin it to your persistent watchlist.
- On your Dashboard, your curated watchlist appears as a horizontal scroll with real-time quotes, latest signals, and a 1-tap **"Scan Watchlist"** button.

### 4. Risk-First Order Calculation
- Enter your intended investment capital (e.g., ₹10,000).
- The system automatically:
  - Calculates whole shares only (no fractional shares).
  - Deducts exact Indian roundtrip regulatory charges (STT, NSE turnover, SEBI charges, GST, DP fees).
  - Computes net profit target and maximum downside risk.
  - Provides a **🎯 AI 2% Sizing** quick-chip that auto-calculates the optimal share quantity strictly within your 2% capital risk rule.

### 5. Mandatory Manual Confirmation (Zero Auto-Buy)
- Automated buying is permanently disabled in the backend codebase for your safety.
- Tapping **"Review & Confirm Buy Order"** opens a verification sheet displaying the verified live quote and slippage check.
- You must explicitly tap **"Confirm Order"** to execute.

### 6. Automated Position Monitoring & Safe Exits
- Once placed, positions are tracked automatically with:
  - Real-time Stop-Loss alerts.
  - Profit Target notifications.
  - 48-Hour holding period deadline reminders.
- **Auto-Selling**: Configurable in Settings (opt-in). By default, positions remain open and notify you first so you have the final manual decision.
- **Emergency Kill Switch**: Available at the top of Settings to immediately halt all new trading with a single toggle.

---

## 4. Paper Trading vs Groww Live Execution

| Mode | Safety Status | Execution Target |
| :--- | :--- | :--- |
| **Paper Trading (Default)** | 🛡️ Safe Sandbox | Simulated in local SQLite database with ₹1,00,000 virtual balance. Zero financial risk. |
| **Groww Live Trading** | 🟢 Live Broker | Routes orders through official Groww Trade API with TOTP authentication. |

---

## 5. Connecting Groww Securely (Section 2)

Your app connects to Groww once during initial setup rather than asking you to re-type credentials every time you launch the app:

### Session Lifecycle & Daily Expiry
- **First Connection**: Enter your Groww API Key, Secret, and TOTP Seed once. The credentials are encrypted and saved securely.
- **Normal App Use**: The backend reuses the saved connection while it remains valid.
- **Daily Expiry (Groww API Policy)**: In accordance with Indian exchange and Groww security requirements, access tokens expire daily at 06:00 IST (~18-hour session).
- **1-Tap Renewal**: When your session expires, a gold `Expired (Renew)` pill appears. Tap **"Renew Session"** on the Trading Control screen to generate a fresh token instantly without typing your passwords.
- **Disconnect / Switch Account**: If you ever want to log out or trade on a different account, tap **"Switch Account"**. This invalidates stored credentials and locks all live trading immediately.

> [!CAUTION]
> **Account Protection & Anti-Account-Switching**:
> To guarantee that your app never silently switches to another person's Groww account or uses their funds, the app performs a strict account verification check before **every single real trade**:
> - Authorized Account: `GROWW-ARUN-PRIMARY` (Arun Kumar)
> - If an unauthorized Groww account ID is detected, trade execution is **aborted immediately** with an explicit error.

---

## 6. Dedicated Trading Control Screen (Section 3)

Accessible directly via the bottom navigation bar under **"Trading"** and from the hero dashboard card:

```text
PERSONAL AI STOCK
──────────────────────────
Groww Account       Connected*
Account Balance     ₹1,000
Available Funds     ₹1,000
Trading Budget      ₹300
Amount in Positions ₹0
Today's P/L         ₹0

[ Start Trading ]   [ Stop Trading ]

Trading Mode:
  ● Notification + Approval

Maximum Amount Per Trade: ₹100
Daily Loss Limit:         ₹50
Auto-Withdraw Profits:    OFF

[ Account Activity ]
[ Buy/Sell Notifications ]
[ Deposit/Withdrawal History ]
──────────────────────────
```

### Trading Control Breakdown:
- **Groww Account**: Live broker connection status (`Connected*`, `Expired (Renew)`, `Disconnected`).
- **Account Balance & Available Funds**: Real-time margin and cash balances fetched directly from Groww API.
- **Trading Budget (₹100, ₹300, ₹400, or Custom)**:
  > [!IMPORTANT]
  > Choosing ₹300 as your trading budget does **NOT** deposit ₹300 into Groww or withdraw anything from your bank. It sets an internal safety cap on how much capital the app is permitted to allocate to trades.
  > The app strictly distinguishes between your actual Groww balance, the trading budget, capital invested in open positions, and profit or loss.
- **Amount in Positions**: Real capital currently committed to open positions.
- **Today's P/L**: Live aggregated profit and loss (realized profits + unrealized mark-to-market).
- **Start Trading**: Activates the automated scanning and AI trade alert generator.
- **Stop Trading**: Halts new trade signal generation immediately while safely monitoring existing open positions.
- **Maximum Amount Per Trade**: Defaults to ₹100 per position (protects against concentration risk).
- **Daily Loss Limit**: Defaults to ₹50 daily max drawdown. If reached, new trade proposals are halted for the day.
- **Account Activity & Deposit/Withdrawal History**: Logs all real and recorded fund events without ever misrepresenting simulated figures as real bank transfers.

---

## 7. Trade Alert Notification & Pre-Trade Approval (Section 4)

Your workflow is **100% notification-first and approval-gated**. No trade is ever placed without your explicit manual tap.

### Standard Trade Alert Format:
```text
PERSONAL AI STOCK — TRADE ALERT

Stock: RELIANCE
Action: BUY
Suggested investment: ₹100
Estimated quantity: 1 share
Estimated order value: ₹100
Reason: Technical breakout above 20 EMA with bullish MACD cross
Risk: Medium
Stop-loss: ₹2,910
Target: ₹3,080

[ APPROVE BUY ]  [ REJECT ]
```

### End-to-End Execution Sequence:
1. **AI Opportunity Identification**: Background scanner and Gemini AI identify a high-confluence setup.
2. **Push Notification Dispatched**: Your Android phone receives a high-priority push alert with the proposed stock, action, quantity, stop-loss, and target.
3. **Owner Review & 1-Tap Action**:
   - Tap **[ APPROVE BUY ]** to execute.
   - Tap **[ REJECT ]** to dismiss. No trade is placed.
4. **Broker Verification**: The order is submitted to Groww API. The app actively verifies the broker order status (`FILLED`, `REJECTED`, or `PENDING`) rather than assuming immediate success.
5. **Post-Trade Confirmation**: Your phone receives a confirmation alert with actual executed price, updated funds, and risk parameters.

---

## 8. Automatic Profit Management & Bank Withdrawals (Section 5)

There is a critical distinction between **realizing profit** and **withdrawing money to your bank**:

1. **Automatic Sell (Position Exit)**:
   - When a stock reaches its target profit level or an exit signal occurs, the app sends a **SELL Trade Alert**.
   - Upon your approval (or optional auto-exit setting), the position is closed in Groww, locking in your realized gains.
2. **Broker Bank Withdrawal**:
   - Moving cash from Groww to your linked bank account is an external banking transaction subject to broker clearance and banking settlement (T+1 settlement for Indian equities).
   - The app allows you to set an **Auto-Withdraw Profits Rule** (e.g., consider withdrawing realized profits above ₹100).
   - The app verifies whether settled withdrawable funds are available in Groww and asks for your explicit confirmation before requesting any withdrawal. It will **never** withdraw money that is still invested in positions or touch your retained base capital.

---

## 9. Google Gemini AI Pro Research Engine (Section 6)

The app integrates Google's flagship **Gemini 1.5 Pro** model to perform institutional-grade stock evaluations.

### 5 Research Dimensions:
1. **Technical Analysis**: Price trends (20/50/200 EMAs), momentum (RSI), relative volume (RVOL), ATR volatility, and support/resistance levels.
2. **Fundamental Analysis**: Revenue growth, earnings consistency, valuation multiples (P/E, P/B), and debt-to-equity health.
3. **News & Events**: Corporate announcements, quarterly results, sector news, and macroeconomic catalysts.
4. **Risk Analysis**: Downside exposure, beta volatility, position sizing compliance, and invalidation criteria.
5. **Trade Evaluation**: Expected risk-to-reward ratio, slippage, transaction cost estimates (STT, GST, SEBI charges), and optimal entry/exit price levels.

### Gemini API vs Google AI Pro Subscription:
> [!NOTE]
> Having a consumer **Google AI Pro subscription** does not automatically grant free programmatic Gemini API tokens. The Gemini API is accessed via [Google AI Studio / Google Cloud Vertex AI](https://ai.google.dev).
> The app is built with a resilient multi-tier fallback architecture:
> 1. `gemini-1.5-pro` (Primary deep reasoning)
> 2. `gemini-2.5-flash` (High-speed secondary fallback)
> 3. `gemini-1.5-flash` (Cost-efficient tertiary fallback)
> 4. Deterministic Quantitative Analysis Engine (Ensures 100% uptime even when offline or during API rate limits).

---

## 10. Active Automation Mode: Option B (Hybrid Guard)

Arun has selected **Option B (Hybrid Guard)** as the operational trading automation mode:

| Dimension | Policy Under Option B | Mechanism |
| :--- | :--- | :--- |
| **Buy Orders** | **100% Manual 1-Tap Approval** | Every trade alert requires you to tap **`[ APPROVE BUY ]`**. Zero automated buys permitted. |
| **Normal Profit Exits** | **Manual 1-Tap Approval** | Profit targets send a **SELL Trade Alert** with **`[ APPROVE SELL ]`** / **`[ REJECT ]`**. |
| **Stop-Loss Breach** | **Automated Stop-Loss Exit** | If market price drops through your hard stop-loss (`curr_price <= stop_loss`), the app immediately executes the exit order via Groww and dispatches a high-priority **`HYBRID GUARD: AUTO STOP-LOSS EXECUTED`** notification. |
| **Capital Protection** | **Crash & Absence Shield** | Protects your capital against rapid market down-moves even if you are away from your phone, in a meeting, or without connectivity. |

> [!TIP]
> **Switching Modes Anytime**:
> You can view or change your active mode anytime directly on the **Trading Control** screen by tapping on the **Trading Mode** row (`Option B: Hybrid Guard (Auto Stop-Loss)`).

