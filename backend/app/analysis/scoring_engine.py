"""Dynamic Multi-Dimensional Quality and Confidence Scoring Engine.

Computes 8 independent objective dimension scores (0-100):
1. Data Quality Score
2. Technical Confirmation Score
3. Candlestick Confirmation Score
4. Market Structure Score
5. Volume Confirmation Score
6. Global Market & Macro Score
7. Model Prediction Score
8. Risk / Reward Quality Score

Enforces strict research thresholds:
- 90 - 100: Very Strong Setup (High Priority)
- 80 - 89: Strong Setup (Standard Confirmed)
- 70 - 79: Watchlist Only
- Below 70: NO TRADE – INSUFFICIENT CONFIRMATION
"""

from typing import Dict, Any, Optional
import numpy as np


class QualityScoringEngine:
    """Calculates multi-factor confidence and enforces institutional quality gating."""

    @classmethod
    def evaluate_all_scores(
        cls,
        data_quality_metrics: Dict[str, Any],
        technical_metrics: Dict[str, Any],
        candlestick_metrics: Dict[str, Any],
        market_structure_metrics: Dict[str, Any],
        volume_metrics: Dict[str, Any],
        global_market_metrics: Dict[str, Any],
        model_metrics: Dict[str, Any],
        risk_reward_ratio: float,
        proposed_action: str = "BUY",
    ) -> Dict[str, Any]:
        """Synthesizes all 8 dimension scores and computes calibrated composite confidence."""
        
        # 1. Data Quality Score (0-100)
        dq_score = 100.0
        if not data_quality_metrics.get("is_complete", True):
            dq_score -= 30.0
        if data_quality_metrics.get("is_delayed", False):
            dq_score -= 15.0
        if data_quality_metrics.get("bar_count", 100) < 50:
            dq_score -= 20.0
        data_quality_score = float(np.clip(dq_score, 10.0, 100.0))

        # 2. Technical Confirmation Score (0-100)
        tech_score = 50.0
        rsi = float(technical_metrics.get("rsi_14") or 50.0)
        supertrend_dir = int(technical_metrics.get("supertrend_dir", 1))
        adx = float(technical_metrics.get("adx_14") or 20.0)
        price = float(technical_metrics.get("close") or 0.0)
        ema_21 = float(technical_metrics.get("ema_21") or price)
        ema_50 = float(technical_metrics.get("ema_50") or price)
        sma_50 = float(technical_metrics.get("sma_50") or price)

        if proposed_action == "BUY":
            if price >= ema_21 and ema_21 >= ema_50:
                tech_score += 20.0
            if price >= sma_50:
                tech_score += 10.0
            if supertrend_dir == 1:
                tech_score += 10.0
            if 50.0 <= rsi <= 68.0:
                tech_score += 15.0  # Momentum sweet spot
            elif rsi > 75.0:
                tech_score -= 10.0  # Extended overbought
            if adx >= 22.0:
                tech_score += 10.0
            elif adx < 16.0:
                tech_score -= 15.0  # Choppy
        elif proposed_action == "SELL":
            if price <= ema_21 and ema_21 <= ema_50:
                tech_score += 20.0
            if price <= sma_50:
                tech_score += 10.0
            if supertrend_dir == -1:
                tech_score += 10.0
            if 30.0 <= rsi <= 48.0:
                tech_score += 15.0
            if adx >= 22.0:
                tech_score += 10.0

        technical_score = float(np.clip(tech_score, 10.0, 95.0))

        # 3. Candlestick Confirmation Score (0-100)
        candlestick_score = float(candlestick_metrics.get("pattern_score", 50.0))

        # 4. Market Structure Score (0-100)
        market_structure_score = float(market_structure_metrics.get("structure_score", 50.0))

        # 5. Volume Confirmation Score (0-100)
        volume_score = float(volume_metrics.get("volume_score", 50.0))

        # 6. Global Market & Macro Score (0-100)
        global_market_score = float(global_market_metrics.get("macro_score", 50.0))

        # 7. Model Prediction Score (0-100)
        model_score = float(model_metrics.get("ensemble_confidence", 50.0))

        # 8. Risk / Reward Quality Score (0-100)
        if risk_reward_ratio >= 3.0:
            risk_reward_score = 95.0
        elif risk_reward_ratio >= 2.5:
            risk_reward_score = 88.0
        elif risk_reward_ratio >= 2.0:
            risk_reward_score = 80.0
        elif risk_reward_ratio >= 1.5:
            risk_reward_score = 65.0
        elif risk_reward_ratio >= 1.0:
            risk_reward_score = 40.0
        else:
            risk_reward_score = 20.0

        # Weighted Composite Confidence Calculation
        # Weights:
        # Technical: 15%, Candlestick: 15%, Structure: 20%, Volume: 15%,
        # Macro: 10%, Model Ensemble: 15%, Risk/Reward: 10%
        composite = (
            (technical_score * 0.15)
            + (candlestick_score * 0.15)
            + (market_structure_score * 0.20)
            + (volume_score * 0.15)
            + (global_market_score * 0.10)
            + (model_score * 0.15)
            + (risk_reward_score * 0.10)
        )

        # Severe penalty if data quality is degraded
        if data_quality_score < 70.0:
            composite = min(composite, 60.0)

        composite_confidence = round(float(np.clip(composite, 10.0, 96.0)), 1)

        # Calibrated Tier
        if composite_confidence >= 90.0:
            setup_quality = "VERY_STRONG_SETUP"
            signal_eligible = True
            suggested_action = proposed_action
        elif composite_confidence >= 80.0:
            setup_quality = "STRONG_SETUP"
            signal_eligible = True
            suggested_action = proposed_action
        elif composite_confidence >= 70.0:
            setup_quality = "WATCHLIST_ONLY"
            signal_eligible = False
            suggested_action = f"{proposed_action} WATCHLIST"
        else:
            setup_quality = "NO_TRADE_INSUFFICIENT_CONFIRMATION"
            signal_eligible = False
            suggested_action = "NO TRADE"

        return {
            "composite_confidence": composite_confidence,
            "setup_quality": setup_quality,
            "signal_eligible": signal_eligible,
            "suggested_action": suggested_action,
            "data_quality_score": round(data_quality_score, 1),
            "technical_score": round(technical_score, 1),
            "candlestick_score": round(candlestick_score, 1),
            "market_structure_score": round(market_structure_score, 1),
            "volume_score": round(volume_score, 1),
            "global_market_score": round(global_market_score, 1),
            "model_score": round(model_score, 1),
            "risk_reward_score": round(risk_reward_score, 1),
        }
