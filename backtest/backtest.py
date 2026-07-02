"""Backtest 4 candidate strategies for a small T212 account.

Cost model: 0.20% per side (0.15% T212 FX fee + ~0.05% spread/slippage).
Data:
  - Daily 1990-2022: skfolio S&P500 index + 20 large caps (survivorship-biased, noted).
  - Monthly 1953-2026: Shiller S&P (TR), gold, US 10Y yield -> bond TR approximation.
"""
import numpy as np
import pandas as pd
from pathlib import Path
from skfolio.datasets import load_sp500_dataset, load_sp500_index

COST = 0.0020  # per side

S = str(Path(__file__).parent / "data")

# ---------- helpers ----------
def stats(rets, freq, name, turnover_py=None, exposure=None):
    rets = rets.dropna()
    eq = (1 + rets).cumprod()
    yrs = len(rets) / freq
    cagr = eq.iloc[-1] ** (1 / yrs) - 1
    vol = rets.std() * np.sqrt(freq)
    sharpe = (rets.mean() * freq) / vol if vol > 0 else np.nan
    dd = (eq / eq.cummax() - 1).min()
    out = dict(name=name, yrs=round(yrs, 1), CAGR=round(100 * cagr, 2),
               Vol=round(100 * vol, 1), Sharpe=round(sharpe, 2),
               MaxDD=round(100 * dd, 1))
    if turnover_py is not None: out["trades/yr"] = round(turnover_py, 1)
    if exposure is not None: out["exposure%"] = round(100 * exposure, 0)
    return out

def rsi(series, period=2):
    delta = series.diff()
    up = delta.clip(lower=0).ewm(alpha=1/period, adjust=False).mean()
    dn = (-delta.clip(upper=0)).ewm(alpha=1/period, adjust=False).mean()
    rs = up / dn
    return 100 - 100 / (1 + rs)

results = []

# ---------- monthly multi-asset data (1953-2026) ----------
sp = pd.read_csv(f"{S}/sp500_monthly.csv", parse_dates=["Date"]).set_index("Date")
gold = pd.read_csv(f"{S}/gold_monthly.csv")
gold["Date"] = pd.to_datetime(gold["Date"], format="%Y-%m")
gold = gold.set_index("Date")["Price"]
y10 = pd.read_csv(f"{S}/us10y_monthly.csv", parse_dates=["Date"]).set_index("Date")["Rate"]

sp = sp[["SP500", "Dividend"]].copy()
sp.loc[sp["Dividend"] == 0, "Dividend"] = np.nan
# forward-fill dividend *yield* for missing recent months
divy = (sp["Dividend"] / sp["SP500"]).ffill()
sp_tr = sp["SP500"].pct_change() + divy / 12.0

g_ret = gold.pct_change()
# 10Y bond total return approximation (duration ~7.5, convexity ~70)
dy = y10.diff() / 100.0
bond_tr = y10.shift(1) / 100.0 / 12.0 - 7.5 * dy + 0.5 * 70 * dy ** 2
# cash proxy: rough T-bill = max(10Y - 1.4, 0.1)
cash_ret = ((y10 - 1.4).clip(lower=0.1) / 100.0 / 12.0).shift(0)

m = pd.DataFrame({"stocks": sp_tr, "gold": g_ret, "bonds": bond_tr, "cash": cash_ret}).dropna()
m = m.loc["1954-01-01":]
px = (1 + m).cumprod()  # synthetic TR price series
print("monthly panel:", m.index[0].date(), "->", m.index[-1].date(), m.shape)

def run_monthly(holdings, rets_panel, name, splits=True):
    """holdings: Series of asset name chosen at each month END (applied next month)."""
    h = holdings.shift(1).dropna()
    r = pd.Series(index=h.index, dtype=float)
    for dt, asset in h.items():
        r[dt] = rets_panel.loc[dt, asset]
    switches = (h != h.shift(1)).sum()
    yrs = len(h) / 12
    # cost: full portfolio switch = sell + buy = 2 sides
    costs = pd.Series(0.0, index=h.index)
    costs[h != h.shift(1)] = 2 * COST
    r_net = r - costs
    expo = (h != "cash").mean()
    results.append(stats(r_net, 12, name, switches / yrs, expo))
    if splits:
        for lo, hi, tag in [("1954", "1989", "54-89"), ("1990", "2009", "90-09"), ("2010", "2026", "10-26")]:
            sub = r_net.loc[lo:hi]
            if len(sub) > 24:
                results.append(stats(sub, 12, f"  {name} [{tag}]"))
    return r_net

# A. Dual momentum (stocks vs gold, absolute filter vs cash 12m, fallback bonds)
mom12 = px[["stocks", "gold"]].pct_change(12).iloc[12:]
cash12 = px["cash"].pct_change(12).iloc[12:]
best = mom12.idxmax(axis=1)
abs_ok = mom12.max(axis=1) > cash12
holdA = best.where(abs_ok, "bonds").dropna()
run_monthly(holdA, m, "A. DualMomentum s/g/b")

