"""Global Market & Macro Research Engine.

Gathers and analyzes broader market indices, sector alignment, currency,
and commodities before predicting individual stocks:
- Indian Benchmark Indices: Nifty 50 (^NSEI), Bank Nifty (^NSEBANK), Nifty IT (^CNXIT)
- Global Indices: S&P 500 (^GSPC), Nasdaq Composite (^IXIC)
- Commodities & FX: Brent Crude (BZ=F), USD/INR (INR=X)
- Stock vs Index Beta & Relative Strength
"""

import time
from datetime import datetime, timezone
from typing import Dict, Any, Optional
import pandas as pd
from app.core.logging import logger
from app.providers.factory import get_market_data_provider

# Memory cache for global macro quotes (15-minute TTL)
_MACRO_CACHE: Dict[str, Any] = {"data": None, "timestamp": 0.0}
_CACHE_TTL = 900.0  # 15 minutes


class GlobalMarketEngine:
    """Macro and cross-market intelligence aggregator."""

    MACRO_SYMBOLS = {
        "nifty_50": "^NSEI",
        "bank_nifty": "^NSEBANK",
        "nifty_it": "^CNXIT",
        "sp_500": "^GSPC",
        "nasdaq": "^IXIC",
        "crude_oil": "BZ=F",
        "usd_inr": "INR=X",
    }

    @classmethod
    def get_macro_context(cls, force_refresh: bool = False) -> Dict[str, Any]:
        """Fetches and caches current performance across major macro assets."""
        global _MACRO_CACHE
        now = time.time()

        if not force_refresh and _MACRO_CACHE["data"] and (now - _MACRO_CACHE["timestamp"] < _CACHE_TTL):
            return _MACRO_CACHE["data"]

        provider = get_market_data_provider()
        context = {
            "indices": {},
            "commodities_fx": {},
            "nifty_status": "NEUTRAL",
            "global_sentiment": "NEUTRAL",
            "macro_score": 50.0,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }

        # Query quotes for macro symbols
        for key, sym in cls.MACRO_SYMBOLS.items():
            try:
                q = provider.get_quote(sym, exchange="GLOBAL")
                if q and q.price:
                    pct = q.percent_change or 0.0
                    data_dict = {
                        "symbol": sym,
                        "price": q.price,
                        "change_pct": round(pct, 2),
                        "status": "BULLISH" if pct > 0.3 else ("BEARISH" if pct < -0.3 else "FLAT"),
                    }
                    if "nifty" in key or "sp_500" in key or "nasdaq" in key:
                        context["indices"][key] = data_dict
                    else:
                        context["commodities_fx"][key] = data_dict
            except Exception as e:
                logger.debug(f"Could not load macro symbol {sym}: {e}")

        # Assess Nifty 50 stance
        nifty = context["indices"].get("nifty_50")
        if nifty:
            npct = nifty.get("change_pct", 0.0)
            if npct >= 0.5:
                context["nifty_status"] = "STRONG_BULLISH"
            elif npct > 0.0:
                context["nifty_status"] = "MILD_BULLISH"
            elif npct <= -0.5:
                context["nifty_status"] = "STRONG_BEARISH"
            else:
                context["nifty_status"] = "MILD_BEARISH"

        # Global sentiment synthesis
        sp = context["indices"].get("sp_500", {}).get("change_pct", 0.0)
        nas = context["indices"].get("nasdaq", {}).get("change_pct", 0.0)
        nifty_p = nifty.get("change_pct", 0.0) if nifty else 0.0
        avg_global = (sp + nas + nifty_p) / 3.0

        if avg_global >= 0.4:
            context["global_sentiment"] = "RISK_ON_BULLISH"
            macro_score = 75.0
        elif avg_global <= -0.4:
            context["global_sentiment"] = "RISK_OFF_BEARISH"
            macro_score = 25.0
        else:
            context["global_sentiment"] = "NEUTRAL_MIXED"
            macro_score = 50.0

        context["macro_score"] = round(macro_score, 1)

        _MACRO_CACHE["data"] = context
        _MACRO_CACHE["timestamp"] = now
        return context

    @classmethod
    def evaluate_stock_macro_alignment(
        cls,
        stock_symbol: str,
        sector: Optional[str] = None,
        stock_df: Optional[pd.DataFrame] = None,
    ) -> Dict[str, Any]:
        """
        Evaluates how the broader macro environment supports or hinders
        an individual stock's directional prospects.
        """
        macro = cls.get_macro_context()
        nifty_stat = macro.get("nifty_status", "NEUTRAL")
        macro_score = macro.get("macro_score", 50.0)

        # Sector-specific weighting
        sector_clean = (sector or "").upper()
        sector_tailwinds = []
        sector_headwinds = []

        if "TECH" in sector_clean or "IT" in sector_clean:
            it_idx = macro.get("indices", {}).get("nifty_it", {})
            it_chg = it_idx.get("change_pct", 0.0)
            if it_chg > 0.5:
                sector_tailwinds.append(f"Nifty IT Sector strongly supportive (+{it_chg}%)")
                macro_score += 10.0
            elif it_chg < -0.5:
                sector_headwinds.append(f"Nifty IT Sector dragging (-{abs(it_chg)}%)")
                macro_score -= 10.0

        elif "FINANC" in sector_clean or "BANK" in sector_clean:
            bank_idx = macro.get("indices", {}).get("bank_nifty", {})
            b_chg = bank_idx.get("change_pct", 0.0)
            if b_chg > 0.5:
                sector_tailwinds.append(f"Bank Nifty Sector rally (+{b_chg}%)")
                macro_score += 10.0
            elif b_chg < -0.5:
                sector_headwinds.append(f"Bank Nifty weakness (-{abs(b_chg)}%)")
                macro_score -= 10.0

        elif "ENERGY" in sector_clean or "OIL" in sector_clean:
            crude = macro.get("commodities_fx", {}).get("crude_oil", {})
            c_chg = crude.get("change_pct", 0.0)
            if abs(c_chg) > 2.0:
                sector_tailwinds.append(f"Elevated crude volatility ({c_chg}%) impacting margins")

        # Relative Strength vs Benchmark
        rel_strength = "IN_LINE"
        if stock_df is not None and len(stock_df) >= 20:
            stock_ret_20 = ((stock_df["close"].iloc[-1] - stock_df["close"].iloc[-20]) / stock_df["close"].iloc[-20]) * 100.0
            nifty_ret_est = macro.get("indices", {}).get("nifty_50", {}).get("change_pct", 0.0) * 10.0
            if stock_ret_20 > nifty_ret_est + 4.0:
                rel_strength = "OUTPERFORMING_BENCHMARK"
                macro_score += 10.0
            elif stock_ret_20 < nifty_ret_est - 4.0:
                rel_strength = "UNDERPERFORMING_BENCHMARK"
                macro_score -= 10.0

        macro_score = float(max(min(macro_score, 95.0), 10.0))

        return {
            "macro_score": round(macro_score, 1),
            "nifty_status": nifty_stat,
            "global_sentiment": macro.get("global_sentiment", "NEUTRAL"),
            "relative_strength": rel_strength,
            "sector_tailwinds": sector_tailwinds,
            "sector_headwinds": sector_headwinds,
            "macro_snapshot": macro,
        }
