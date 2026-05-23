"""
api_ingest.py — Ingest API-sourced datasets into the Bronze layer.

Pattern (mirrors the SQL bronze.load_bronze procedure):
  1. Fetch from a REST API (with retry + backoff).
  2. Truncate the target bronze.api_* table.
  3. Bulk-insert the raw rows via fast_executemany.

Run:  python -m scripts.ingest.api_ingest
"""

from __future__ import annotations

import logging
import os
from datetime import date, timedelta
from typing import Iterable, Iterator

import pyodbc
import requests
from dotenv import load_dotenv
from requests.adapters import HTTPAdapter, Retry

load_dotenv()
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("api_ingest")


def _session() -> requests.Session:
    s = requests.Session()
    retries = Retry(
        total=5,
        backoff_factor=0.5,
        status_forcelist=[429, 500, 502, 503, 504],
        allowed_methods=["GET"],
    )
    s.mount("https://", HTTPAdapter(max_retries=retries))
    return s


def _connect() -> pyodbc.Connection:
    conn_str = (
        f"DRIVER={{{os.environ['SQL_DRIVER']}}};"
        f"SERVER={os.environ['SQL_SERVER']};"
        f"DATABASE={os.environ['SQL_DATABASE']};"
        f"Trusted_Connection={os.environ.get('SQL_TRUSTED', 'yes')};"
    )
    return pyodbc.connect(conn_str)


# --- Source: frankfurter.app (free ECB FX rates, no API key) -----------------

FRANKFURTER_BASE = "https://api.frankfurter.app"


def fetch_fx_rates(start: date, end: date, base: str = "USD") -> Iterator[tuple]:
    """Yield (rate_date, base_currency, quote_currency, rate) for a date range."""
    sess = _session()
    url = f"{FRANKFURTER_BASE}/{start.isoformat()}..{end.isoformat()}"
    resp = sess.get(url, params={"from": base}, timeout=30)
    resp.raise_for_status()
    for d, quotes in sorted(resp.json().get("rates", {}).items()):
        for quote, rate in quotes.items():
            yield (d, base, quote, rate)


def load_fx_rates(rows: Iterable[tuple]) -> int:
    insert_sql = (
        "INSERT INTO bronze.api_fx_rates "
        "(rate_date, base_currency, quote_currency, rate) VALUES (?, ?, ?, ?)"
    )
    batch = list(rows)
    with _connect() as conn:
        cur = conn.cursor()
        cur.fast_executemany = True
        cur.execute("TRUNCATE TABLE bronze.api_fx_rates")
        cur.executemany(insert_sql, batch)
        conn.commit()
    return len(batch)


def main() -> None:
    lookback = int(os.environ.get("FX_LOOKBACK_DAYS", "30"))
    base = os.environ.get("FX_BASE_CURRENCY", "USD")
    end = date.today()
    start = end - timedelta(days=lookback)

    log.info("Fetching FX rates base=%s window=%s..%s", base, start, end)
    rows = list(fetch_fx_rates(start, end, base=base))
    log.info("Fetched %d rows; loading bronze.api_fx_rates", len(rows))
    n = load_fx_rates(rows)
    log.info("Loaded %d rows into bronze.api_fx_rates", n)


if __name__ == "__main__":
    main()
