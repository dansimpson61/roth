# Roth Conversion Directional Estimator

A minimalist, high-level Roth conversion scenario tool. Directional only; not tax preparation software. Focus: compare a simple conversion strategy to baseline.

## Scope Contract (Deliberate Omissions)
- Federal only (MFJ). No state tax.
- Simplified brackets & standard deduction, inflated by single rate.
- Social Security: user-supplied flat annual amount & start year. 85% taxable assumption simplified to full inclusion.
- MAGI == gross income for this model.
- IRMAA: tier assignment + flat annual surcharge applied with 2-year lag.
- RMD: simplified table subset.
- No credits, itemized deductions, capital gains, QBI, AMT.

## Run
```
bundle install
ruby app.rb -p 4567
```
Open http://localhost:4567

## Tests
```
rspec
```

## Next Steps (Optional)
1. Add Target MAGI strategy.
2. Add stacked area chart visualization.
3. Add IRMAA tier strip display.
