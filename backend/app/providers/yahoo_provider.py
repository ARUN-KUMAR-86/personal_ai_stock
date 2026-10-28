"""Yahoo Finance market data provider for NSE and BSE stocks."""

from datetime import datetime, timezone, timedelta
from typing import List, Dict, Any, Optional
import yfinance as yf
import pandas as pd
from app.core.logging import logger
from app.core.exceptions import MarketDataProviderError
from app.providers.base import BaseMarketDataProvider
from app.schemas.candle import QuoteRead

# Comprehensive High-Liquidity Universe of Top NSE Indian Stocks (Internet Daily Search Universe)
NIFTY_50_UNIVERSE = [
    {"symbol": "RELIANCE", "name": "Reliance Industries Ltd", "exchange": "NSE", "sector": "Energy"},
    {"symbol": "JPL", "name": "Jio Platforms Ltd", "exchange": "NSE", "sector": "Telecom & Digital Services"},
    {"symbol": "JIOFIN", "name": "Jio Financial Services Ltd", "exchange": "NSE", "sector": "Financials"},
    {"symbol": "ZOMATO", "name": "Zomato Ltd", "exchange": "NSE", "sector": "Consumer Services"},
    {"symbol": "TCS", "name": "Tata Consultancy Services Ltd", "exchange": "NSE", "sector": "Technology"},
    {"symbol": "HDFCBANK", "name": "HDFC Bank Ltd", "exchange": "NSE", "sector": "Financials"},
    {"symbol": "INFY", "name": "Infosys Ltd", "exchange": "NSE", "sector": "Technology"},
    {"symbol": "ICICIBANK", "name": "ICICI Bank Ltd", "exchange": "NSE", "sector": "Financials"},
    {"symbol": "BHARTIARTL", "name": "Bharti Airtel Ltd", "exchange": "NSE", "sector": "Telecom"},
    {"symbol": "SBIN", "name": "State Bank of India", "exchange": "NSE", "sector": "Financials"},
    {"symbol": "LICI", "name": "Life Insurance Corp of India", "exchange": "NSE", "sector": "Financials"},
    {"symbol": "ITC", "name": "ITC Ltd", "exchange": "NSE", "sector": "Consumer Goods"},
    {"symbol": "HINDUNILVR", "name": "Hindustan Unilever Ltd", "exchange": "NSE", "sector": "Consumer Goods"},
    {"symbol": "LT", "name": "Larsen & Toubro Ltd", "exchange": "NSE", "sector": "Capital Goods"},
    {"symbol": "BAJFINANCE", "name": "Bajaj Finance Ltd", "exchange": "NSE", "sector": "Financials"},
    {"symbol": "HCLTECH", "name": "HCL Technologies Ltd", "exchange": "NSE", "sector": "Technology"},
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
    {"symbol": "BAJAJFINSV", "name": "Bajaj Finserv Ltd", "exchange": "NSE", "sector": "Financials"},
    {"symbol": "BAJAJ-AUTO", "name": "Bajaj Auto Ltd", "exchange": "NSE", "sector": "Automobile"},
    {"symbol": "COALINDIA", "name": "Coal India Ltd", "exchange": "NSE", "sector": "Energy"},
    {"symbol": "WIPRO", "name": "Wipro Ltd", "exchange": "NSE", "sector": "Technology"},
    {"symbol": "POWERGRID", "name": "Power Grid Corp of India", "exchange": "NSE", "sector": "Utilities"},
    {"symbol": "ULTRACEMCO", "name": "UltraTech Cement Ltd", "exchange": "NSE", "sector": "Materials"},
    {"symbol": "TATASTEEL", "name": "Tata Steel Ltd", "exchange": "NSE", "sector": "Metals & Mining"},
    {"symbol": "JSWSTEEL", "name": "JSW Steel Ltd", "exchange": "NSE", "sector": "Metals & Mining"},
    {"symbol": "ASIANPAINT", "name": "Asian Paints Ltd", "exchange": "NSE", "sector": "Consumer Goods"},
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
]