# B. Trend filter: stocks if price > 10m SMA else bonds
sma10 = px["stocks"].rolling(10).mean()
holdB = pd.Series(np.where(px["stocks"] > sma10, "stocks", "bonds"), index=px.index)
holdB = holdB[sma10.notna()]
run_monthly(holdB, m, "B. TrendFilter 10mSMA")

# A2. Combined: dual momentum + trend (hold winner only if above its own 10m SMA)
sma_g = px["gold"].rolling(10).mean()
above = pd.DataFrame({"stocks": px["stocks"] > sma10, "gold": px["gold"] > sma_g})
holdC = []
for dt in px.index:
    if dt not in mom12.index or pd.isna(mom12.loc[dt].max()) or pd.isna(sma10.loc[dt]):
        holdC.append(np.nan); continue
    b = mom12.loc[dt].idxmax()
    if above.loc[dt, b] and mom12.loc[dt, b] > cash12.loc[dt]:
        holdC.append(b)
    else:
        holdC.append("bonds")
holdC = pd.Series(holdC, index=px.index).dropna()
run_monthly(holdC, m, "C. DualMom+Trend")

# Benchmarks
results.append(stats(m["stocks"], 12, "BH stocks (SP500 TR)"))
results.append(stats(m.loc["2010":, "stocks"], 12, "  BH stocks [10-26]"))

# ---------- daily data (1990-2022) ----------
idx = load_sp500_index()["SP500"]
stocks = load_sp500_dataset()
d_ret = idx.pct_change()

# D. RSI-2 mean reversion on index: long if RSI2<10 and px>200SMA; exit RSI2>65
sma200 = idx.rolling(200).mean()
r2 = rsi(idx, 2)
pos = pd.Series(0.0, index=idx.index)
in_pos = False
for i in range(200, len(idx)):
    if not in_pos and r2.iloc[i] < 10 and idx.iloc[i] > sma200.iloc[i]:
        in_pos = True
    elif in_pos and (r2.iloc[i] > 65 or idx.iloc[i] < sma200.iloc[i]):
        in_pos = False
    pos.iloc[i] = 1.0 if in_pos else 0.0
entries = ((pos == 1) & (pos.shift(1) == 0)).sum()
strat = pos.shift(1) * d_ret
trade_cost = pd.Series(0.0, index=idx.index)
trade_cost[(pos != pos.shift(1))] = COST
strat_net = (strat - trade_cost).dropna()
yrs_d = len(strat_net) / 252
results.append(stats(strat_net, 252, "D. RSI2 meanrev (daily)", 2 * entries / yrs_d, pos.mean()))
results.append(stats(strat_net.loc["2010":], 252, "  D. RSI2 [10-22]"))

# E. Daily 200SMA trend on index (to cash), 1% band to cut whipsaw
band_hi, band_lo = sma200 * 1.01, sma200 * 0.99
posE = pd.Series(np.nan, index=idx.index)
posE[idx > band_hi] = 1.0
posE[idx < band_lo] = 0.0
posE = posE.ffill().fillna(0)
entriesE = ((posE == 1) & (posE.shift(1) == 0)).sum()
stratE = posE.shift(1) * d_ret
costE = pd.Series(0.0, index=idx.index)
costE[posE != posE.shift(1)] = COST
stratE_net = (stratE - costE).dropna()
results.append(stats(stratE_net, 252, "E. 200SMA daily trend", 2 * entriesE / yrs_d, posE.mean()))
results.append(stats(stratE_net.loc["2010":], 252, "  E. 200SMA [10-22]"))

# F. Momentum rotation top-3 of 20 stocks (monthly rebal, 126d mom skip 21d, regime filter)
mpx = stocks.resample("ME").last()
midx = idx.resample("ME").last()
mom = mpx.pct_change(6).shift(1)  # ~126d momentum with 1-month skip... use 6m-1m
regime = midx > midx.rolling(10).mean()
w_prev = pd.Series(0.0, index=mpx.columns)
rets_f, costs_f = [], []
mrets = mpx.pct_change()
for i in range(13, len(mpx)):
    dt, prev_dt = mpx.index[i], mpx.index[i - 1]
    if regime.loc[prev_dt]:
        top = mom.loc[prev_dt].nlargest(3).index
        w = pd.Series(0.0, index=mpx.columns); w[top] = 1 / 3
    else:
        w = pd.Series(0.0, index=mpx.columns)  # cash
    turn = (w - w_prev).abs().sum()
    rets_f.append((w * mrets.loc[dt]).sum())
    costs_f.append(turn * COST)
    w_prev = w
rf = pd.Series(rets_f, index=mpx.index[13:]) - pd.Series(costs_f, index=mpx.index[13:])
results.append(stats(rf, 12, "F. StockMom top3/20 (SURVIVORSHIP!)", None, None))
results.append(stats(rf.loc["2010":], 12, "  F. StockMom [10-22]"))
results.append(stats(d_ret.dropna(), 252, "BH SP500 index 90-22 (price only)"))

df = pd.DataFrame(results).set_index("name")
pd.set_option("display.width", 160)
print(df.to_string())
