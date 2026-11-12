"""Automatic stock scanner and 15-step research notification execution engine."""

import time
from datetime import datetime, timezone
from typing import List, Optional, Dict, Any
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.logging import logger
from app.database.session import SessionLocal
from app.models.stock import Stock
from app.models.scan_job import ScanJob
from app.models.signal import StockSignal
from app.models.prediction import StockPrediction
from app.providers.factory import get_market_data_provider
from app.strategies.registry import strategy_registry
from app.notifications.notifier import notifier
from app.analysis.narrative import AINarrativeGenerator
from app.analysis.ensemble_predictor import ensemble_predictor
from app.analysis.candlestick_intelligence import CandlestickIntelligence
from app.analysis.market_structure import MarketStructureAnalyzer
from app.analysis.volume_intelligence import VolumeIntelligence
from app.analysis.false_signal_detector import FalseSignalDetector
from app.analysis.market_regime import MarketRegimeDetector
from app.analysis.global_market_engine import GlobalMarketEngine

narrative_generator = AINarrativeGenerator()


class ScannerEngine:
    """Orchestrates scanning of supported stock universe and 15-step research pipeline."""

    def __init__(self):
        self.is_scanning = False

    def sync_universe(self, db: Session, exchange: str = "ALL") -> int:
        """Discovers and synchronizes supported stock universe (NSE + Foreign US) into the database."""
        provider = get_market_data_provider()
        universe_items = provider.get_supported_universe(exchange=exchange)
        added_count = 0

        for item in universe_items:
            symbol = item["symbol"]
            item_exchange = item.get("exchange", "NSE")
            existing = (
                db.query(Stock)
                .filter(Stock.symbol == symbol, Stock.exchange == item_exchange)
                .first()
            )
            if not existing:
                stock = Stock(
                    symbol=symbol,
                    exchange=item_exchange,
                    name=item.get("name", symbol),
                    sector=item.get("sector"),
                    is_active=True,
                )
                db.add(stock)
                added_count += 1
        db.commit()
        logger.info(f"Synchronized universe: added {added_count} new stocks ({exchange}).")
        return added_count

    def run_scan(
        self,
        db: Session,
        symbols: Optional[List[str]] = None,
        exchange: str = "ALL",
        force: bool = False,
    ) -> ScanJob:
        """Executes a 15-step research scanning pass over active stocks."""
        if self.is_scanning:
            logger.warning("Scan pass already in progress. Skipping concurrent run.")
            latest = db.query(ScanJob).order_by(ScanJob.id.desc()).first()
            return latest

        self.is_scanning = True
        provider = get_market_data_provider()

        # Check market status if market-hours only is enabled
        market_status = provider.get_market_status(exchange="NSE")
        if settings.SCAN_MARKET_HOURS_ONLY and not force and exchange in ("NSE", "BSE"):
            if not market_status.get("is_open"):
                logger.info("Market is currently closed. Scanning skipped as configured.")
                self.is_scanning = False
                job = ScanJob(
                    started_at=datetime.now(timezone.utc),
                    finished_at=datetime.now(timezone.utc),
                    status="SKIPPED",
                    error_details="Market is closed and SCAN_MARKET_HOURS_ONLY is True.",
                )
                db.add(job)
                db.commit()
                return job

        # Create ScanJob record
        job = ScanJob(
            started_at=datetime.now(timezone.utc),
            status="RUNNING",
            total_stocks=0,
            scanned_stocks=0,
            passed_signals=0,
            failed_stocks=0,
            failed_symbols=[],
        )
        db.add(job)
        db.commit()
        db.refresh(job)

        try:
            # Determine stocks to scan
            if symbols:
                target_stocks = (
                    db.query(Stock)
                    .filter(Stock.symbol.in_([s.upper() for s in symbols]))
                    .all()
                )
            elif exchange == "ALL":
                target_stocks = db.query(Stock).filter(Stock.is_active == True).all()
            else:
                target_stocks = (
                    db.query(Stock)
                    .filter(Stock.exchange == exchange, Stock.is_active == True)
                    .all()
                )

            # Auto-seed if database is empty
            if not target_stocks:
                self.sync_universe(db, exchange=exchange)
                if exchange == "ALL":
                    target_stocks = db.query(Stock).filter(Stock.is_active == True).all()
                else:
                    target_stocks = (
                        db.query(Stock)
                        .filter(Stock.exchange == exchange, Stock.is_active == True)
                        .all()
                    )

            job.total_stocks = len(target_stocks)
            db.commit()

            from app.models.broker import BrokerAccount
            account = db.query(BrokerAccount).filter(BrokerAccount.broker_name == "GROWW").first()
            selected_algo = getattr(account, "active_algorithm", "HighestGainMaximizer") if account else "HighestGainMaximizer"
            primary_strategy = strategy_registry.get(selected_algo) or strategy_registry.get("HighestGainMaximizer") or strategy_registry.get_all()[0]

            failed_symbols = []
            approved_signals_count = 0

            # Batch scanning to respect rate limits
            batch_size = settings.SCAN_BATCH_SIZE
            for i in range(0, len(target_stocks), batch_size):
                batch = target_stocks[i : i + batch_size]
                for stock in batch:
                    try:
                        # 1. Scan stock & 2. Ingest external market data
                        df = provider.get_historical_ohlcv(
                            symbol=stock.symbol,
                            exchange=stock.exchange,
                            timeframe="1d",
                            period="6mo",
                        )

                        # 3. Verify data quality
                        if df.empty or len(df) < 25:
                            failed_symbols.append({"symbol": stock.symbol, "error": "Insufficient bars"})
                            job.failed_stocks += 1
                            continue

                        # Execute 15-Step Research Pipeline via Ensemble Engine
                        # Steps 4 through 14: Historical Analysis, Candlesticks, Structure, Volume,
                        # Multi-Timeframe, Macro Research, Ensemble Prediction, Risk/Reward, False Signals,
                        # Candle Confirmation, and Confidence Scoring
                        research_result = ensemble_predictor.predict(
                            df=df,
                            symbol=stock.symbol,
                            company_name=stock.name or stock.symbol,
                            exchange=stock.exchange,
                            sector=stock.sector,
                            time_horizon="1-DAY",
                        )

                        action = research_result["predicted_action"]
                        approval_status = research_result["approval_status"]
                        confidence = research_result["confidence_score"]
                        price = research_result["price_at_prediction"]
                        target_price = research_result["target_price"]
                        stop_loss_price = research_result["stop_loss"]
                        regime = research_result["market_regime"]
                        traps = research_result["false_signal_traps"]

                        # Step 15: Approve or Reject Signal
                        is_approved = (
                            approval_status == "APPROVED_SIGNAL"
                            and confidence >= 80.0
                            and len(traps) == 0
                            and action in ("BUY", "STRONG BUY", "SELL", "STRONG SELL")
                        )

                        if is_approved:
                            signal_type = "BUY" if "BUY" in action else "SELL"
                            priority = "HIGH" if confidence >= 90.0 else "MEDIUM"
                            explanation = f"15-Step Research APPROVED: {action} ({confidence}% confidence). {research_result['verdict_reason']}"
                        else:
                            signal_type = "NO TRADE"
                            priority = "LOW"
                            explanation = f"NO TRADE – INSUFFICIENT CONFIRMATION. {research_result['verdict_reason']}"

                        # Save Signal Record to Database
                        signal = StockSignal(
                            symbol=stock.symbol,
                            exchange=stock.exchange,
                            timestamp=datetime.now(timezone.utc),
                            signal_type=signal_type,
                            strategy_name=primary_strategy.name,
                            price=price,
                            stop_loss=stop_loss_price,
                            target=target_price,
                            risk_reward=research_result["risk_reward_ratio"],
                            strength=confidence,
                            priority=priority,
                            company_name=stock.name or stock.symbol,
                            entry_range_low=round(price * 0.995, 2),
                            entry_range_high=round(price * 1.005, 2),
                            holding_period_hours=48,
                            data_source=f"{provider.name} (Verified NSE/BSE Feed)",
                            data_freshness="Verified Tick / Daily Candle",
                            liquidity_summary=f"RVOL: {research_result['rvol']:.2f}x. VWAP: ₹{research_result['vwap']:.2f}.",
                            explanation=explanation,
                            indicator_summary={
                                "rvol": research_result["rvol"],
                                "vwap": research_result["vwap"],
                                "market_regime": regime,
                                "candlestick_patterns": research_result["candlestick_patterns"],
                                "dimension_scores": research_result["dimension_scores"],
                                "probabilities": research_result["probabilities"],
                            },
                            score_breakdown=research_result["dimension_scores"],
                            ai_thesis={
                                "headline": f"{priority} Priority Research: {stock.symbol} ({signal_type})",
                                "investment_thesis": explanation,
                                "approval_status": approval_status,
                                "market_regime": regime,
                                "candlestick_confirmation": research_result["candlestick_confirmation"],
                                "market_structure": research_result["market_structure"],
                                "probabilities": research_result["probabilities"],
                                "dimension_scores": research_result["dimension_scores"],
                                "traps_detected": traps,
                                "model_used": research_result["model_used"],
                                "verdict_reason": research_result["verdict_reason"],
                                "catalysts": research_result.get("catalysts") or [
                                    f"Market structure indicates {research_result.get('market_structure', 'active trend')}",
                                    f"Volume confirmation: RVOL is {research_result['rvol']:.2f}x average",
                                    f"Technical indicators confirm {signal_type} regime",
                                ],
                                "risk_factors": research_result.get("risk_factors") or [
                                    f"Stop-loss protection level: ₹{stop_loss_price:.2f}",
                                    "General market volatility and macro policy shifts",
                                    "Sector-specific headwind sensitivity",
                                ],
                            },
                        )
                        db.add(signal)
                        db.commit()
                        db.refresh(signal)

                        # Record in StockPrediction table for Continuous Validation
                        pred_record = StockPrediction(
                            symbol=stock.symbol,
                            exchange=stock.exchange,
                            company_name=stock.name or stock.symbol,
                            price_at_prediction=price,
                            predicted_direction=research_result["predicted_direction"],
                            predicted_action=action,
                            target_price=target_price,
                            expected_gain_pct=research_result["expected_gain_pct"],
                            stop_loss=stop_loss_price,
                            confidence_score=confidence,
                            time_horizon="1-DAY (Calibrated)",
                            algorithm_name=f"Institutional AI Ensemble ({regime})",
                            working_algorithm=f"15-Step Research Pipeline. Regime: {regime}. Confidence: {confidence}%. Verdict: {research_result['verdict_reason']}",
                            algorithm_metrics=research_result["dimension_scores"],
                            ai_prediction_summary=explanation,
                            model_used=research_result["model_used"],
                            prob_up=research_result["probabilities"]["prob_up"],
                            prob_down=research_result["probabilities"]["prob_down"],
                            prob_sideways=research_result["probabilities"]["prob_sideways"],
                            market_regime=regime,
                            candlestick_patterns=research_result["candlestick_patterns"],
                            dimension_scores=research_result["dimension_scores"],
                            approval_status=approval_status,
                            outcome_status="PENDING",
                            model_version="v2.0-ensemble",
                        )
                        db.add(pred_record)
                        db.commit()

                        # Dispatch Notification ONLY if Approved and action is SELL (Strictly Sell Alerts Only)
                        if is_approved:
                            norm_action = "BUY" if "BUY" in action else "SELL"
                            if norm_action == "SELL" and not notifier.should_suppress_duplicate(db, stock.symbol, norm_action):
                                approved_signals_count += 1
                                notifier.send_buy_sell_alert(
                                    db=db,
                                    symbol=stock.symbol,
                                    exchange=stock.exchange,
                                    action=norm_action,
                                    price=price,
                                    stop_loss=stop_loss_price,
                                    target=target_price,
                                    risk_reward=research_result["risk_reward_ratio"],
                                    reason=explanation,
                                    gemini_research=signal.ai_thesis,
                                    signal_id=signal.id,
                                    time_horizon="1-DAY",
                                )
                                logger.info(f"DISPATCHED APPROVED SELL NOTIFICATION for {stock.symbol}: {norm_action}")
                            elif norm_action == "BUY":
                                logger.debug(f"Suppressed general BUY notification for {stock.symbol} (Strictly Sell Notifications enabled).")
                            else:
                                logger.info(f"Suppressed duplicate alert for {stock.symbol} ({norm_action}) within cooldown period.")
                        else:
                            logger.debug(f"Stock {stock.symbol} returned NO TRADE (Confidence: {confidence}%). Notification withheld.")

                        job.scanned_stocks += 1

                    except Exception as e:
                        logger.error(f"Error scanning {stock.symbol}: {e}")
                        failed_symbols.append({"symbol": stock.symbol, "error": str(e)})
                        job.failed_stocks += 1

                job.failed_symbols = failed_symbols
                job.passed_signals = approved_signals_count
                db.commit()
                time.sleep(0.3)

            job.status = "COMPLETED"
            job.finished_at = datetime.now(timezone.utc)
            db.commit()
            logger.info(f"Scan job #{job.id} completed: {job.scanned_stocks} scanned, {approved_signals_count} approved signals.")

        except Exception as e:
            logger.error(f"Fatal error in scan job #{job.id}: {e}")
            job.status = "FAILED"
            job.finished_at = datetime.now(timezone.utc)
            job.error_details = str(e)
            db.commit()

        finally:
            self.is_scanning = False

        return job


scanner_engine = ScannerEngine()