# Foreign / US Mega-Cap Stock Universe (Global Leaders)
GLOBAL_US_UNIVERSE = [
    {"symbol": "NVDA", "name": "NVIDIA Corporation", "exchange": "US", "sector": "Semiconductors"},
    {"symbol": "AAPL", "name": "Apple Inc.", "exchange": "US", "sector": "Consumer Electronics"},
    {"symbol": "MSFT", "name": "Microsoft Corporation", "exchange": "US", "sector": "Cloud & Software"},
    {"symbol": "TSLA", "name": "Tesla Inc.", "exchange": "US", "sector": "Automobile & Clean Energy"},
    {"symbol": "AMZN", "name": "Amazon.com Inc.", "exchange": "US", "sector": "E-Commerce & Cloud"},
    {"symbol": "GOOGL", "name": "Alphabet Inc.", "exchange": "US", "sector": "Internet & AI"},
    {"symbol": "META", "name": "Meta Platforms Inc.", "exchange": "US", "sector": "Social Media & AI"},
    {"symbol": "AMD", "name": "Advanced Micro Devices", "exchange": "US", "sector": "Semiconductors"},
    {"symbol": "NFLX", "name": "Netflix Inc.", "exchange": "US", "sector": "Streaming Media"},
    {"symbol": "PLTR", "name": "Palantir Technologies", "exchange": "US", "sector": "Enterprise AI"},
]


