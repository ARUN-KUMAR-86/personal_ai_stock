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

# Foreign / US Mega-Cap Stock Universe (Global Leaders - NYSE & NASDAQ)
from app.providers.us_market_service import US_STOCKS_UNIVERSE
GLOBAL_US_UNIVERSE = US_STOCKS_UNIVERSE


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
        if sym == "TATAMOTORS":
            return "TMPV.NS"
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
        price = None
        prev_close = 100.0
        change = 0.0
        pct_change = 0.0
        open_p = 100.0
        high_p = 100.0
        low_p = 100.0
        volume = 0.0

        try:
            ticker = yf.Ticker(ticker_sym)
            try:
                fast_info = getattr(ticker, "fast_info", None)
                if fast_info:
                    last_p = getattr(fast_info, "last_price", None)
                    if last_p is not None:
                        price = float(last_p)
                        prev_close = float(getattr(fast_info, "previous_close", None) or price)
                        change = price - prev_close
                        pct_change = (change / prev_close) * 100 if prev_close else 0.0
                        open_p = float(getattr(fast_info, "open", None) or price)
                        high_p = float(getattr(fast_info, "day_high", None) or price)
                        low_p = float(getattr(fast_info, "day_low", None) or price)
                        volume = float(getattr(fast_info, "last_volume", None) or 0.0)
            except Exception:
                price = None

            if price is None:
                try:
                    hist = ticker.history(period="5d", interval="1d")
                    if not hist.empty:
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
                except Exception:
                    pass

            if price is None:
                # Fallback quote so server never freezes on slow/delisted tickers
                price = 100.0
                prev_close = 100.0

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
            logger.debug(f"Note on quote fetch for {ticker_sym}: {e}")
            fallback_quote = QuoteRead(
                symbol=symbol.upper(),
                exchange=exchange.upper(),
                price=100.0,
                change=0.0,
                percent_change=0.0,
                open=100.0,
                high=100.0,
                low=100.0,
                previous_close=100.0,
                volume=0.0,
                timestamp=now,
                is_live=False,
                is_delayed=True,
                data_source="Fallback-Safe",
            )
            self._quote_cache[cache_key] = (fallback_quote, now)
            return fallback_quote

    def get_bulk_quotes(self, symbols: List[str], exchange: str = "NSE") -> Dict[str, QuoteRead]:
        """Fetches quotes for multiple symbols in parallel with caching."""
        results: Dict[str, QuoteRead] = {}
        now = datetime.now(timezone.utc)
        to_fetch = []
        for s in symbols:
            ck = f"{s.upper()}:{exchange.upper()}"
            if ck in self._quote_cache:
                q, t = self._quote_cache[ck]
                if now - t < timedelta(seconds=120):
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

            with ThreadPoolExecutor(max_workers=min(20, max(len(to_fetch), 1))) as pool:
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
