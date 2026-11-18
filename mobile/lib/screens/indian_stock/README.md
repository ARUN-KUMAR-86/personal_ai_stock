# Indian Stock Full Details Module (Zed Dev)

This folder contains all screen components, widgets, and calculation models specifically dedicated to **Indian Equities** (NSE, BSE).

## Folder Structure
- `indian_stock_detail_screen.dart`: Complete standalone Full Details screen for Indian stocks.
- `indian_stock_metrics_card.dart`: IST trading sessions (09:15 - 15:30 IST, Pre-open, Post-market), fundamentals formatted in INR (₹ Cr / Lakh Cr), P/E, EPS, and Reserve Bank of India (RBI) macro framework.
- `indian_order_calculation_card.dart`: Indian statutory levies calculator (STT 0.1%, Brokerage ₹20, DP charges ₹15.93, SEBI/stamp, GST), Groww broker login status & margin, and INR net profit calculations.

## How to Edit in Zed Dev
- **Currency & Formats**: All values are explicitly formatted in INR (`₹`). To adjust presets (₹5,000, ₹10,000, etc.), edit `indian_order_calculation_card.dart`.
- **Trading Hours**: Market session logic is isolated in `IndianStockMetricsCard.getIndianMarketSessionStatus()` (09:15 - 15:30 IST).
- **Statutory Levies & Taxes**: Indian STT, DP, and Brokerage formulas are located in `IndianOrderCalculationCard.computeIndianCharges()`.
- Changes made in this directory **will not** affect US stock workflows or screens.
