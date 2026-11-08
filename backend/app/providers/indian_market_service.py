"""Indian Market Data Service (NSE & BSE).

Handles:
- NSE stocks, BSE stocks, NIFTY 50, NIFTY BANK, NIFTY IT, SENSEX, and Indian sector indices
- Indian market trading hours (09:15 - 15:30 IST)
- INR (₹) currency formatting
- Indian company financial statements & fundamentals
"""

from datetime import datetime, timezone, timedelta
from typing import List, Dict, Any, Optional
import yfinance as yf
from app.core.logging import logger
from app.schemas.candle import QuoteRead

# High-Liquidity Indian Stock Universe (NSE / BSE Leaders)
INDIAN_STOCKS_UNIVERSE = [
    {"symbol": "RELIANCE", "name": "Reliance Industries Ltd", "exchange": "NSE", "sector": "Energy"},
    {"symbol": "TCS", "name": "Tata Consultancy Services Ltd", "exchange": "NSE", "sector": "Technology"},
    {"symbol": "INFY", "name": "Infosys Ltd", "exchange": "NSE", "sector": "Technology"},
    {"symbol": "HDFCBANK", "name": "HDFC Bank Ltd", "exchange": "NSE", "sector": "Financials"},
    {"symbol": "ICICIBANK", "name": "ICICI Bank Ltd", "exchange": "NSE", "sector": "Financials"},
    {"symbol": "SBIN", "name": "State Bank of India", "exchange": "NSE", "sector": "Financials"},
    {"symbol": "ITC", "name": "ITC Ltd", "exchange": "NSE", "sector": "Consumer Goods"},
    {"symbol": "BHARTIARTL", "name": "Bharti Airtel Ltd", "exchange": "NSE", "sector": "Telecom"},
    {"symbol": "HINDUNILVR", "name": "Hindustan Unilever Ltd", "exchange": "NSE", "sector": "Consumer Goods"},
    {"symbol": "LT", "name": "Larsen & Toubro Ltd", "exchange": "NSE", "sector": "Capital Goods"},
    {"symbol": "BAJFINANCE", "name": "Bajaj Finance Ltd", "exchange": "NSE", "sector": "Financials"},
    {"symbol": "MARUTI", "name": "Maruti Suzuki India Ltd", "exchange": "NSE", "sector": "Automobile"},
    {"symbol": "SUNPHARMA", "name": "Sun Pharmaceutical Industries", "exchange": "NSE", "sector": "Healthcare"},
    {"symbol": "TATAMOTORS", "name": "Tata Motors Ltd", "exchange": "NSE", "sector": "Automobile"},
    {"symbol": "NTPC", "name": "NTPC Ltd", "exchange": "NSE", "sector": "Utilities"},
    {"symbol": "ONGC", "name": "Oil & Natural Gas Corp Ltd", "exchange": "NSE", "sector": "Energy"},
    {"symbol": "KOTAKBANK", "name": "Kotak Mahindra Bank Ltd", "exchange": "NSE", "sector": "Financials"},
    {"symbol": "TITAN", "name": "Titan Company Ltd", "exchange": "NSE", "sector": "Consumer Goods"},
    {"symbol": "ADANIENT", "name": "Adani Enterprises Ltd", "exchange": "NSE", "sector": "Metals & Mining"},
    {"symbol": "ADANIPORTS", "name": "Adani Ports & SEZ Ltd", "exchange": "NSE", "sector": "Infrastructure"},
    {"symbol": "AXISBANK", "name": "Axis Bank Ltd", "exchange": "NSE", "sector": "Financials"},
    {"symbol": "WIPRO", "name": "Wipro Ltd", "exchange": "NSE", "sector": "Technology"},
    {"symbol": "TATASTEEL", "name": "Tata Steel Ltd", "exchange": "NSE", "sector": "Metals & Mining"},
    {"symbol": "JSWSTEEL", "name": "JSW Steel Ltd", "exchange": "NSE", "sector": "Metals & Mining"},
    {"symbol": "ASIANPAINT", "name": "Asian Paints Ltd", "exchange": "NSE", "sector": "Consumer Goods"},
    {"symbol": "COALINDIA", "name": "Coal India Ltd", "exchange": "NSE", "sector": "Energy"},
    {"symbol": "POWERGRID", "name": "Power Grid Corp of India", "exchange": "NSE", "sector": "Utilities"},
    {"symbol": "ULTRACEMCO", "name": "UltraTech Cement Ltd", "exchange": "NSE", "sector": "Materials"},
    {"symbol": "HCLTECH", "name": "HCL Technologies Ltd", "exchange": "NSE", "sector": "Technology"},
    {"symbol": "BAJAJFINSV", "name": "Bajaj Finserv Ltd", "exchange": "NSE", "sector": "Financials"},
    {"symbol": "BAJAJ-AUTO", "name": "Bajaj Auto Ltd", "exchange": "NSE", "sector": "Automobile"},
    {"symbol": "TECHM", "name": "Tech Mahindra Ltd", "exchange": "NSE", "sector": "Technology"},
    {"symbol": "INDUSINDBK", "name": "IndusInd Bank Ltd", "exchange": "NSE", "sector": "Financials"},
    {"symbol": "HINDALCO", "name": "Hindalco Industries Ltd", "exchange": "NSE", "sector": "Metals & Mining"},
    {"symbol": "GRASIM", "name": "Grasim Industries Ltd", "exchange": "NSE", "sector": "Materials"},
    {"symbol": "CIPLA", "name": "Cipla Ltd", "exchange": "NSE", "sector": "Healthcare"},
    {"symbol": "DRREDDY", "name": "Dr. Reddy's Laboratories", "exchange": "NSE", "sector": "Healthcare"},
    {"symbol": "APOLLOHOSP", "name": "Apollo Hospitals Enterprise", "exchange": "NSE", "sector": "Healthcare"},
    {"symbol": "EICHERMOT", "name": "Eicher Motors Ltd", "exchange": "NSE", "sector": "Automobile"},
    {"symbol": "HEROMOTOCO", "name": "Hero MotoCorp Ltd", "exchange": "NSE", "sector": "Automobile"},
    {"symbol": "BPCL", "name": "Bharat Petroleum Corp Ltd", "exchange": "NSE", "sector": "Energy"},
    {"symbol": "DIVISLAB", "name": "Divi's Laboratories Ltd", "exchange": "NSE", "sector": "Healthcare"},
    {"symbol": "BRITANNIA", "name": "Britannia Industries Ltd", "exchange": "NSE", "sector": "Consumer Goods"},
    {"symbol": "NESTLEIND", "name": "Nestle India Ltd", "exchange": "NSE", "sector": "Consumer Goods"},
    {"symbol": "SBILIFE", "name": "SBI Life Insurance Co Ltd", "exchange": "NSE", "sector": "Financials"},
    {"symbol": "HDFCLIFE", "name": "HDFC Life Insurance Co Ltd", "exchange": "NSE", "sector": "Financials"},
    {"symbol": "SHRIRAMFIN", "name": "Shriram Finance Ltd", "exchange": "NSE", "sector": "Financials"},
    {"symbol": "BEL", "name": "Bharat Electronics Ltd", "exchange": "NSE", "sector": "Capital Goods"},
    {"symbol": "TRENT", "name": "Trent Ltd", "exchange": "NSE", "sector": "Consumer Services"},
    {"symbol": "ZOMATO", "name": "Zomato Ltd", "exchange": "NSE", "sector": "Consumer Services"},
    {"symbol": "JIOFIN", "name": "Jio Financial Services Ltd", "exchange": "NSE", "sector": "Financials"},
]

