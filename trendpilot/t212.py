"""Minimal Trading 212 public API client (equity endpoints, API v0).

Docs: https://docs.trading212.com/api  (beta; Invest & Stocks ISA only — the
public API does not cover CFD accounts, which is why CFDs are signal-mode only).

Auth: the API key goes in the Authorization header verbatim (no Bearer prefix).
Rate limits are per-endpoint and strict; we keep a conservative client-side
limiter and honour 429s with backoff.
"""

from __future__ import annotations

import logging
import time

import requests

log = logging.getLogger("trendpilot.t212")


class T212Error(RuntimeError):
    def __init__(self, status: int, body: str):
        super().__init__(f"T212 API error {status}: {body}")
        self.status = status


class T212Client:
    def __init__(self, base_url: str, api_key: str, min_interval: float = 2.5):
        if not api_key:
            raise ValueError("T212 API key is required (set T212_API_KEY)")
        self.base_url = base_url.rstrip("/")
        self._session = requests.Session()
        self._session.headers["Authorization"] = api_key
        self._min_interval = min_interval
        self._last_call = 0.0

    # -- plumbing -----------------------------------------------------------
    def _request(self, method: str, path: str, json: dict | None = None) -> dict | list:
        for attempt in range(5):
            wait = self._min_interval - (time.monotonic() - self._last_call)
            if wait > 0:
                time.sleep(wait)
            resp = self._session.request(
                method, f"{self.base_url}{path}", json=json, timeout=30
            )
            self._last_call = time.monotonic()
            if resp.status_code == 429:
                backoff = 2.0 * (2 ** attempt)
                log.warning("rate limited on %s, backing off %.0fs", path, backoff)
                time.sleep(backoff)
                continue
            if resp.status_code >= 400:
                raise T212Error(resp.status_code, resp.text[:500])
            return resp.json() if resp.text else {}
        raise T212Error(429, f"still rate-limited after retries: {path}")

    # -- account ------------------------------------------------------------
    def account_cash(self) -> dict:
        """Keys include: free, total, invested, ppl, blocked."""
        return self._request("GET", "/equity/account/cash")

    def account_info(self) -> dict:
        """Keys include: id, currencyCode."""
        return self._request("GET", "/equity/account/info")

    # -- instruments & portfolio --------------------------------------------
    def instruments(self) -> list:
        return self._request("GET", "/equity/metadata/instruments")

    def portfolio(self) -> list:
        """Open positions: ticker, quantity, averagePrice, currentPrice, ppl."""
        return self._request("GET", "/equity/portfolio")

    def position(self, ticker: str) -> dict | None:
        for pos in self.portfolio():
            if pos.get("ticker") == ticker:
                return pos
        return None

    # -- orders ---------------------------------------------------------------
    def pending_orders(self) -> list:
        return self._request("GET", "/equity/orders")

    def place_market_order(self, ticker: str, quantity: float) -> dict:
        """Positive quantity buys, negative sells (T212 convention)."""
        payload = {"ticker": ticker, "quantity": round(quantity, 8)}
        log.info("placing market order: %s", payload)
        return self._request("POST", "/equity/orders/market", json=payload)

    def cancel_order(self, order_id: int) -> None:
        self._request("DELETE", f"/equity/orders/{order_id}")
