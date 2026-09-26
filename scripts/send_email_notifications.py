#!/usr/bin/env python3
"""
BWZ CORPORATION Finance Tracker - Automated Email Notification Dispatcher
Features:
1. Instant Login alert emails.
2. Instant Transaction confirmation emails (Income, Expense, Savings, Debt).
3. Daily Savings status notification scheduled at 6:00 PM CAT (UTC+2).
4. Daily Transactions summary notification scheduled at 6:00 PM CAT.
"""

import os
import sys
import json
import smtplib
from datetime import datetime, timezone, timedelta
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
import urllib.request
import urllib.parse
import re

# Configuration (empty env vars fall back to built-in defaults so local runs work)
SMTP_HOST = os.environ.get("SMTP_HOST") or "smtp.gmail.com"
SMTP_PORT = int(os.environ.get("SMTP_PORT") or "465")
SMTP_USER = os.environ.get("SMTP_USER") or "hheribwiza1@gmail.com"
SMTP_PASSWORD = (os.environ.get("SMTP_PASSWORD") or "vrsl pkvf nbto dxre").replace(" ", "")
ADMIN_EMAIL = os.environ.get("ADMIN_EMAIL") or "hheribwiza1@gmail.com"

SUPABASE_URL = os.environ.get("SUPABASE_URL") or "https://sxcshkumjmlweyclttsc.supabase.co"
SUPABASE_SERVICE_ROLE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or ""
SUPABASE_PUBLISHABLE_KEY = (
    os.environ.get("SUPABASE_PUBLISHABLE_KEY")
    or "sb_publishable_D_zIvEZOkr_578iWWq-PgA_N0ppMr6k"
)

AUTH_KEY = SUPABASE_SERVICE_ROLE_KEY if SUPABASE_SERVICE_ROLE_KEY else SUPABASE_PUBLISHABLE_KEY

def send_smtp_email(to_email: str, subject: str, html_body: str) -> bool:
    """Send an HTML email via Gmail SSL SMTP."""
    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = f"BWZ CORPORATION <{SMTP_USER}>"
    msg["To"] = to_email

    plain_text = re.sub(r"<[^>]+>", "", html_body)
    msg.attach(MIMEText(plain_text, "plain", "utf-8"))
    msg.attach(MIMEText(html_body, "html", "utf-8"))

    try:
        with smtplib.SMTP_SSL(SMTP_HOST, SMTP_PORT, timeout=20) as server:
            server.login(SMTP_USER, SMTP_PASSWORD)
            server.send_message(msg)
        print(f"[{datetime.now(timezone.utc).isoformat()}] Email sent to {to_email}: {subject}")
        return True
    except Exception as e:
        print(f"[{datetime.now(timezone.utc).isoformat()}] Failed to send email to {to_email}: {e}", file=sys.stderr)
        return False
def supabase_request(endpoint: str, method: str = "GET", data: dict = None, params: dict = None):
    """Execute a REST request against Supabase PostgREST API."""
    url = f"{SUPABASE_URL.rstrip('/')}/rest/v1/{endpoint}"
    if params:
        url += "?" + urllib.parse.urlencode(params)

    headers = {
        "apikey": AUTH_KEY,
        "Authorization": f"Bearer {AUTH_KEY}",
        "Content-Type": "application/json",
        "Prefer": "return=representation"
    }

    body_bytes = json.dumps(data).encode("utf-8") if data is not None else None
    req = urllib.request.Request(url, data=body_bytes, headers=headers, method=method)

    try:
        with urllib.request.urlopen(req, timeout=15) as response:
            res_body = response.read().decode("utf-8")
            return json.loads(res_body) if res_body else []
    except urllib.error.HTTPError as err:
        err_body = err.read().decode("utf-8") if err.fp else ""
        print(f"Supabase HTTP Error {err.code} on {endpoint}: {err_body}", file=sys.stderr)
        return None
    except Exception as err:
        print(f"Supabase request failed on {endpoint}: {err}", file=sys.stderr)
        return None