# Major Indian Benchmark and Sector Indices
INDIAN_INDICES = [
    {"symbol": "^NSEI", "name": "NIFTY 50", "category": "Benchmark"},
    {"symbol": "^NSEBANK", "name": "NIFTY BANK", "category": "Sector Banking"},
    {"symbol": "^CNXIT", "name": "NIFTY IT", "category": "Sector Technology"},
    {"symbol": "^BSESN", "name": "SENSEX", "category": "Benchmark"},
    {"symbol": "^CNXAUTO", "name": "NIFTY AUTO", "category": "Sector Auto"},
    {"symbol": "^CNXPHARMA", "name": "NIFTY PHARMA", "category": "Sector Pharma"},
    {"symbol": "^CNXFMCG", "name": "NIFTY FMCG", "category": "Sector FMCG"},
    {"symbol": "^CNXMETAL", "name": "NIFTY METAL", "category": "Sector Metals"},
]


class IndianMarketDataService:
    """Service providing dedicated Indian stock market data (NSE & BSE)."""

    MARKET_CODE = "INDIA"
    CURRENCY = "INR"
    CURRENCY_SYMBOL = "₹"
    TIMEZONE_STR = "Asia/Kolkata"

    _index_cache: Dict[str, Any] = {}
    _index_cache_ts: float = 0.0

    @classmethod
    def format_ticker(cls, symbol: str, exchange: str = "NSE") -> str:
        """Formats ticker with appropriate Indian exchange suffix."""
        sym = symbol.strip().upper()
        if sym.startswith("^"):
            return sym
        if sym.endswith(".NS") or sym.endswith(".BO"):
            return sym
        if exchange.upper() == "BSE":
            return f"{sym}.BO"
        return f"{sym}.NS"

    @classmethod
    def get_market_session_status(cls) -> Dict[str, Any]:
        """Calculates exact NSE/BSE trading session status in IST (09:15 - 15:30 IST)."""
        # UTC + 5:30
        now_utc = datetime.now(timezone.utc)
        ist_offset = timedelta(hours=5, minutes=30)
        now_ist = now_utc + ist_offset

        weekday = now_ist.weekday()  # 0=Mon, 4=Fri, 5=Sat, 6=Sun
        is_weekend = weekday >= 5

        open_time = now_ist.replace(hour=9, minute=15, second=0, microsecond=0)
        close_time = now_ist.replace(hour=15, minute=30, second=0, microsecond=0)
        pre_market = now_ist.replace(hour=9, minute=0, second=0, microsecond=0)

        is_open = False
        status = "CLOSED"
        session_text = "Market Closed"

        if is_weekend:
            status = "WEEKEND_CLOSED"
            session_text = "Weekend Closed • Opens Mon 09:15 IST"
        elif now_ist < pre_market:
            status = "PRE_SESSION"
            diff = open_time - now_ist
            hrs = int(diff.total_seconds() // 3600)
            mins = int((diff.total_seconds() % 3600) // 60)
            session_text = f"Opens in {hrs}h {mins}m (09:15 IST)"
        elif pre_market <= now_ist < open_time:
            status = "PRE_MARKET"
            session_text = "Pre-Market Session (09:00 - 09:15 IST)"
        elif open_time <= now_ist <= close_time:
            is_open = True
            status = "OPEN"
            diff = close_time - now_ist
            hrs = int(diff.total_seconds() // 3600)
            mins = int((diff.total_seconds() % 3600) // 60)
            session_text = f"Live Market Open • Closes in {hrs}h {mins}m"
        else:
            status = "POST_MARKET"
            session_text = "Market Closed (15:30 IST) • Reopens Next Session"

        return {
            "market": "INDIA",
            "exchange": "NSE / BSE",
            "currency": cls.CURRENCY,
            "currency_symbol": cls.CURRENCY_SYMBOL,
            "is_open": is_open,
            "status": status,
            "session_text": session_text,
            "server_time_ist": now_ist.strftime("%d %b %Y, %I:%M:%S %p IST"),
            "market_open_time": "09:15 IST",
            "market_close_time": "15:30 IST",
        }

    @classmethod
    def get_indices(cls, force_refresh: bool = False) -> List[Dict[str, Any]]:
        """Fetches live quotes for major Indian benchmark and sector indices."""
        now = datetime.now(timezone.utc).timestamp()
        if not force_refresh and cls._index_cache and (now - cls._index_cache_ts < 90):
            return list(cls._index_cache.values())

        results = []
        for item in INDIAN_INDICES:
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
                logger.debug(f"Index fetch note for {sym}: {e}")

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
        """Returns the supported Indian stock universe."""
        return [dict(s, market="INDIA", currency=cls.CURRENCY) for s in INDIAN_STOCKS_UNIVERSE]

    @classmethod
    def search_stocks(cls, query: str) -> List[Dict[str, Any]]:
        """Searches strictly within Indian stocks (NSE / BSE)."""
        q = query.strip().upper()
        if not q:
            return []

        results = []
        # 1. Match local predefined universe
        for s in INDIAN_STOCKS_UNIVERSE:
            if q in s["symbol"].upper() or q in s["name"].upper():
                results.append({**s, "market": "INDIA", "currency": cls.CURRENCY, "currency_symbol": cls.CURRENCY_SYMBOL})

        # 2. Dynamic Yahoo Finance search limited to Indian exchanges (.NS and .BO)
        try:
            search_obj = yf.Search(f"{query} NSE India", max_results=8)
            for item in getattr(search_obj, "quotes", []):
                sym = item.get("symbol", "")
                if ".NS" in sym or ".BO" in sym:
                    clean_sym = sym.replace(".NS", "").replace(".BO", "")
                    exch = "BSE" if ".BO" in sym else "NSE"
                    name = item.get("longname") or item.get("shortname") or clean_sym
                    sector = item.get("sector") or item.get("industry") or "Indian Equity"
                    if not any(r["symbol"] == clean_sym for r in results):
                        results.append({
                            "symbol": clean_sym,
                            "name": name,
                            "exchange": exch,
                            "sector": sector,
                            "market": "INDIA",
                            "currency": cls.CURRENCY,
                            "currency_symbol": cls.CURRENCY_SYMBOL,
                        })
        except Exception as e:
            logger.debug(f"Indian dynamic search note: {e}")

        return results

    @classmethod
    def get_stock_fundamentals(cls, symbol: str, exchange: str = "NSE") -> Dict[str, Any]:
        """Fetches detailed financial statements and company fundamentals for an Indian stock."""
        ticker_sym = cls.format_ticker(symbol, exchange)
        ticker = yf.Ticker(ticker_sym)
        info = ticker.info or {}

        return {
            "symbol": symbol.upper(),
            "exchange": exchange.upper(),
            "market": "INDIA",
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
