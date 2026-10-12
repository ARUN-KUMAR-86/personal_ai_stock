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

### To Connect Your Groww Account:
1. Tap the **"Log In to Groww"** pill in the top app bar.
2. Enter your Groww API Key, Secret, and TOTP Key.
3. Choose whether to enable live order execution or remain in simulated mode.
4. Tap **Connect to Groww**. You can disconnect and revert to Paper Trading at any time with 1 tap.
