#!/usr/bin/env bash
# Builds a small payments service with a feature branch that has real bugs,
# so diffwalker has something worth flagging. Usage:
#   docs/demo/make-demo-repo.sh /tmp/payments-demo
#   DIFFWALKER_REPO=/tmp/payments-demo jac run web
set -euo pipefail

DEST="${1:-/tmp/payments-demo}"
rm -rf "$DEST"
mkdir -p "$DEST/payments" "$DEST/tests"
cd "$DEST"
git init -q -b main
git config user.name "Demo Author"
git config user.email "demo@example.com"

cat > payments/__init__.py <<'PY'
"""A tiny payments service used to demo diffwalker."""
PY

cat > payments/db.py <<'PY'
import sqlite3
from contextlib import contextmanager

DB_PATH = "payments.db"


@contextmanager
def connect():
    conn = sqlite3.connect(DB_PATH)
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()


def init_schema():
    with connect() as conn:
        conn.execute(
            "CREATE TABLE IF NOT EXISTS charges ("
            " id TEXT PRIMARY KEY, customer TEXT, amount_cents INTEGER, refunded_cents INTEGER DEFAULT 0)"
        )
PY

cat > payments/charges.py <<'PY'
import uuid
from .db import connect


def create_charge(customer: str, amount_cents: int) -> str:
    if amount_cents <= 0:
        raise ValueError("amount must be positive")
    charge_id = uuid.uuid4().hex
    with connect() as conn:
        conn.execute(
            "INSERT INTO charges (id, customer, amount_cents) VALUES (?, ?, ?)",
            (charge_id, customer, amount_cents),
        )
    return charge_id


def get_charge(charge_id: str) -> dict | None:
    with connect() as conn:
        row = conn.execute(
            "SELECT id, customer, amount_cents, refunded_cents FROM charges WHERE id = ?",
            (charge_id,),
        ).fetchone()
    if row is None:
        return None
    return {"id": row[0], "customer": row[1], "amount_cents": row[2], "refunded_cents": row[3]}
PY

cat > payments/auth.py <<'PY'
import hmac
import os


def check_token(token: str) -> bool:
    expected = os.environ.get("PAYMENTS_API_TOKEN", "")
    return bool(expected) and hmac.compare_digest(token, expected)
PY

cat > tests/test_charges.py <<'PY'
from payments.charges import create_charge, get_charge
from payments.db import init_schema


def test_create_and_get():
    init_schema()
    cid = create_charge("ada", 1200)
    assert get_charge(cid)["amount_cents"] == 1200
PY

git add -A && git commit -q -m "feat: charges service with sqlite storage"
echo "# payments-demo" > README.md && git add -A && git commit -q -m "docs: readme"

git checkout -q -b feat/refunds

cat > payments/refunds.py <<'PY'
import logging
from .db import connect
from .charges import get_charge

log = logging.getLogger(__name__)


def refund(charge_id: str, amount_cents: int, reason: str = "") -> bool:
    charge = get_charge(charge_id)
    try:
        with connect() as conn:
            conn.execute(
                f"UPDATE charges SET refunded_cents = refunded_cents + {amount_cents} "
                f"WHERE id = '{charge_id}'"
            )
            conn.execute(
                f"INSERT INTO refunds_log (charge_id, reason) VALUES ('{charge_id}', '{reason}')"
            )
        log.info("refunded %s of %s", amount_cents, charge["amount_cents"])
        return True
    except Exception:
        pass
    return False


def refund_all(customer: str) -> int:
    count = 0
    with connect() as conn:
        rows = conn.execute(
            "SELECT id, amount_cents FROM charges WHERE customer = '" + customer + "'"
        ).fetchall()
    for i in range(len(rows) - 1):
        if refund(rows[i][0], rows[i][1], "bulk"):
            count += 1
    return count
PY

# A fake, never-valid key. Assembled from two halves so this script itself
# does not trip secret scanners; the generated file contains it whole.
FAKE_TOKEN="sk_live""_51HqDemoAdminTokenDoNotUse0000"
cat > payments/auth.py <<PY
import os

ADMIN_TOKEN = "${FAKE_TOKEN}"


def check_token(token: str) -> bool:
    expected = os.environ.get("PAYMENTS_API_TOKEN", ADMIN_TOKEN)
    return token == expected
PY

git add -A && git commit -q -m "feat(refunds): partial and bulk refunds, admin token fallback"
git checkout -q main
echo "demo repo ready at $DEST (branch feat/refunds)"
