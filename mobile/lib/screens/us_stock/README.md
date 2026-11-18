# US Stock Full Details Module (Zed Dev)

This folder contains all screen components, widgets, and calculation models specifically dedicated to **US Equities** (NASDAQ, NYSE, AMEX).

## Folder Structure
- `us_stock_detail_screen.dart`: Complete standalone Full Details screen for US stocks.
- `us_stock_metrics_card.dart`: Wall Street trading sessions (Regular, Pre-market, After-hours), fundamentals formatted in USD ($B / $T), P/E, EPS, and US Federal Reserve macro framework.
- `us_order_calculation_card.dart`: Zero-commission equity sizing, statutory SEC transaction fee ($0.0000278), FINRA TAF ($0.000166/share), and USD net profit calculations.

## How to Edit in Zed Dev
- **Currency & Formats**: All values are explicitly formatted in USD (`$`). To adjust presets ($100, $500, etc.), edit `us_order_calculation_card.dart`.
- **Trading Hours**: Market session logic is isolated in `UsStockMetricsCard.getUsMarketSessionStatus()` (09:30 - 16:00 EST).
- **Fees**: Statutory SEC & FINRA fee formulas are located in `UsOrderCalculationCard.computeUsFees()`.
- Changes made in this directory **will not** affect Indian stock workflows or screens.