def process_pending_queue():
    """Process any pending rows in notification_queue (e.g., queued from browser client)."""
    print("Checking notification queue...")
    rows = supabase_request("notification_queue", "GET", params={"status": "eq.pending", "order": "created_at.asc", "limit": 20})
    if not rows:
        print("No pending notifications in queue.")
        return

    for item in rows:
        nid = item.get("id")
        recipient = item.get("recipient") or ADMIN_EMAIL
        subject = item.get("subject", "BWZ Finance Notification")
        html = item.get("html_body", "")

        success = send_smtp_email(recipient, subject, html)
        status = "sent" if success else "failed"
        patch_payload = {
            "status": status,
            "sent_at": datetime.now(timezone.utc).isoformat()
        }
        if success and not SMTP_PASSWORD:
            print(f"[DRY-RUN] Would mark notification {nid} as sent (no SMTP password configured).")
            continue
        if nid:
            updated = supabase_request(
                "notification_queue",
                method="PATCH",
                data=patch_payload,
                params={"id": f"eq.{nid}"},
            )
            if updated is None:
                print(f"Warning: could not update status for notification {nid}", file=sys.stderr)
            else:
                print(f"Notification {nid} marked as {status}.")
def generate_savings_report():
    """Compile and send the Daily Savings Report at 6 PM."""
    print("Generating 6 PM Savings Report...")
    savings_rows = supabase_request("savings", "GET", params={"order": "date.desc", "limit": 200}) or []

    totals = {}
    today_cat = (datetime.now(timezone.utc) + timedelta(hours=2)).strftime("%Y-%m-%d")
    today_movements = []

    for s in savings_rows:
        cur = s.get("currency") or "RWF"
        amt = float(s.get("amount") or 0)
        stype = s.get("type", "deposit")
        signed_amt = amt if stype == "deposit" else -amt
        totals[cur] = totals.get(cur, 0.0) + signed_amt

        s_date = str(s.get("date", ""))[:10]
        if s_date == today_cat:
            today_movements.append(s)

    def fmt(val):
        return f"{val:,.2f}"

    lines = []
    for cur in ["RWF", "USD", "CDF"]:
        if cur in totals or cur == "RWF":
            amt_val = totals.get(cur, 0.0)
            color = "#10B981" if amt_val >= 0 else "#EF4444"
            lines.append(f"<div style='font-size:18px; font-weight:bold; color:{color}; margin-bottom:4px;'>{fmt(amt_val)} {cur}</div>")

    movements_html = ""
    if today_movements:
        movements_html = """
        <h4 style="margin-top:20px; color:#1a1a2e; border-bottom:1px solid #e2e8f0; padding-bottom:6px;">Movements Logged Today</h4>
        <table style="width:100%; border-collapse:collapse; font-size:13px;">
          <thead>
            <tr style="background:#f8fafc; text-align:left;">
              <th style="padding:8px;">Type</th>
              <th style="padding:8px;">Amount</th>
              <th style="padding:8px;">Reason</th>
            </tr>
          </thead>
          <tbody>
        """
        for m in today_movements:
            is_dep = m.get("type") == "deposit"
            color = "#10B981" if is_dep else "#EF4444"
            prefix = "+" if is_dep else "-"
            movements_html += f"""
            <tr style="border-bottom:1px solid #f1f5f9;">
              <td style="padding:8px; font-weight:bold; color:{color};">{m.get('type', '').capitalize()}</td>
              <td style="padding:8px; font-weight:bold;">{prefix}{fmt(float(m.get('amount') or 0))} {m.get('currency', 'RWF')}</td>
              <td style="padding:8px; color:#475569;">{m.get('reason', '—')}</td>
            </tr>
            """
        movements_html += "</tbody></table>"
    else:
        movements_html = "<p style='color:#64748b; font-size:13px;'>No new savings deposits or withdrawals logged today.</p>"

    now_cat = (datetime.now(timezone.utc) + timedelta(hours=2)).strftime("%B %d, %Y - 06:00 PM CAT")
    html_body = f"""
    <div style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif; max-width:600px; margin:0 auto; background:#ffffff; border:1px solid #e2e8f0; border-radius:12px; overflow:hidden; box-shadow:0 4px 6px -1px rgba(0,0,0,0.1);">
      <div style="background:linear-gradient(135deg, #10B981 0%, #059669 100%); padding:24px; text-align:center; color:#ffffff;">
        <h1 style="margin:0 0 4px 0; font-size:22px;">BWZ CORPORATION</h1>
        <p style="margin:0; font-size:14px; opacity:0.9;">Daily Savings Status Report (6:00 PM)</p>
      </div>
      <div style="padding:24px;">
        <p style="font-size:14px; color:#64748b; margin-top:0;">Time: <strong>{now_cat}</strong></p>
        <div style="background:#f0fdf4; border:1px solid #bbf7d0; border-radius:8px; padding:16px; margin:16px 0;">
          <h3 style="margin:0 0 10px 0; color:#166534; font-size:14px; text-transform:uppercase; letter-spacing:0.05em;">Current Net Savings Balance</h3>
          {''.join(lines)}
        </div>
        {movements_html}
        <div style="margin-top:24px; padding-top:16px; border-top:1px solid #e2e8f0; text-align:center;">
          <a href="https://heribwiza.github.io/bwz-finances/" style="display:inline-block; background:#10B981; color:#ffffff; text-decoration:none; padding:10px 20px; border-radius:6px; font-weight:bold; font-size:13px;">Open Finance Tracker</a>
        </div>
      </div>
      <div style="background:#f8fafc; padding:12px; text-align:center; font-size:11px; color:#94a3b8;">
        Sent automatically by BWZ CORPORATION Finance Tracker System.
      </div>
    </div>
    """

    subject = f"💰 BWZ Daily Savings Report (6 PM) - {today_cat}"
    send_smtp_email(ADMIN_EMAIL, subject, html_body)


