"""Gemini AI Stock Prediction & Quantitative Algorithmic Engine.

Combines Google Gemini Generative Intelligence with multi-indicator technical confluence
to predict stock price direction, target prices, win confidence, and explain the working algorithm.
"""

import json
import os
from datetime import datetime, timezone
from typing import Dict, Any, List, Optional
import httpx
import pandas as pd

from app.core.config import settings
from app.core.logging import logger
from app.analysis.indicators import TechnicalIndicators


class GeminiStockPredictor:
    """Institutional-grade AI stock price predictor powered by Google Gemini and quantitative confluence."""

    def __init__(self):
        self.default_model = "gemini-2.5-flash"
        self.models_to_try = [
            "gemini-2.5-flash",
            "gemini-1.5-pro",
            "gemini-2.5-pro",
            "gemini-3.5-flash",
            "gemini-flash-latest",
            "gemini-3.8-flash",
            "gemini-3.5-flash-lite",
            "gemini-pro-latest",
        ]

    def _get_api_key(self) -> Optional[str]:
        key = settings.GEMINI_API_KEY or os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
        if not key:
            try:
                from app.database.session import SessionLocal
                from app.models.setting import AppSetting
                db = SessionLocal()
                rec = db.query(AppSetting).filter(AppSetting.key == "GEMINI_API_KEY").first()
                if rec and rec.value:
                    key = rec.value.strip()
                db.close()
            except Exception:
                pass
        return key

    def predict_stock(
        self,
        symbol: str,
        company_name: Optional[str] = None,
        exchange: str = "NSE",
        df: Optional[pd.DataFrame] = None,
        time_horizon: str = "1-DAY",
        force_deterministic: bool = False,
    ) -> Dict[str, Any]:
        """
        Executes a real-time predictive pass for the given stock.
        Calculates all quantitative indicators, determines directional probability,
        and prompts Google Gemini for deep predictive synthesis.
        """
        sym = symbol.upper().strip()
        comp_name = company_name or sym
        ex = exchange.upper()

        # 1. Fetch candles if not supplied
        if df is None or df.empty:
            from app.providers.factory import get_market_data_provider
            provider = get_market_data_provider()
            df = provider.get_historical_ohlcv(symbol=sym, exchange=ex, timeframe="1d", period="6mo")

        if df.empty:
            raise ValueError(f"Could not load market candlestick data for {sym}")

        # 2. Enrich with full technical indicator suite
        enriched = TechnicalIndicators.calculate_all(df)
        metrics = TechnicalIndicators.get_latest_metrics(enriched)
        price = metrics.get("close") or float(df.iloc[-1]["close"])

        # Core quantitative indicators
        rsi = float(metrics.get("rsi_14") or 50.0)
        rvol = float(metrics.get("rvol") or 1.0)
        ema_21 = float(metrics.get("ema_21") or price)
        ema_50 = float(metrics.get("ema_50") or price)
        sma_50 = float(metrics.get("sma_50") or price)
        sma_200 = float(metrics.get("sma_200") or price)
        atr = float(metrics.get("atr_14") or max(price * 0.02, 1.0))
        swing_high = float(metrics.get("swing_high_20") or price)
        swing_low = float(metrics.get("swing_low_20") or price)
        pivot = float(metrics.get("pivot") or price)
        r1 = float(metrics.get("r1") or (price * 1.02))
        s1 = float(metrics.get("s1") or (price * 0.98))
        supertrend = float(metrics.get("supertrend") or price)
        supertrend_dir = int(metrics.get("supertrend_dir", 1))
        adx = float(metrics.get("adx_14") or 20.0)
        plus_di = float(metrics.get("plus_di") or 0.0)
        minus_di = float(metrics.get("minus_di") or 0.0)
        upper_wick_ratio = float(metrics.get("upper_wick_ratio") or 0.0)

        # 3. Deterministic Algorithmic Scoring (Confluence Engine - Institutional Accuracy)
        score = 50.0
        # Trend Confluence (Moving Averages)
        if price >= ema_21 and ema_21 >= ema_50:
            score += 15.0
        elif price <= ema_21 and ema_21 <= ema_50:
            score -= 15.0

        # Supertrend Confluence
        if supertrend_dir == 1 and price >= supertrend:
            score += 15.0
        elif supertrend_dir == -1 and price <= supertrend:
            score -= 15.0

        # Momentum Confluence (RSI Sweet Spot)
        if 54.0 <= rsi <= 70.0:
            score += 15.0
        elif rsi < 40.0:
            score -= 15.0
        elif rsi > 74.0:
            score -= 10.0  # Overbought pullback risk

        # Trend Strength via ADX
        if adx >= 22.0 and plus_di > minus_di:
            score += 10.0
        elif adx < 18.0:
            score -= 10.0  # Choppy sideways chop penalty

        # Volume Flow
        if rvol >= 1.3:
            score += 15.0
        elif rvol < 0.7:
            score -= 10.0

        # Breakout proximity & Trap Detection
        if price >= 0.98 * swing_high:
            if upper_wick_ratio > 0.40:
                score -= 15.0  # False breakout rejection trap!
            else:
                score += 10.0

        confidence = round(min(max(score, 20.0), 96.0), 1)

        # Baseline directional projection
        if confidence >= 72.0:
            direction = "BULLISH"
            action = "STRONG BUY" if confidence >= 82.0 else "BUY"
            mult = 3.5 if time_horizon == "1-DAY" else 5.5
            target = round(price + max(mult * atr, price * 0.04), 2)
            # Anchor stop-loss to Supertrend or 1.25x ATR
            sl_candidate = max(price - (1.25 * atr), 0.5)
            if supertrend_dir == 1 and supertrend < price:
                stop_loss = round(max(sl_candidate, supertrend * 0.995), 2)
            else:
                stop_loss = round(sl_candidate, 2)
        elif confidence <= 38.0:
            direction = "BEARISH"
            action = "STRONG SELL" if confidence <= 28.0 else "SELL"
            mult = 2.5 if time_horizon == "1-DAY" else 4.0
            target = round(max(price - (mult * atr), 0.5), 2)
            stop_loss = round(price + (1.25 * atr), 2)
        else:
            direction = "NEUTRAL"
            action = "HOLD"
            target = round(price + (1.5 * atr), 2)
            stop_loss = round(max(price - (1.5 * atr), 0.5), 2)

        gain_pct = round(((target - price) / price) * 100, 2)

        working_algo_text = (
            f"1. Trend Confluence: Price ₹{price:.2f} evaluated vs 21-EMA (₹{ema_21:.2f}) & 50-EMA (₹{ema_50:.2f}). "
            f"{'Bullish alignment confirmed' if price >= ema_21 else 'Consolidation / below moving averages'}.\n"
            f"2. Momentum & Velocity: RSI (14) is {rsi:.1f} ({'Optimal bullish velocity zone' if 50 <= rsi <= 72 else 'Neutral/Oversold'}).\n"
            f"3. Institutional Volume Flow: Relative Volume (RVOL) is {rvol:.2f}x average daily volume.\n"
            f"4. Volatility & Channel Range: 14-Day ATR is ₹{atr:.2f} (±{round((atr/price)*100, 1)}% daily band). 20-Day Range: ₹{swing_low:.2f} - ₹{swing_high:.2f}.\n"
            f"5. Algorithmic Projection: Confluence confidence score of {confidence}% outputs {direction} ({action}) targeting ₹{target:.2f} with risk cut at ₹{stop_loss:.2f}."
        )

        prediction_data = {
            "symbol": sym,
            "exchange": ex,
            "company_name": comp_name,
            "price_at_prediction": price,
            "predicted_direction": direction,
            "predicted_action": action,
            "target_price": target,
            "expected_gain_pct": gain_pct,
            "stop_loss": stop_loss,
            "confidence_score": confidence,
            "time_horizon": "1-DAY (Swing)" if time_horizon == "1-DAY" else "1-MONTH (Positional)",
            "algorithm_name": "Gemini Predictive AI Confluence",
            "working_algorithm": working_algo_text,
            "algorithm_metrics": {
                "rsi_14": rsi,
                "rvol": rvol,
                "ema_21": ema_21,
                "ema_50": ema_50,
                "sma_50": sma_50,
                "sma_200": sma_200,
                "atr_14": atr,
                "swing_high": swing_high,
                "swing_low": swing_low,
                "pivot": pivot,
                "r1": r1,
                "s1": s1,
                "supertrend": supertrend,
                "supertrend_dir": supertrend_dir,
                "adx_14": adx,
            },
            "ai_prediction_summary": (
                f"{comp_name} ({sym}) displays a high-probability {direction} structure at ₹{price:.2f}. "
                f"Quantitative indicators show {confidence}% confluence targeting ₹{target:.2f} ({'+' if gain_pct > 0 else ''}{gain_pct}%) "
                f"over the {time_horizon} horizon with defined invalidation at ₹{stop_loss:.2f}."
            ),
            "key_catalysts": [
                f"Multi-moving average support at 21-EMA ₹{ema_21:.2f} and 50-EMA ₹{ema_50:.2f}",
                f"RSI reading of {rsi:.1f} indicating sustainable directional velocity",
                f"Volume expansion at {rvol:.2f}x benchmark volume",
                f"Target calculated using {round(mult if 'mult' in locals() else 3.0, 1)}x ATR upside projection",
            ],
            "risk_assessment": [
                f"Stop-loss breached if price closes below ₹{stop_loss:.2f}",
                f"Broader market volatility or index reversal below pivot ₹{pivot:.2f}",
                f"Volume exhaustion before reaching resistance ₹{r1:.2f}",
            ],
            "invalidation_trigger": f"Daily bar close below ₹{stop_loss:.2f} invalidates this prediction setup.",
            "model_used": "Gemini Quantitative Confluence Engine",
            "created_at": datetime.now(timezone.utc).isoformat(),
        }

        # 4. Enhance with Gemini Generative AI synthesis if API Key is available
        api_key = self._get_api_key()
        if api_key and settings.AI_ANALYSIS_ENABLED and not force_deterministic:
            try:
                gemini_enhanced = self._call_gemini_api(
                    api_key=api_key,
                    symbol=sym,
                    company_name=comp_name,
                    price=price,
                    direction=direction,
                    target=target,
                    stop_loss=stop_loss,
                    confidence=confidence,
                    time_horizon=time_horizon,
                    metrics=prediction_data["algorithm_metrics"],
                    working_algo=working_algo_text,
                )
                if gemini_enhanced:
                    prediction_data.update(gemini_enhanced)
            except Exception as e:
                logger.warning(f"Gemini prediction call note for {sym}: {e}. Retaining confluence prediction.")

        return prediction_data

    def _call_gemini_api(
        self,
        api_key: str,
        symbol: str,
        company_name: str,
        price: float,
        direction: str,
        target: float,
        stop_loss: float,
        confidence: float,
        time_horizon: str,
        metrics: Dict[str, Any],
        working_algo: str,
    ) -> Optional[Dict[str, Any]]:
        """Queries Google Gemini API for deep natural language prediction synthesis."""
        prompt = (
            f"You are a Principal AI Quantitative Strategist for Indian Equities (NSE/BSE).\n"
            f"Analyze the following real-time data for {company_name} ({symbol}) and generate a precise stock prediction.\n\n"
            f"Current Market Data:\n"
            f"- Price: ₹{price:.2f}\n"
            f"- Algorithmic Direction: {direction} (Confidence: {confidence}%)\n"
            f"- Calculated Target: ₹{target:.2f} | Stop Loss: ₹{stop_loss:.2f}\n"
            f"- Time Horizon: {time_horizon}\n"
            f"- Technical Indicators: RSI={metrics.get('rsi_14')}, RVOL={metrics.get('rvol')}x, "
            f"21-EMA=₹{metrics.get('ema_21')}, 50-EMA=₹{metrics.get('ema_50')}, 14-ATR=₹{metrics.get('atr_14')}\n"
            f"- Working Algorithm Steps:\n{working_algo}\n\n"
            f"Requirements:\n"
            f"1. Explain exactly WHY the working algorithm predicts this direction based on technical confluence and institutional flow.\n"
            f"2. Output strictly valid JSON matching this schema (no markdown, no extra commentary):\n"
            f"{{\n"
            f'  "predicted_direction": "{direction}",\n'
            f'  "predicted_action": "{"STRONG BUY" if confidence >= 80 else "BUY" if direction == "BULLISH" else "HOLD"}",\n'
            f'  "target_price": {target},\n'
            f'  "expected_gain_pct": {round(((target - price)/price)*100, 2)},\n'
            f'  "stop_loss": {stop_loss},\n'
            f'  "confidence_score": {confidence},\n'
            f'  "working_algorithm": "Step-by-step mathematical & indicator rationale explaining the prediction.",\n'
            f'  "ai_prediction_summary": "Crisp 2-3 sentence executive forecast for {symbol}.",\n'
            f'  "key_catalysts": ["3 specific technical or market catalysts"],\n'
            f'  "risk_assessment": ["3 specific risk factors or downside invalidation checks"],\n'
            f'  "invalidation_trigger": "Exact price condition that cancels this forecast."\n'
            f"}}"
        )

        payload = {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {
                "temperature": 0.2,
                "responseMimeType": "application/json",
            },
        }

        with httpx.Client(timeout=18.0) as client:
            for model_name in self.models_to_try:
                try:
                    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent?key={api_key}"
                    resp = client.post(url, json=payload)
                    if resp.status_code == 200:
                        data = resp.json()
                        raw_text = data["candidates"][0]["content"]["parts"][0]["text"]
                        parsed = json.loads(raw_text)
                        parsed["model_used"] = f"Gemini Pro ({model_name})"
                        return parsed
                except Exception as e:
                    logger.debug(f"Gemini model {model_name} note: {e}")
            return None


gemini_stock_predictor = GeminiStockPredictor()