class YahooMarketDataProvider(BaseMarketDataProvider):
    """Fetches real market quotes and candles using Yahoo Finance."""

    def __init__(self):
        super().__init__(name="YahooFinance")
        self._quote_cache: Dict[str, tuple[QuoteRead, datetime]] = {}
        self._cache_duration = timedelta(seconds=180)  # 3 minute cache

    def _format_ticker(self, symbol: str, exchange: str) -> str:
        """Appends appropriate exchange suffix for Yahoo Finance."""
        sym = symbol.strip().upper()
        if sym == "JIO":
            return "JPL.NS"
        if sym.endswith(".NS") or sym.endswith(".BO"):
            return sym
        if exchange.upper() in ("US", "NASDAQ", "NYSE", "GLOBAL"):
            return sym
        if exchange.upper() == "BSE":
            return f"{sym}.BO"
        return f"{sym}.NS"

    def get_supported_universe(self, exchange: str = "ALL") -> List[Dict[str, Any]]:
        ex = exchange.upper()
        if ex in ("US", "NASDAQ", "NYSE", "GLOBAL"):
            return [dict(s, exchange="US") for s in GLOBAL_US_UNIVERSE]
        elif ex in ("NSE", "BSE", "INDIA"):
            return [dict(s, exchange="NSE") for s in NIFTY_50_UNIVERSE]
        else:
            return [dict(s, exchange="NSE") for s in NIFTY_50_UNIVERSE] + [dict(s, exchange="US") for s in GLOBAL_US_UNIVERSE]

    def get_quote(self, symbol: str, exchange: str = "NSE") -> QuoteRead:
        cache_key = f"{symbol}:{exchange}"
        now = datetime.now(timezone.utc)
        if cache_key in self._quote_cache:
            cached_quote, cached_at = self._quote_cache[cache_key]
            if now - cached_at < self._cache_duration:
                return cached_quote

        ticker_sym = self._format_ticker(symbol, exchange)
        try:
            ticker = yf.Ticker(ticker_sym)
            fast_info = getattr(ticker, "fast_info", None)
            
            if fast_info and getattr(fast_info, "last_price", None) is not None:
                price = float(fast_info.last_price)
                prev_close = float(fast_info.previous_close or price)
                change = price - prev_close
                pct_change = (change / prev_close) * 100 if prev_close else 0.0
                open_p = float(fast_info.open or price)
                high_p = float(fast_info.day_high or price)
                low_p = float(fast_info.day_low or price)
                volume = float(fast_info.last_volume or 0.0)
            else:
                hist = ticker.history(period="5d", interval="1d")
                if hist.empty:
                    raise MarketDataProviderError(f"No price history found for {ticker_sym}")
                latest = hist.iloc[-1]
                prev = hist.iloc[-2] if len(hist) > 1 else latest
                price = float(latest["Close"])
                prev_close = float(prev["Close"])
                change = price - prev_close
                pct_change = (change / prev_close) * 100 if prev_close else 0.0
                open_p = float(latest["Open"])
                high_p = float(latest["High"])
                low_p = float(latest["Low"])
                volume = float(latest["Volume"])

            quote = QuoteRead(
                symbol=symbol.upper(),
                exchange=exchange.upper(),
                price=round(price, 2),
                change=round(change, 2),
                percent_change=round(pct_change, 2),
                open=round(open_p, 2),
                high=round(high_p, 2),
                low=round(low_p, 2),
                previous_close=round(prev_close, 2),
                volume=round(volume, 0),
                timestamp=now,
                is_live=False,  # Yahoo Finance public tier is ~15 min delayed for Indian markets
                is_delayed=True,
                data_source="YahooFinance-Delayed",
            )
            self._quote_cache[cache_key] = (quote, now)
            return quote
        except Exception as e:
            logger.error(f"Error fetching quote for {ticker_sym}: {e}")
            raise MarketDataProviderError(f"Failed to fetch market quote for {symbol}: {str(e)}")

    def get_bulk_quotes(self, symbols: List[str], exchange: str = "NSE") -> Dict[str, QuoteRead]:
        """Fetches quotes for multiple symbols in parallel with caching."""
        results: Dict[str, QuoteRead] = {}
        now = datetime.now(timezone.utc)
        to_fetch = []
        for s in symbols:
            ck = f"{s.upper()}:{exchange.upper()}"
            if ck in self._quote_cache:
                q, t = self._quote_cache[ck]
                if now - t < timedelta(seconds=60):
                    results[s.upper()] = q
                    continue
            to_fetch.append(s)

        if to_fetch:
            from concurrent.futures import ThreadPoolExecutor

            def _fetch_one(sym: str):
                try:
                    return sym.upper(), self.get_quote(sym, exchange)
                except Exception:
                    return sym.upper(), None

            with ThreadPoolExecutor(max_workers=min(12, max(len(to_fetch), 1))) as pool:
                fetched = list(pool.map(_fetch_one, to_fetch))
                for sym, q in fetched:
                    if q:
                        results[sym] = q

        return results

    def search_stocks(self, query: str, exchange: str = "NSE") -> List[Dict[str, Any]]:
        """Dynamically searches predefined universe and internet/Yahoo Finance for stocks."""
        q = query.strip().upper()
        if not q:
            return []
        results = []
        # 1. Match local predefined universe
        universe = self.get_supported_universe(exchange)
        for u in universe:
            if q in u["symbol"].upper() or q in u["name"].upper():
                results.append(dict(u))

        # 2. Dynamic live search via Yahoo Finance (covers newly listed IPOs like JPL / Jio)
        try:
            search_obj = yf.Search(query, max_results=8)
            for item in getattr(search_obj, "quotes", []):
                sym = item.get("symbol", "")
                if not sym:
                    continue
                name = item.get("longname") or item.get("shortname") or sym
                if ".NS" in sym:
                    exch = "NSE"
                elif ".BO" in sym:
                    exch = "BSE"
                elif item.get("quoteType") == "EQUITY":
                    exch = "US"
                else:
                    continue

                clean_sym = sym.replace(".NS", "").replace(".BO", "")
                sector = item.get("sector") or item.get("industry") or "General"
                if not any(r["symbol"] == clean_sym and r["exchange"] == exch for r in results):
                    results.append({
                        "symbol": clean_sym,
                        "name": name,
                        "exchange": exch,
                        "sector": sector,
                    })
        except Exception as e:
            logger.warning(f"Yahoo dynamic search error for '{query}': {e}")

        return results

    def get_historical_ohlcv(
        self,
        symbol: str,
        exchange: str = "NSE",
        timeframe: str = "1d",
        period: str = "1y",
        start: Optional[datetime] = None,
        end: Optional[datetime] = None,
    ) -> pd.DataFrame:
        ticker_sym = self._format_ticker(symbol, exchange)
        try:
            ticker = yf.Ticker(ticker_sym)
            if start and end:
                hist = ticker.history(start=start.strftime("%Y-%m-%d"), end=end.strftime("%Y-%m-%d"), interval=timeframe)
            else:
                hist = ticker.history(period=period, interval=timeframe)

            # Robust Fallback for Newly Listed IPOs (like JPL / Jio) with < 20 daily bars
            if (hist.empty or len(hist) < 20) and not (start and end):
                try:
                    hist_intra = ticker.history(period="5d", interval="15m")
                    if not hist_intra.empty and len(hist_intra) >= len(hist):
                        hist = hist_intra
                    elif hist.empty:
                        hist_5m = ticker.history(period="1d", interval="5m")
                        if not hist_5m.empty:
                            hist = hist_5m
                except Exception as intra_e:
                    logger.debug(f"Intraday fallback note for {ticker_sym}: {intra_e}")

            if hist.empty:
                raise MarketDataProviderError(f"Historical data for {ticker_sym} is empty")

            hist = hist.reset_index()
            # Standardize column names
            date_col = "Date" if "Date" in hist.columns else "Datetime"
            hist = hist.rename(
                columns={
                    date_col: "timestamp",
                    "Open": "open",
                    "High": "high",
                    "Low": "low",
                    "Close": "close",
                    "Volume": "volume",
                }
            )
            hist["timestamp"] = pd.to_datetime(hist["timestamp"], utc=True)
            return hist[["timestamp", "open", "high", "low", "close", "volume"]]
        except Exception as e:
            logger.error(f"Error fetching historical data for {ticker_sym}: {e}")
            raise MarketDataProviderError(f"Failed to fetch historical OHLCV for {symbol}: {str(e)}")
