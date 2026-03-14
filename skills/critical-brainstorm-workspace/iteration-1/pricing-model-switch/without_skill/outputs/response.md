# Switching from Per-Seat to Usage-Based Pricing: Key Considerations

This is a significant pricing transition with real revenue risk, so it's worth thinking through the mechanics carefully before committing.

## Why the 100x Usage Variance Matters

The fact that usage varies 100x across seats tells you something important: your per-seat model is massively cross-subsidizing. Low-usage seats are overpaying, and heavy-usage seats are getting a bargain. This creates two problems:

1. **Churn risk on the low end.** Customers with mostly light users are probably already questioning the value. They may be quietly reducing seat count or evaluating alternatives.
2. **Margin risk on the high end.** Your heaviest users may be costing you more to serve than the $50/seat covers, especially if API calls have real infrastructure cost behind them.

Usage-based pricing fixes the cross-subsidy, but that fix cuts both ways.

## What You'll Likely Gain

- **Expansion revenue from heavy users.** The customers generating 100x the calls are currently paying the same $50. Usage-based pricing captures that value.
- **Lower barrier to entry.** New customers can start small without committing to a seat count. This typically improves top-of-funnel conversion.
- **Better alignment with value delivered.** If your API calls map to outcomes your customers care about, charging per call feels fair and defensible.
- **Reduced "shelfware" objection.** Customers never feel like they're paying for something they're not using.

## What You'll Likely Lose (At Least Initially)

- **Revenue predictability.** Per-seat pricing gives you a clean MRR number. Usage-based revenue fluctuates monthly, which complicates forecasting and can spook investors or leadership.
- **Some revenue from light users.** Customers who were paying $50/seat but barely using the product will now pay much less. You need to be honest about how much of your current revenue comes from these accounts.
- **Simplicity in sales conversations.** "It's $50/seat" is easy. "It depends on your usage" requires estimation, which slows deal cycles and creates invoice disputes.

## The Transition Is the Hard Part

The pricing model itself matters less than how you migrate existing customers. A few practical considerations:

**Run the numbers on your current base first.** Before announcing anything, simulate what every current customer would pay under the new model. Categorize them:
- Customers who'd pay more (your heavy users) -- they'll push back
- Customers who'd pay less (your light users) -- they'll be happy but you lose revenue
- Customers who'd pay roughly the same -- easiest group

**Consider a hybrid model.** Many companies land on a base platform fee plus usage. For example: $200/month base (replaces a few seats' worth of revenue) plus $0.01 per API call above a generous included tier. This preserves some revenue floor while capturing upside from heavy users.

**Grandfather existing customers or give a long runway.** Changing pricing on existing contracts mid-term is a trust violation. Common approaches:
- Lock existing customers into current pricing for 12 months
- Offer a "better of" period where they pay the lower of old vs. new pricing for 6 months
- Migrate at renewal only

**Watch for demand suppression.** When you switch to usage-based pricing, customers start watching their usage. Some will throttle API calls, implement caching, or reduce integrations to control costs. This is rational behavior on their part, but it means your revenue per customer may be lower than the simulation suggests.

## Questions to Answer Before Deciding

1. **What's your cost structure?** If marginal API calls are nearly free to serve, usage-based pricing may not be necessary -- you're just redistributing revenue. If each call has real cost, usage pricing aligns revenue with cost.

2. **What percentage of revenue comes from light users?** If 60% of your revenue comes from accounts that would pay less under usage pricing, you have a serious revenue risk to manage.

3. **Do your heavy users have alternatives?** If your biggest API consumers have options, raising their effective price through usage pricing may push them to competitors. If you have a moat, you can capture more value.

4. **Can your billing system handle it?** Usage-based billing requires metering infrastructure, usage dashboards for customers, alerting, and dispute resolution processes. This is non-trivial engineering and ops work.

5. **What does your sales team think?** They're the ones who have to sell and defend the new model. If they're not bought in, the transition will stall.

## A Practical Path Forward

Rather than a hard switch, consider a phased approach:

1. **Instrument everything.** Start tracking per-customer, per-seat usage data if you aren't already. You need at least 3-6 months of clean data.
2. **Introduce usage-based pricing for new customers only.** Keep existing customers on per-seat. This lets you test the model without risking current revenue.
3. **Add a usage tier to the existing model.** Introduce a usage cap on the per-seat plan with overage charges. This is a gentler first step that introduces customers to the concept.
4. **Migrate existing customers at renewal.** Give them the data showing what they would have paid, and offer the transition with appropriate safeguards.

The companies that handle this transition well tend to move deliberately and communicate transparently. The ones that stumble usually move too fast, surprise customers with higher bills, or underestimate the revenue impact from light-user accounts shrinking.
