"""US Market Data Service (NYSE & NASDAQ).

Handles:
- NYSE stocks, NASDAQ stocks, S&P 500, NASDAQ 100, Dow Jones, and US sector indices
- US market trading hours (09:30 - 16:00 EST / America/New_York)
- USD ($) currency formatting
- US company financial statements & SEC fundamentals
"""

from datetime import datetime, timezone, timedelta
from typing import List, Dict, Any, Optional
import yfinance as yf
from app.core.logging import logger
from app.schemas.candle import QuoteRead

# Prominent US Mega-Cap & S&P 500 Stock Universe
US_STOCKS_UNIVERSE = [
    {"symbol": "AAPL", "name": "Apple Inc.", "exchange": "NASDAQ", "sector": "Consumer Electronics"},
    {"symbol": "NVDA", "name": "NVIDIA Corporation", "exchange": "NASDAQ", "sector": "Semiconductors"},
    {"symbol": "MSFT", "name": "Microsoft Corporation", "exchange": "NASDAQ", "sector": "Cloud & Software"},
    {"symbol": "AMZN", "name": "Amazon.com Inc.", "exchange": "NASDAQ", "sector": "E-Commerce & Cloud"},
    {"symbol": "GOOGL", "name": "Alphabet Inc.", "exchange": "NASDAQ", "sector": "Internet & AI"},
    {"symbol": "META", "name": "Meta Platforms Inc.", "exchange": "NASDAQ", "sector": "Social Media & AI"},
    {"symbol": "TSLA", "name": "Tesla Inc.", "exchange": "NASDAQ", "sector": "Automobile & Clean Energy"},
    {"symbol": "BRK-B", "name": "Berkshire Hathaway Inc.", "exchange": "NYSE", "sector": "Financials"},
    {"symbol": "AVGO", "name": "Broadcom Inc.", "exchange": "NASDAQ", "sector": "Semiconductors"},
    {"symbol": "JPM", "name": "JPMorgan Chase & Co.", "exchange": "NYSE", "sector": "Financials"},
    {"symbol": "V", "name": "Visa Inc.", "exchange": "NYSE", "sector": "Financials"},
    {"symbol": "WMT", "name": "Walmart Inc.", "exchange": "NYSE", "sector": "Retail"},
    {"symbol": "MA", "name": "Mastercard Incorporated", "exchange": "NYSE", "sector": "Financials"},
    {"symbol": "UNH", "name": "UnitedHealth Group", "exchange": "NYSE", "sector": "Healthcare"},
    {"symbol": "COST", "name": "Costco Wholesale Corp.", "exchange": "NASDAQ", "sector": "Consumer Staples"},
    {"symbol": "HD", "name": "The Home Depot Inc.", "exchange": "NYSE", "sector": "Consumer Discretionary"},
    {"symbol": "PG", "name": "Procter & Gamble Co.", "exchange": "NYSE", "sector": "Consumer Goods"},
    {"symbol": "JNJ", "name": "Johnson & Johnson", "exchange": "NYSE", "sector": "Healthcare"},
    {"symbol": "ORCL", "name": "Oracle Corporation", "exchange": "NYSE", "sector": "Software & Cloud"},
    {"symbol": "AMD", "name": "Advanced Micro Devices", "exchange": "NASDAQ", "sector": "Semiconductors"},
    {"symbol": "NFLX", "name": "Netflix Inc.", "exchange": "NASDAQ", "sector": "Streaming Media"},
    {"symbol": "CRM", "name": "Salesforce Inc.", "exchange": "NYSE", "sector": "Software"},
    {"symbol": "PLTR", "name": "Palantir Technologies", "exchange": "NASDAQ", "sector": "Enterprise AI"},
    {"symbol": "INTC", "name": "Intel Corporation", "exchange": "NASDAQ", "sector": "Semiconductors"},
    {"symbol": "DIS", "name": "The Walt Disney Company", "exchange": "NYSE", "sector": "Entertainment"},
    {"symbol": "BA", "name": "The Boeing Company", "exchange": "NYSE", "sector": "Aerospace & Defense"},
]

# Major US Benchmark and Sector Indices
US_INDICES = [
    {"symbol": "^GSPC", "name": "S&P 500", "category": "Benchmark"},
    {"symbol": "^IXIC", "name": "NASDAQ Composite", "category": "Benchmark"},
    {"symbol": "^NDX", "name": "NASDAQ 100", "category": "Tech Benchmark"},
    {"symbol": "^DJI", "name": "Dow Jones Industrial", "category": "Bluechip Benchmark"},
    {"symbol": "XLK", "name": "Technology Select SPDR", "category": "Sector Tech"},
    {"symbol": "XLF", "name": "Financial Select SPDR", "category": "Sector Finance"},
    {"symbol": "XLE", "name": "Energy Select SPDR", "category": "Sector Energy"},
    {"symbol": "XLV", "name": "Healthcare Select SPDR", "category": "Sector Healthcare"},
]


