# Groww Trade API Integration Guide

## 1. Overview & Verification

Groww provides an official developer ecosystem via **Groww Trade API** (documented at [https://groww.in/trade-api/docs/](https://groww.in/trade-api/docs/)) and a companion Python SDK package (`growwapi`).

This system implements a modular adapter pattern (`app/brokers/groww_adapter.py`) adhering strictly to official API capabilities.

---

## 2. Authentication Requirements

Groww Trade API requires one of the following authentication flows:

1. **Daily Access Token Flow:**
   - Generated via Groww Trade API developer portal.
   - Set in `.env`: `GROWW_API_AUTH_TOKEN="your_jwt_auth_token"`
   - Tokens expire daily as mandated by Indian SEBI exchange guidelines.

2. **API Key & Secret + TOTP Flow:**
   - Requires API Key, API Secret, and TOTP secret key for automatic session renewal.
   - Configuration:
     ```bash
     GROWW_API_KEY="your_api_key"
     GROWW_API_SECRET="your_api_secret"
     GROWW_TOTP_KEY="your_totp_secret_seed"
     ```
   - Handled via `pyotp.TOTP(settings.GROWW_TOTP_KEY)`.

---

## 3. Supported Endpoints & Operations

| Feature | Method / Endpoint | System Support |
| :--- | :--- | :--- |
| **Market Quotes (LTP)** | `GrowwAPI.get_quote(...)` | Enabled (`is_live=True`) |
| **Historical Candles** | `GrowwAPI.get_historical_candles(...)` | Enabled |
| **Available Margins/Funds**| `GrowwAPI.get_margin()` | Enabled (`/api/v1/funds`) |
| **Account Holdings** | `GrowwAPI.get_holdings()` | Enabled (`/api/v1/groww/holdings`) |
| **Open Positions** | `GrowwAPI.get_positions()` | Enabled (`/api/v1/groww/positions`) |
| **Order Placement** | `GrowwAPI.place_order(...)` | **Disabled by Default (Safety)** |

---

## 4. Manual-Trading-First Safety Architecture

> [!IMPORTANT]
> **Real money automated order execution is disabled by default.**
> 
> In accordance with sound risk engineering:
> 1. The scanner and strategies generate actionable notifications.
> 2. The owner reviews the signal, entry criteria, stop-loss, and target levels.
> 3. The owner executes the trade manually inside the official Groww mobile app or web platform.
> 4. The backend synchronizes open positions and margins via authorized read-only API access.
> 
> To enable automated execution, you must explicitly set `GROWW_ORDER_EXECUTION_ENABLED=true` in `.env`.

---

## 5. Fallback & Unconfigured Behavior

If Groww API credentials are not provided:
- The system **never crashes**.
- The market data provider gracefully uses `YahooMarketDataProvider` (delayed quotes for NSE/BSE) or `MockMarketDataProvider`.
- The Funds screen displays `Broker: GROWW (UNCONFIGURED)` with instructions on how to set credentials.
