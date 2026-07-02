"""Vectorised daily backtest engine with trading costs.

Execution model (deliberately conservative):
- A signal computed on the close of day t earns the market return of day t+1
  onwards (`position.shift(1)`), i.e. we assume the bot trades at/near the
  daily close right after computing the signal and never uses information
  from the candle it trades on.
- Every position change pays `cost_per_side` (exchange fee + slippage) on the
  full traded notional.
- Cash earns nothing.
"""

from dataclasses import dataclass

import numpy as np
import pandas as pd

TRADING_DAYS = 365  # crypto trades every day


@dataclass
class Result:
    name: str
    equity: pd.Series          # equity curve, starts at 1.0
    total_return: float        # e.g. 2.5 == +250%
    cagr: float
    sharpe: float              # annualised, rf = 0
    max_drawdown: float        # negative fraction, e.g. -0.55
    n_trades: int              # position changes (each side counts as one)
    trades_per_year: float
    exposure: float            # fraction of days in the market
    win_rate: float            # fraction of round trips closed at a profit

    def row(self) -> dict:
        return {
            "strategy": self.name,
            "total_return_pct": round(100 * self.total_return, 1),
            "cagr_pct": round(100 * self.cagr, 1),
            "sharpe": round(self.sharpe, 2),
            "max_dd_pct": round(100 * self.max_drawdown, 1),
            "trades": self.n_trades,
            "trades_per_yr": round(self.trades_per_year, 1),
            "exposure_pct": round(100 * self.exposure, 1),
            "win_rate_pct": round(100 * self.win_rate, 1) if not np.isnan(self.win_rate) else None,
        }


def run(name: str, close: pd.Series, position: pd.Series,
        cost_per_side: float = 0.005) -> Result:
    """Backtest a position series against a close series.

    cost_per_side: fee + slippage charged on each entry and each exit.
    Default 0.5% = Kraken base taker fee 0.40% + 0.10% slippage allowance.
    """
    close = close.dropna()
    position = position.reindex(close.index).fillna(0.0)

    daily_ret = close.pct_change().fillna(0.0)
    held = position.shift(1).fillna(0.0)          # position during day t
    turnover = held.diff().abs().fillna(0.0)      # traded notional per day

    strat_ret = held * daily_ret - turnover * cost_per_side
    equity = (1.0 + strat_ret).cumprod()

    years = len(close) / TRADING_DAYS
    total_return = float(equity.iloc[-1] - 1.0)
    cagr = float(equity.iloc[-1] ** (1 / years) - 1.0) if years > 0 else 0.0

    vol = strat_ret.std()
    sharpe = float(strat_ret.mean() / vol * np.sqrt(TRADING_DAYS)) if vol > 0 else 0.0

    running_max = equity.cummax()
    max_dd = float((equity / running_max - 1.0).min())

    changes = held.diff().fillna(0.0)
    n_trades = int((changes != 0).sum())

    # Round-trip win rate: return between each entry and the following exit.
    entries = list(close.index[changes > 0])
    exits = list(close.index[changes < 0])
    wins, rts = 0, 0
    for entry_t in entries:
        exit_after = [t for t in exits if t > entry_t]
        if not exit_after:
            exit_px = close.iloc[-1]              # still open at the end
        else:
            exit_px = close.loc[exit_after[0]]
        rts += 1
        # entry/exit both cost one side
        if exit_px / close.loc[entry_t] - 1.0 - 2 * cost_per_side > 0:
            wins += 1
    win_rate = wins / rts if rts else float("nan")

    return Result(
        name=name,
        equity=equity,
        total_return=total_return,
        cagr=cagr,
        sharpe=sharpe,
        max_drawdown=max_dd,
        n_trades=n_trades,
        trades_per_year=n_trades / years if years > 0 else 0.0,
        exposure=float((held > 0).mean()),
        win_rate=win_rate,
    )
