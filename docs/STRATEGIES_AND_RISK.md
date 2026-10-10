# Strategy Rationale & Risk Management

## 1. Regulatory & Mathematical Disclaimer

> [!WARNING]
> This system is an automated, rule-based algorithmic decision-support tool. It computes verifiable indicators and applies predefined quantitative rules.
> 
> **It does not predict market prices with certainty and makes no guarantee of profit.**
> Signals are marked as "WATCH" candidates requiring owner review prior to manual execution.

---

## 2. Strategies Implemented

### Strategy 1: Trend Momentum Breakout (`MomentumBreakout`)
- **Objective**: Capture aggressive trending moves in liquid leaders.
- **Rule Confluence**:
  1. **Trend Alignment**: $\text{EMA}_{21} > \text{EMA}_{50}$ and $\text{Close} > \text{SMA}_{50}$.
  2. **Volume Breakout**: $\text{RVOL} \ge 1.25\times$ (Volume vs 20-day average).
  3. **RSI Strength**: $52.0 \le \text{RSI}_{14} \le 72.0$ (strong momentum, not exhausted).
  4. **Structure Test**: $\text{Price} \ge 0.99 \times \text{20-day High}$.
- **Risk Metrics**:
  - Stop Loss: $\text{Entry} - (1.5 \times \text{ATR}_{14})$
  - Target: $\text{Entry} + (3.0 \times \text{ATR}_{14})$
  - Risk/Reward: $\ge 2.0$

### Strategy 2: Mean Reversion Pullback (`MeanReversionPullback`)
- **Objective**: Enter established bull-market leaders on short-term oversold dips.
- **Rule Confluence**:
  1. **Macro Regime**: $\text{Price} \ge 0.95 \times \text{SMA}_{50}$ (structural uptrend intact).
  2. **Oversold Exhaustion**: $\text{RSI}_{14} \le 40.0$.
  3. **Support Confluence**: Price testing Classic Support $S_1 = 2 \times \text{Pivot} - \text{High}$.
- **Risk Metrics**:
  - Stop Loss: Below $S_2$ or $\text{Entry} - (1.2 \times \text{ATR}_{14})$
  - Target: Mean reversion to $\text{EMA}_{21}$ / Pivot
  - Risk/Reward: $\ge 1.8$

### Strategy 3: MACD Trend Crossover (`MacdCross`)
- **Objective**: Catch momentum inflection points confirmed by higher-timeframe trend.
- **Rule Confluence**:
  1. MACD Line crosses above Signal Line ($\text{MACD}_{\text{line}} > \text{MACD}_{\text{signal}}$).
  2. MACD Histogram expands positive.
  3. Filter: Price is above $\text{EMA}_{50}$.
- **Risk Metrics**:
  - Stop Loss: $\text{Entry} - (1.5 \times \text{ATR}_{14})$
  - Target: $\text{Entry} + (3.0 \times \text{ATR}_{14})$

---

## 3. Position Sizing & Portfolio Risk Controls

The **Risk Engine** (`app/risk/engine.py`) enforces strict capital preservation:

1. **Fixed Fractional Risk (2% Capital Rule)**:
   $$\text{Risk Amount} = \text{Total Capital} \times 0.02$$
   $$\text{Max Quantity} = \left\lfloor \frac{\text{Risk Amount}}{\text{Entry Price} - \text{Stop Loss}} \right\rfloor$$

2. **Single Stock Concentration Cap (10%)**:
   $$\text{Max Stock Value} = \text{Total Capital} \times 0.10$$

3. **Total Portfolio Exposure Cap (25%)**:
   Total invested value across all open positions is capped at $25\%$ of capital. New trades exceeding this threshold are blocked.