def generate_daily_transactions_summary():
    """Compile and send Daily Summary of all transactions (Expenses, Incomes, Debts, Savings) for today."""
    print("Generating Daily Transactions Summary...")
    today_cat = (datetime.now(timezone.utc) + timedelta(hours=2)).strftime("%Y-%m-%d")

    expenses = supabase_request("expenses", "GET", params={"date": f"eq.{today_cat}"}) or []
    income = supabase_request("income", "GET", params={"date": f"eq.{today_cat}"}) or []
    debts = supabase_request("debts", "GET", params={"date": f"eq.{today_cat}"}) or []
    savings = supabase_request("savings", "GET", params={"order": "date.desc", "limit": 100}) or []
    today_savings = [s for s in savings if str(s.get("date", ""))[:10] == today_cat]

    total_count = len(expenses) + len(income) + len(debts) + len(today_savings)
    def fmt(v):
        return f"{v:,.2f}"

    def build_table(headers, rows):
        if not rows:
            return "<p style='color:#94a3b8; font-size:12px; margin:6px 0 16px;'>No activity logged today.</p>"
        html = "<table style='width:100%; border-collapse:collapse; font-size:13px; margin-bottom:16px;'><tr style='background:#f1f5f9; text-align:left;'>"
        for h in headers:
            html += f"<th style='padding:6px 8px;'>{h}</th>"
        html += "</tr>"
        for r in rows:
            html += "<tr style='border-bottom:1px solid #f1f5f9;'>"
            for col in r:
                html += f"<td style='padding:6px 8px;'>{col}</td>"
            html += "</tr>"
        html += "</table>"
        return html

    exp_rows = [
        [e.get("category", "—"), e.get("description", "—"), f"<b>{fmt(float(e.get('amount') or 0))} {e.get('currency', 'RWF')}</b>"]
        for e in expenses
    ]
    inc_rows = [
        [i.get("title", "—"), i.get("category", "—"), f"<b style='color:#10B981;'>+{fmt(float(i.get('amount') or 0))} {i.get('currency', 'RWF')}</b>"]
        for i in income
    ]
    debt_rows = [
        [d.get("person", "—"), d.get("description", "—"), f"<b style='color:#F59E0B;'>{fmt(float(d.get('amount') or 0))} {d.get('currency', 'RWF')}</b>", d.get("status", "unpaid")]
        for d in debts
    ]
    sav_rows = [
        [s.get("type", "").capitalize(), s.get("reason", "—"), f"<b>{fmt(float(s.get('amount') or 0))} {s.get('currency', 'RWF')}</b>"]
        for s in today_savings
    ]

    now_cat = (datetime.now(timezone.utc) + timedelta(hours=2)).strftime("%B %d, %Y")

    html_body = f"""
    <div style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif; max-width:650px; margin:0 auto; background:#ffffff; border:1px solid #e2e8f0; border-radius:12px; overflow:hidden; box-shadow:0 4px 6px -1px rgba(0,0,0,0.1);">
      <div style="background:linear-gradient(135deg, #1E293B 0%, #0F172A 100%); padding:24px; text-align:center; color:#ffffff;">
        <h1 style="margin:0 0 4px 0; font-size:22px;">BWZ CORPORATION</h1>
        <p style="margin:0; font-size:14px; color:#94A3B8;">Daily Transactions Summary — {now_cat}</p>
      </div>
      <div style="padding:24px;">
        <div style="margin-bottom:20px; background:#F8FAFC; padding:12px 16px; border-radius:8px; border:1px solid #E2E8F0; font-size:13px;">
          <div>Total Transactions Today: <strong>{total_count}</strong></div>
          <div style="color:#64748B; margin-top:4px;">Expenses: <strong>{len(expenses)}</strong> | Incomes: <strong>{len(income)}</strong> | Debts: <strong>{len(debts)}</strong> | Savings: <strong>{len(today_savings)}</strong></div>
        </div>

        <h3 style="color:#EF4444; margin:16px 0 8px; font-size:15px;">💸 Expenses Today ({len(expenses)})</h3>
        {build_table(["Category", "Description", "Amount"], exp_rows)}

        <h3 style="color:#10B981; margin:16px 0 8px; font-size:15px;">💵 Income Logged Today ({len(income)})</h3>
        {build_table(["Source", "Category", "Amount"], inc_rows)}

        <h3 style="color:#F59E0B; margin:16px 0 8px; font-size:15px;">📋 Debts Created/Modified Today ({len(debts)})</h3>
        {build_table(["Person", "Description", "Amount", "Status"], debt_rows)}

        <h3 style="color:#3B82F6; margin:16px 0 8px; font-size:15px;">🏦 Savings Movements Today ({len(today_savings)})</h3>
        {build_table(["Type", "Reason", "Amount"], sav_rows)}

        <div style="margin-top:24px; padding-top:16px; border-top:1px solid #e2e8f0; text-align:center;">
          <a href="https://heribwiza.github.io/bwz-finances/" style="display:inline-block; background:#10B981; color:#ffffff; text-decoration:none; padding:10px 20px; border-radius:6px; font-weight:bold; font-size:13px;">View Dashboard Online</a>
        </div>
      </div>
      <div style="background:#f8fafc; padding:12px; text-align:center; font-size:11px; color:#94a3b8;">
        BWZ CORPORATION Finance Tracker Notification Service
      </div>
    </div>
    """

    subject = f"📊 BWZ Daily Transactions Summary - {now_cat} ({total_count} transactions)"
    send_smtp_email(ADMIN_EMAIL, subject, html_body)

if __name__ == "__main__":
    action = sys.argv[1] if len(sys.argv) > 1 else "all"
    print(f"Executing notification task: {action}")

    if action in ["queue", "all"]:
        process_pending_queue()
    if action in ["savings", "all"]:
        generate_savings_report()
    if action in ["summary", "all"]:
        generate_daily_transactions_summary()

    print("Task execution completed.")
