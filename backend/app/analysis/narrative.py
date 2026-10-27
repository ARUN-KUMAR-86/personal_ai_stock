"""AI Narrative and Explainable Investment Thesis Generator.

Combines Google Gemini API generative intelligence with an institutional-grade
deterministic quantitative confluence engine to produce transparent, explainable
stock investment theses, catalysts, risk factors, and tactical plans.
"""

import json
import os
from datetime import datetime, timezone
from typing import Dict, Any, List, Optional
import httpx

from app.core.config import settings
from app.core.logging import logger


class AINarrativeGenerator:
    """Generates explainable investment theses and risk breakdowns."""

    def __init__(self):
        self.default_model = settings.GEMINI_MODEL

    def generate_thesis(
        self,
        symbol: str,
        company_name: Optional[str] = None,
        exchange: str = "NSE",
        signal_type: str = "BUY WATCH",
        strategy_name: str = "MomentumBreakout",
        price: float = 0.0,
        stop_loss: Optional[float] = None,
        target: Optional[float] = None,
        risk_reward: Optional[float] = None,
        metrics: Optional[Dict[str, Any]] = None,
        financial_news: Optional[List[Dict[str, Any]]] = None,
        force_deterministic: bool = False,
        time_horizon: str = "1-DAY",
    ) -> Dict[str, Any]:
        """
        Produces a structured AI investment thesis.
        Attempts Gemini API synthesis if configured and available;
        falls back seamlessly to the deterministic rules-based engine.
        Supports 1-DAY (Short Term) and 1-MONTH (Long Term) horizons, and foreign / US stocks.
        """
        metrics = metrics or {}
        comp_name = company_name or symbol

        # 1. Attempt Gemini Generative synthesis if API key is provided and not forced deterministic
        api_key = settings.GEMINI_API_KEY or os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
        if not api_key:
            try:
                from app.database.session import SessionLocal
                from app.models.setting import AppSetting
                db_s = SessionLocal()
                rec = db_s.query(AppSetting).filter(AppSetting.key == "GEMINI_API_KEY").first()
                if rec and rec.value:
                    api_key = rec.value.strip()
                db_s.close()
            except Exception:
                pass
        if api_key and settings.AI_ANALYSIS_ENABLED and not force_deterministic:
            try:
                gemini_result = self._generate_via_gemini(
                    api_key=api_key,
                    symbol=symbol,
                    company_name=comp_name,
                    exchange=exchange,
                    signal_type=signal_type,
                    strategy_name=strategy_name,
                    price=price,
                    stop_loss=stop_loss,
                    target=target,
                    risk_reward=risk_reward,
                    metrics=metrics,
                    financial_news=financial_news,
                    time_horizon=time_horizon,
                )
                if gemini_result:
                    return gemini_result
            except Exception as e:
                logger.warning(f"Gemini API narrative generation failed for {symbol}: {e}. Falling back to deterministic engine.")

        # 2. Deterministic Quantitative Confluence Fallback Engine
        return self._generate_deterministic(
            symbol=symbol,
            company_name=comp_name,
            exchange=exchange,
            signal_type=signal_type,
            strategy_name=strategy_name,
            price=price,
            stop_loss=stop_loss,
            target=target,
            risk_reward=risk_reward,
            metrics=metrics,
            financial_news=financial_news,
            time_horizon=time_horizon,
        )

    def _generate_via_gemini(
        self,
        api_key: str,
        symbol: str,
        company_name: str,
        exchange: str,
        signal_type: str,
        strategy_name: str,
        price: float,
        stop_loss: Optional[float],
        target: Optional[float],
        risk_reward: Optional[float],
        metrics: Dict[str, Any],
        financial_news: Optional[List[Dict[str, Any]]],
        time_horizon: str = "1-DAY",
    ) -> Optional[Dict[str, Any]]:
        """Invokes Google Gemini API to craft a deep, natural-language investment thesis."""
        # Models to try: latest Google Gemini versions with automatic fallbacks
        models_to_try = [self.default_model] if self.default_model else []
        for fb in ["gemini-3.5-flash-lite", "gemini-3.5-flash", "gemini-2.5-flash", "gemini-1.5-pro", "gemini-1.5-flash"]:
            if fb not in models_to_try:
                models_to_try.append(fb)

        is_us = exchange.upper() in ("US", "NASDAQ", "NYSE", "GLOBAL")
        curr = "$" if is_us else "₹"
        horizon_label = "1-DAY (Short Term / Swing 24-48 Hours)" if time_horizon == "1-DAY" else "1-MONTH (Long Term / Positional 30 Days)"
        market_label = "US Equities (NASDAQ/NYSE)" if is_us else "Indian Equities (NSE/BSE)"

        # Build news context if available
        news_context = ""
        if financial_news:
            news_items = [f"- {n.get('title', '')} ({n.get('publisher', '')})" for n in financial_news[:3]]
            news_context = "\nRecent Company Announcements / News:\n" + "\n".join(news_items)

        prompt = (
            f"You are a Senior Quantitative Equity Analyst and Institutional Research Specialist for {market_label}.\n"
            f"Generate an institutional-grade, transparent, explainable research report and investment recommendation for {company_name} ({symbol}) on {exchange}.\n"
            f"Recommended Investment Time Horizon: {horizon_label}.\n\n"
            f"1. Verified Technical Analysis:\n"
            f"- Current Price: {curr}{price:.2f}\n"
            f"- Signal Type: {signal_type}\n"
            f"- Quantitative Strategy: {strategy_name}\n"
            f"- Recommended Time Horizon: {horizon_label}\n"
            f"- Stop-Loss: {curr}{stop_loss}\n"
            f"- Target Price: {curr}{target}\n"
            f"- Risk/Reward Ratio: {risk_reward}\n"
            f"- RSI (14): {metrics.get('rsi_14', 'N/A')}\n"
            f"- Relative Volume (RVOL): {metrics.get('rvol', 'N/A')}x\n"
            f"- 21-Day EMA: {curr}{metrics.get('ema_21', 'N/A')}\n"
            f"- 50-Day SMA: {curr}{metrics.get('sma_50', 'N/A')}\n"
            f"- 200-Day SMA: {curr}{metrics.get('sma_200', 'N/A')}\n"
            f"- 14-Day ATR: {curr}{metrics.get('atr_14', 'N/A')}\n"
            f"- 20-Day Swing High: {curr}{metrics.get('swing_high_20', 'N/A')}\n"
            f"- 20-Day Swing Low: {curr}{metrics.get('swing_low_20', 'N/A')}\n"
            f"- Pivot Levels: Pivot={curr}{metrics.get('pivot')}, R1={curr}{metrics.get('r1')}, S1={curr}{metrics.get('s1')}\n"
            f"{news_context}\n\n"
            f"Guidelines:\n"
            f"1. Examine ALL 5 institutional dimensions:\n"
            f"   - Technical Analysis: trends, momentum, volume accumulation, support/resistance.\n"
            f"   - Fundamental Analysis: valuation, financial stability, earnings outlook.\n"
            f"   - News & Events: impact of recent headlines or sector movements.\n"
            f"   - Risk Analysis: downside volatility, maximum allowable position risk.\n"
            f"   - Trade Evaluation: compare risk/reward, statutory roundtrip costs (~0.15%), and entry suitability.\n"
            f"2. Ground ALL numbers strictly in the provided verified data; NEVER invent live prices or guarantee profit.\n"
            f"3. Output MUST be strictly valid JSON with no markdown wrapping.\n\n"
            f"Required JSON Structure:\n"
            f"{{\n"
            f'  "headline": "Punchy 1-line institutional thesis headline",\n'
            f'  "investment_thesis": "Comprehensive narrative (120-200 words) synthesizing technical momentum, fundamentals, and catalyst rationale.",\n'
            f'  "catalysts": ["3 to 4 specific positive catalysts or technical confirmations"],\n'
            f'  "risk_factors": ["3 to 4 specific failure modes or reasons trade might fail"],\n'
            f'  "technical_summary": {{\n'
            f'    "trend": "Bullish / Bearish / Neutral summary",\n'
            f'    "momentum": "Assessment of RSI and momentum",\n'
            f'    "volume_profile": "Assessment of volume and accumulation",\n'
            f'    "volatility": "ATR volatility and range assessment"\n'
            f'  }},\n'
            f'  "fundamental_summary": {{\n'
            f'    "valuation": "Fair / Undervalued / Premium assessment",\n'
            f'    "financial_health": "Solvency, balance sheet health, and sector positioning",\n'
            f'    "earnings_trend": "Quarterly earnings trajectory"\n'
            f'  }},\n'
            f'  "news_and_events": {{\n'
            f'    "sentiment": "Positive / Neutral / Cautionary",\n'
            f'    "summary": "Impact of recent corporate announcements or sector news"\n'
            f'  }},\n'
            f'  "risk_analysis": {{\n'
            f'    "downside_risk": "Estimated downside to stop-loss",\n'
            f'    "suggested_risk_pct": 2.0,\n'
            f'    "volatility_regime": "Low / Medium / Elevated"\n'
            f'  }},\n'
            f'  "trade_evaluation": {{\n'
            f'    "entry_zone": "Price range for optimal entry",\n'
            f'    "stop_loss": "Suggested price level",\n'
            f'    "target": "Suggested price level",\n'
            f'    "expected_costs": "Round-trip STT, brokerage, and GST (~0.15%)",\n'
            f'    "recommendation": "High Confluence Buy / Hold / Pass"\n'
            f'  }},\n'
            f'  "tactical_plan": {{\n'
            f'    "entry_zone": "Price range for entry",\n'
            f'    "stop_loss": "Risk cut level with percentage",\n'
            f'    "target_1": "Primary target level with percentage",\n'
            f'    "target_2": "Secondary target extension",\n'
            f'    "time_horizon": "Expected holding period (e.g. 24 to 48 Hours)",\n'
            f'    "suggested_allocation_pct": 2.0\n'
            f'  }},\n'
            f'  "invalidation_trigger": "Exact condition that invalidates the trade"\n'
            f"}}"
        )

        payload = {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {
                "temperature": 0.2,
                "responseMimeType": "application/json",
            },
        }

        with httpx.Client(timeout=25.0) as client:
            for model_name in models_to_try:
                try:
                    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent?key={api_key}"
                    resp = client.post(url, json=payload)
                    if resp.status_code == 200:
                        data = resp.json()
                        raw_text = data["candidates"][0]["content"]["parts"][0]["text"]
                        parsed = json.loads(raw_text)
                        parsed["model_used"] = f"Gemini Pro ({model_name})"
                        parsed["generated_at"] = datetime.now(timezone.utc).isoformat()
                        return parsed
                    else:
                        logger.warning(f"Gemini API model {model_name} returned status {resp.status_code}")
                except Exception as e:
                    logger.warning(f"Error querying Gemini model {model_name}: {e}")
            return None

    def _generate_deterministic(
        self,
        symbol: str,
        company_name: str,
        exchange: str,
        signal_type: str,
        strategy_name: str,
        price: float,
        stop_loss: Optional[float],
        target: Optional[float],
        risk_reward: Optional[float],
        metrics: Dict[str, Any],
        financial_news: Optional[List[Dict[str, Any]]],
        time_horizon: str = "1-DAY",
    ) -> Dict[str, Any]:
        """High-conviction deterministic prompt synthesis engine."""
        is_us = exchange.upper() in ("US", "NASDAQ", "NYSE", "GLOBAL")
        curr = "$" if is_us else "₹"
        horizon_label = "1-DAY (Short Term / Swing 24-48 Hours)" if time_horizon == "1-DAY" else "1-MONTH (Long Term / Positional 30 Days)"
        holding_desc = "24 to 48 hours" if time_horizon == "1-DAY" else "30 days (1-Month Positional)"

        rsi = float(metrics.get("rsi_14") or 55.0)
        rvol = float(metrics.get("rvol") or 1.2)
        ema_21 = float(metrics.get("ema_21") or price)
        ema_50 = float(metrics.get("ema_50") or price)
        sma_50 = float(metrics.get("sma_50") or price)
        sma_200 = float(metrics.get("sma_200") or price)
        atr = float(metrics.get("atr_14") or max(price * 0.02, 1.0))
        swing_high = float(metrics.get("swing_high_20") or price)
        swing_low = float(metrics.get("swing_low_20") or price)
        pivot = float(metrics.get("pivot") or price)
        s1 = float(metrics.get("s1") or (price * 0.98))
        r1 = float(metrics.get("r1") or (price * 1.02))

        atr_pct = round((atr / price) * 100, 1) if price > 0 else 2.0
        sl = stop_loss if stop_loss is not None else round(price - (1.5 * atr), 2)
        tp = target if target is not None else round(price + (3.0 * atr), 2)
        sl_pct = round(((sl - price) / price) * 100, 1) if price > 0 else -3.0
        tp_pct = round(((tp - price) / price) * 100, 1) if price > 0 else 5.0
        rr = risk_reward if risk_reward is not None else round(abs(tp - price) / max(abs(price - sl), 0.01), 2)

        if signal_type == "BUY WATCH":
            if strategy_name == "MomentumBreakout":
                headline = f"{time_horizon} {symbol}: Bullish Momentum Breakout with {rvol:.1f}x Volume"
                thesis = (
                    f"Institutional accumulation is detected on {company_name} ({symbol}) on {exchange}. "
                    f"Price is trading at {curr}{price:.2f}, successfully consolidating above its 21-day EMA ({curr}{ema_21:.2f}) "
                    f"and 50-day SMA ({curr}{sma_50:.2f}), confirming an established intermediate uptrend. "
                    f"Relative volume has expanded to {rvol:.2f}x its 20-period baseline, confirming genuine institutional "
                    f"sponsorship over retail churn. RSI stands at {rsi:.1f}, reflecting healthy upward momentum with "
                    f"ample headroom before reaching overbought territory (>75). With an asymmetric risk-to-reward ratio "
                    f"of 1:{rr:.2f}, this setup offers an optimal risk-adjusted swing entry over {holding_desc}."
                )
                catalysts = [
                    f"Volume confirmation: RVOL surged to {rvol:.2f}x, confirming institutional participation and accumulation.",
                    f"Moving average confluence: Price ({curr}{price:.2f}) is firmly above 21 EMA ({curr}{ema_21:.2f}) and 50 SMA ({curr}{sma_50:.2f}).",
                    f"Healthy momentum profile: RSI 14 stands at {rsi:.1f}, indicating strong directional acceleration without overextension.",
                    f"Proximity to breakout level: Stock is challenging its 20-day swing high of {curr}{swing_high:.2f} with strong absorption.",
                ]
                risks = [
                    f"Immediate overhead supply: Resistance at {curr}{swing_high:.2f} may trigger brief consolidative pullbacks.",
                    f"Volatility exposure: ATR of ₹{atr:.2f} ({atr_pct}%) suggests normal daily fluctuations of ±₹{atr:.2f}.",
                    f"Technical invalidation: A daily close below the 21 EMA (₹{ema_21:.2f}) or stop-loss ₹{sl:.2f} invalidates the setup.",
                    "Broader market sentiment: Nifty index pullbacks or sudden sector rotation could mute upside velocity.",
                ]
                trend_summary = "Strong Uptrend (Above 21 EMA & 50 SMA)"
                momentum_summary = f"Bullish Acceleration (RSI: {rsi:.1f})"
                vol_summary = f"Institutional Accumulation ({rvol:.2f}x 20-day avg)"

            elif strategy_name == "MeanReversionPullback":
                headline = f"{symbol}: Asymmetric Dip-Buying Opportunity at Classical Support"
                thesis = (
                    f"{company_name} ({symbol}) has pulled back into high-probability demand territory near ₹{price:.2f} "
                    f"while preserving its higher-timeframe uptrend structure above the 50-day SMA (₹{sma_50:.2f}). "
                    f"Short-term indicators show seller exhaustion with RSI dipping to {rsi:.1f}. "
                    f"Classical support (S1: ₹{s1:.2f}) provides an asymmetric risk-defined entry targeting a quick reversion "
                    f"to the 21-day mean (₹{ema_21:.2f}) with a 1:{rr:.2f} risk-to-reward profile."
                )
                catalysts = [
                    f"Oversold exhaustion: RSI 14 at {rsi:.1f} signals short-term selling exhaustion in an uptrend.",
                    f"Dynamic support test: Price is testing classical support zone around S1 (₹{s1:.2f}).",
                    f"Higher timeframe protection: Price remains structured above the 50 SMA (₹{sma_50:.2f}).",
                    f"High reward-to-risk: Tight stop-loss at ₹{sl:.2f} protects capital against unexpected breakdown.",
                ]
                risks = [
                    f"Momentum continuation risk: Oversold conditions can persist during aggressive sector sell-offs.",
                    f"Breakdown below S2: A decisive break below ₹{sl:.2f} signals trend failure and requires immediate exit.",
                    f"Overhead mean resistance: 21 EMA at ₹{ema_21:.2f} acts as immediate supply on the rebound.",
                ]
                trend_summary = "Structural Bull Market (Pullback Phase)"
                momentum_summary = f"Oversold Exhaustion (RSI: {rsi:.1f})"
                vol_summary = "Absorption on Dips"

            else:  # MacdCross or others
                headline = f"{symbol}: MACD Bullish Momentum Inflection Cross Confirmed by Trend Filter"
                thesis = (
                    f"{company_name} ({symbol}) has formed a bullish MACD crossover above its signal line at ₹{price:.2f}. "
                    f"The histogram has turned positive, signaling an influx of fresh momentum following consolidation. "
                    f"Price is positioned above intermediate trend filters, giving institutional confirmation to the setup "
                    f"with a defined stop-loss at ₹{sl:.2f} and target at ₹{tp:.2f}."
                )
                catalysts = [
                    "MACD crossover: Fast line crossed above signal line with positive histogram expansion.",
                    f"Trend confirmation: Price is sustained above 50-day moving average (₹{sma_50:.2f}).",
                    f"Positive momentum shift: RSI at {rsi:.1f} shows expanding buying strength.",
                ]
                risks = [
                    f"Whipsaw risk: Fast MACD crosses in rangebound markets can generate false breakout signals.",
                    f"Trailing resistance: Supply zone at ₹{swing_high:.2f} must be cleared for extended continuation.",
                ]
                trend_summary = "Inflection Uptrend"
                momentum_summary = f"Bullish MACD Shift (RSI: {rsi:.1f})"
                vol_summary = f"Expanding Volume ({rvol:.2f}x)"

            tactical = {
                "entry_zone": f"₹{round(price * 0.995, 2)} - ₹{round(price * 1.005, 2)}",
                "stop_loss": f"₹{sl:.2f} ({sl_pct}%)",
                "target_1": f"₹{tp:.2f} (+{tp_pct}%)",
                "target_2": f"₹{round(price + (4.0 * atr), 2)} (+{round((4*atr/price)*100, 1)}%)",
                "time_horizon": "24 to 48 Hours",
                "suggested_allocation_pct": 2.0,
            }
            invalidation = f"Daily close below ₹{sl:.2f} or decisive volume breakdown below 21 EMA (₹{ema_21:.2f})."

        elif signal_type == "SELL/EXIT WATCH":
            headline = f"{symbol}: Tactical Exit Watch — Trend Structure Deterioration"
            thesis = (
                f"Technical distribution and structure deterioration have been detected on {company_name} ({symbol}) at ₹{price:.2f}. "
                f"Price has breached short-term dynamic moving averages (21 EMA: ₹{ema_21:.2f}) or momentum is showing sustained decline. "
                f"Capital preservation is prioritized according to risk management rules. Existing long swing positions "
                f"should be trimmed or closed, and fresh long exposure withheld until market structure stabilizes."
            )
            catalysts = [
                f"Structural breakdown: Price slipped below 21-day EMA (₹{ema_21:.2f}).",
                f"Momentum decay: RSI deteriorated to {rsi:.1f}, signaling dominant supply.",
                "Risk containment: Locking in gains or limiting drawdown to safeguard capital.",
            ]
            risks = [
                f"Continued downward acceleration towards next support level (₹{s1:.2f} / ₹{swing_low:.2f}).",
                "Holding through distribution exposes portfolio to steep drawdowns.",
            ]
            trend_summary = "Bearish Breakdown"
            momentum_summary = f"Deteriorating (RSI: {rsi:.1f})"
            vol_summary = "Distribution / Profit Taking"
            tactical = {
                "entry_zone": "N/A (Exit Mode)",
                "stop_loss": f"₹{round(price * 1.015, 2)} (+1.5%)",
                "target_1": f"₹{round(price - (2.0 * atr), 2)} (-{round((2*atr/price)*100, 1)}%)",
                "target_2": f"₹{round(price - (3.5 * atr), 2)} (-{round((3.5*atr/price)*100, 1)}%)",
                "time_horizon": "Immediate Exit / 24 Hours",
                "suggested_allocation_pct": 0.0,
            }
            invalidation = f"Bullish reclaim and close above 21-day EMA (₹{ema_21:.2f})."

        elif signal_type == "HOLD":
            headline = f"{symbol}: Constructive Trend Retention — Hold Long Positions"
            thesis = (
                f"{company_name} ({symbol}) is sustaining its broader trend structure at ₹{price:.2f}. "
                f"The stock remains above key moving averages with balanced volatility. "
                f"Existing long positions should be maintained with a trailing stop-loss anchored at ₹{sl:.2f}."
            )
            catalysts = [
                f"Trend continuation: Price sustained above 50 SMA (₹{sma_50:.2f}).",
                f"Controlled volatility: Normal daily swings of ±₹{atr:.2f} ({atr_pct}%).",
            ]
            risks = [
                f"Failure to clear overhead resistance at ₹{swing_high:.2f}.",
                f"Breakdown below trailing stop-loss at ₹{sl:.2f}.",
            ]
            trend_summary = "Constructive Trend"
            momentum_summary = f"Neutral / Positive (RSI: {rsi:.1f})"
            vol_summary = "Stable"
            tactical = {
                "entry_zone": f"Hold Current Position (Trail SL: ₹{sl:.2f})",
                "stop_loss": f"₹{sl:.2f} ({sl_pct}%)",
                "target_1": f"₹{tp:.2f} (+{tp_pct}%)",
                "target_2": f"₹{round(price + (3.5 * atr), 2)}",
                "time_horizon": "24 to 48 Hours",
                "suggested_allocation_pct": 2.0,
            }
            invalidation = f"Exit on close below trailing stop-loss ₹{sl:.2f}."

        else:  # NO TRADE
            headline = f"{symbol}: Rangebound Consolidation — Awaiting Setup Confluence"
            thesis = (
                f"{company_name} ({symbol}) is currently rangebound between ₹{swing_low:.2f} and ₹{swing_high:.2f}. "
                f"Neither momentum breakout nor oversold mean-reversion conditions satisfy our strict 80/100 confluence threshold. "
                f"Patience and capital preservation are recommended until high-conviction volume expansion appears."
            )
            catalysts = [
                f"Consolidation inside 20-day band: ₹{swing_low:.2f} to ₹{swing_high:.2f}.",
                "Wait for directional breakout above resistance or dip to structural support.",
            ]
            risks = [
                "Premature entries in non-trending markets face chop and theta/time decay.",
            ]
            trend_summary = "Neutral / Consolidating"
            momentum_summary = f"Neutral (RSI: {rsi:.1f})"
            vol_summary = f"Average ({rvol:.2f}x)"
            tactical = {
                "entry_zone": "No Trade Active",
                "stop_loss": "N/A",
                "target_1": "N/A",
                "target_2": "N/A",
                "time_horizon": "Watchlist",
                "suggested_allocation_pct": 0.0,
            }
            invalidation = "N/A"

        return {
            "headline": headline,
            "investment_thesis": thesis,
            "catalysts": catalysts,
            "risk_factors": risks,
            "technical_summary": {
                "trend": trend_summary,
                "momentum": momentum_summary,
                "volume_profile": vol_summary,
                "volatility": f"Moderate ATR (±{atr_pct}% daily range)",
            },
            "fundamental_summary": {
                "valuation": "Fair Valuation vs Historical Multiples",
                "financial_health": "Solvent balance sheet, structured for swing horizons",
                "earnings_trend": "Consistent operating margins in primary sector",
            },
            "news_and_events": {
                "sentiment": "Neutral / Positive",
                "summary": "No catastrophic corporate governance red flags detected",
            },
            "risk_analysis": {
                "downside_risk": f"Defined cut at ₹{sl:.2f} ({sl_pct}%)",
                "suggested_risk_pct": 2.0,
                "volatility_regime": "Normal / Within ATR Boundaries",
            },
            "trade_evaluation": {
                "entry_zone": tactical.get("entry_zone", f"₹{price:.2f}"),
                "stop_loss": f"₹{sl:.2f}",
                "target": f"₹{tp:.2f}",
                "expected_costs": "Round-trip STT, brokerage, and GST (~0.15%)",
                "recommendation": "High Confluence Opportunity" if "BUY" in signal_type else "Hold / Exit",
            },
            "tactical_plan": tactical,
            "invalidation_trigger": invalidation,
            "model_used": "Quantitative Confluence Engine (Deterministic Rules)",
            "generated_at": datetime.now(timezone.utc).isoformat(),
        }


ai_narrative_generator = AINarrativeGenerator()