class USMarketDataService:
    """Service providing dedicated US stock market data (NYSE & NASDAQ)."""

    MARKET_CODE = "US"
    CURRENCY = "USD"
    CURRENCY_SYMBOL = "$"
    TIMEZONE_STR = "America/New_York"

    _index_cache: Dict[str, Any] = {}
    _index_cache_ts: float = 0.0

    @classmethod
    def format_ticker(cls, symbol: str) -> str:
        """Formats ticker for US exchanges (clean symbol without dot suffixes)."""
        sym = symbol.strip().upper()
        if sym.startswith("^"):
            return sym
        # Clean any accidental Indian suffixes if passed
        clean = sym.replace(".NS", "").replace(".BO", "")
        return clean

    @classmethod
    def get_market_session_status(cls) -> Dict[str, Any]:
        """Calculates exact NYSE/NASDAQ trading session status in EST (09:30 - 16:00 EST / America/New_York)."""
        # UTC - 5:00 (Standard) or -4:00 (EDT)
        now_utc = datetime.now(timezone.utc)
        # Using -5 hours approximate for EST
        est_offset = timedelta(hours=-5)
        now_est = now_utc + est_offset

        weekday = now_est.weekday()  # 0=Mon, 4=Fri, 5=Sat, 6=Sun
        is_weekend = weekday >= 5

        open_time = now_est.replace(hour=9, minute=30, second=0, microsecond=0)
        close_time = now_est.replace(hour=16, minute=0, second=0, microsecond=0)
        pre_market = now_est.replace(hour=4, minute=0, second=0, microsecond=0)

        is_open = False
        status = "CLOSED"
        session_text = "Market Closed"

        if is_weekend:
            status = "WEEKEND_CLOSED"
            session_text = "Weekend Closed • Opens Mon 09:30 EST"
        elif now_est < pre_market:
            status = "PRE_SESSION"
            session_text = "Overnight Session • Pre-Market Opens 04:00 EST"
        elif pre_market <= now_est < open_time:
            status = "PRE_MARKET"
            diff = open_time - now_est
            hrs = int(diff.total_seconds() // 3600)
            mins = int((diff.total_seconds() % 3600) // 60)
            session_text = f"Pre-Market Active • Regular Session in {hrs}h {mins}m"
        elif open_time <= now_est <= close_time:
            is_open = True
            status = "OPEN"
            diff = close_time - now_est
            hrs = int(diff.total_seconds() // 3600)
            mins = int((diff.total_seconds() % 3600) // 60)
            session_text = f"Regular Trading Open • Closes in {hrs}h {mins}m"
        else:
            status = "AFTER_HOURS"
            session_text = "After-Hours Session (16:00 - 20:00 EST)"

        return {
            "market": "US",
            "exchange": "NYSE / NASDAQ",
            "currency": cls.CURRENCY,
            "currency_symbol": cls.CURRENCY_SYMBOL,
            "is_open": is_open,
            "status": status,
            "session_text": session_text,
            "server_time_est": now_est.strftime("%d %b %Y, %I:%M:%S %p EST"),
            "market_open_time": "09:30 EST",
            "market_close_time": "16:00 EST",
        }

    @classmethod
    def get_indices(cls, force_refresh: bool = False) -> List[Dict[str, Any]]:
        """Fetches live quotes for major US benchmark and sector indices."""
        now = datetime.now(timezone.utc).timestamp()
        if not force_refresh and cls._index_cache and (now - cls._index_cache_ts < 90):
            return list(cls._index_cache.values())

        results = []
        for item in US_INDICES:
            sym = item["symbol"]
            name = item["name"]
            cat = item["category"]
            price = 0.0
            pct_change = 0.0
            change = 0.0
            prev_close = 0.0

            try:
                t = yf.Ticker(sym)
                fi = getattr(t, "fast_info", None)
                if fi and getattr(fi, "last_price", None) is not None:
                    price = float(fi.last_price)
                    prev_close = float(fi.previous_close or price)
                    change = price - prev_close
                    pct_change = (change / prev_close) * 100 if prev_close else 0.0
                else:
                    hist = t.history(period="5d", interval="1d")
                    if not hist.empty:
                        latest = hist.iloc[-1]
                        prev = hist.iloc[-2] if len(hist) > 1 else latest
                        price = float(latest["Close"])
                        prev_close = float(prev["Close"])
                        change = price - prev_close
                        pct_change = (change / prev_close) * 100 if prev_close else 0.0
            except Exception as e:
                logger.debug(f"US Index fetch note for {sym}: {e}")

            idx_data = {
                "symbol": sym,
                "name": name,
                "category": cat,
                "price": round(price, 2),
                "change": round(change, 2),
                "percent_change": round(pct_change, 2),
                "currency": cls.CURRENCY,
                "currency_symbol": cls.CURRENCY_SYMBOL,
                "is_positive": pct_change >= 0,
            }
            results.append(idx_data)
            cls._index_cache[sym] = idx_data

        cls._index_cache_ts = now
        return results

    @classmethod
    def get_universe(cls) -> List[Dict[str, Any]]:
        """Returns the supported US stock universe."""
        return [dict(s, market="US", currency=cls.CURRENCY) for s in US_STOCKS_UNIVERSE]

    @classmethod
    def search_stocks(cls, query: str) -> List[Dict[str, Any]]:
        """Searches strictly within US stocks (NYSE / NASDAQ)."""
        q = query.strip().upper()
        if not q:
            return []

        results = []
        # 1. Match local predefined universe
        for s in US_STOCKS_UNIVERSE:
            if q in s["symbol"].upper() or q in s["name"].upper():
                results.append({**s, "market": "US", "currency": cls.CURRENCY, "currency_symbol": cls.CURRENCY_SYMBOL})

        # 2. Dynamic Yahoo Finance search strictly for US equities
        try:
            search_obj = yf.Search(f"{query} US equity", max_results=8)
            for item in getattr(search_obj, "quotes", []):
                sym = item.get("symbol", "")
                quote_type = item.get("quoteType", "")
                if sym and quote_type in ("EQUITY", "ETF") and "." not in sym:
                    exch = item.get("exchange") or "NASDAQ"
                    name = item.get("longname") or item.get("shortname") or sym
                    sector = item.get("sector") or item.get("industry") or "US Equity"
                    if not any(r["symbol"] == sym for r in results):
                        results.append({
                            "symbol": sym,
                            "name": name,
                            "exchange": exch,
                            "sector": sector,
                            "market": "US",
                            "currency": cls.CURRENCY,
                            "currency_symbol": cls.CURRENCY_SYMBOL,
                        })
        except Exception as e:
            logger.debug(f"US dynamic search note: {e}")

        return results

    @classmethod
    def get_stock_fundamentals(cls, symbol: str) -> Dict[str, Any]:
        """Fetches detailed SEC financial statements and company fundamentals for a US stock."""
        ticker_sym = cls.format_ticker(symbol)
        ticker = yf.Ticker(ticker_sym)
        info = ticker.info or {}

        return {
            "symbol": symbol.upper(),
            "exchange": info.get("exchange") or "NASDAQ",
            "market": "US",
            "currency": cls.CURRENCY,
            "currency_symbol": cls.CURRENCY_SYMBOL,
            "company_name": info.get("longName") or info.get("shortName") or symbol.upper(),
            "sector": info.get("sector") or "General",
            "industry": info.get("industry") or "General",
            "market_cap": info.get("marketCap"),
            "trailing_pe": info.get("trailingPE"),
            "forward_pe": info.get("forwardPE"),
            "price_to_book": info.get("priceToBook"),
            "return_on_equity": info.get("returnOnEquity"),
            "return_on_assets": info.get("returnOnAssets"),
            "gross_margins": info.get("grossMargins"),
            "operating_margins": info.get("operatingMargins"),
            "profit_margins": info.get("profitMargins"),
            "quarterly_revenue_growth": info.get("revenueGrowth"),
            "quarterly_earnings_growth": info.get("earningsQuarterlyGrowth"),
            "total_revenue": info.get("totalRevenue"),
            "net_income": info.get("netIncomeToCommon"),
            "total_debt": info.get("totalDebt"),
            "debt_to_equity": info.get("debtToEquity"),
            "free_cashflow": info.get("freeCashflow"),
            "trailing_eps": info.get("trailingEps"),
            "forward_eps": info.get("forwardEps"),
            "52_week_high": info.get("fiftyTwoWeekHigh"),
            "52_week_low": info.get("fiftyTwoWeekLow"),
            "target_mean_price": info.get("targetMeanPrice"),
            "recommendation_key": info.get("recommendationKey"),
            "number_of_analyst_opinions": info.get("numberOfAnalystOpinions"),
            "website": info.get("website"),
            "summary": info.get("longBusinessSummary"),
        }
