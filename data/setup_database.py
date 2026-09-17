"""
setup_database.py

Builds a realistic (synthetic) banking analytics database for the SQL
portfolio: branches, customers, accounts, and transactions - the kind
of schema used for KPI monitoring, SLA reporting, and customer analytics
in a retail banking / outsourcing environment.

Run once to generate data/banking_analytics.db, which every query
in this portfolio runs against.
"""

import sqlite3
import random
from datetime import datetime, timedelta

random.seed(7)

DB_PATH = "data/banking_analytics.db"

BRANCHES = [
    (1, "Karachi Main", "Karachi", "Sindh"),
    (2, "Lahore Gulberg", "Lahore", "Punjab"),
    (3, "Islamabad F-7", "Islamabad", "Federal"),
    (4, "Multan Cantt", "Multan", "Punjab"),
    (5, "Faisalabad City", "Faisalabad", "Punjab"),
]

ACCOUNT_TYPES = ["SAVINGS", "CURRENT", "FIXED_DEPOSIT"]
TXN_TYPES = ["DEPOSIT", "WITHDRAWAL", "TRANSFER", "PAYMENT"]
TXN_CHANNELS = ["BRANCH", "ATM", "ONLINE", "MOBILE"]
KYC_STATUSES = ["VERIFIED", "PENDING", "EXPIRED", "REJECTED"]


def build_schema(conn):
    conn.executescript("""
    DROP TABLE IF EXISTS transactions;
    DROP TABLE IF EXISTS accounts;
    DROP TABLE IF EXISTS customers;
    DROP TABLE IF EXISTS branches;

    CREATE TABLE branches (
        branch_id INTEGER PRIMARY KEY,
        branch_name TEXT NOT NULL,
        city TEXT NOT NULL,
        region TEXT NOT NULL
    );

    CREATE TABLE customers (
        customer_id INTEGER PRIMARY KEY,
        full_name TEXT NOT NULL,
        branch_id INTEGER NOT NULL,
        kyc_status TEXT NOT NULL,
        kyc_last_updated DATE NOT NULL,
        signup_date DATE NOT NULL,
        FOREIGN KEY (branch_id) REFERENCES branches(branch_id)
    );

    CREATE TABLE accounts (
        account_id INTEGER PRIMARY KEY,
        customer_id INTEGER NOT NULL,
        account_type TEXT NOT NULL,
        opened_date DATE NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
    );

    CREATE TABLE transactions (
        transaction_id INTEGER PRIMARY KEY,
        account_id INTEGER NOT NULL,
        transaction_type TEXT NOT NULL,
        channel TEXT NOT NULL,
        amount REAL NOT NULL,
        transaction_date DATE NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts(account_id)
    );
    """)


def random_date(start_days_back, end_days_back=0):
    start = datetime.now() - timedelta(days=start_days_back)
    end = datetime.now() - timedelta(days=end_days_back)
    delta = (end - start).days
    return (start + timedelta(days=random.randint(0, max(delta, 1)))).date()


def populate(conn):
    cur = conn.cursor()

    cur.executemany(
        "INSERT INTO branches VALUES (?, ?, ?, ?)", BRANCHES
    )

    first_names = ["Ahmed", "Sara", "Bilal", "Ayesha", "Hassan", "Fatima",
                   "Usman", "Zainab", "Omar", "Hira", "Ali", "Mahnoor"]
    last_names = ["Khan", "Raza", "Malik", "Sheikh", "Butt", "Qureshi",
                  "Chaudhry", "Iqbal", "Farooq", "Siddiqui"]

    customers = []
    for cid in range(1, 3001):
        name = f"{random.choice(first_names)} {random.choice(last_names)}"
        branch_id = random.choice(BRANCHES)[0]
        signup_date = random_date(730, 30)
        kyc_status = random.choices(
            KYC_STATUSES, weights=[70, 15, 10, 5]
        )[0]
        kyc_last_updated = random_date(400, 0)
        customers.append((cid, name, branch_id, kyc_status, kyc_last_updated, signup_date))
    cur.executemany("INSERT INTO customers VALUES (?, ?, ?, ?, ?, ?)", customers)

    customer_signup = {c[0]: c[5] for c in customers}

    accounts = []
    account_id = 1
    for cid in range(1, 3001):
        signup_date = customer_signup[cid]
        days_since_signup = (datetime.now().date() - signup_date).days
        num_accounts = random.choices([1, 2, 3], weights=[60, 30, 10])[0]
        for _ in range(num_accounts):
            acc_type = random.choice(ACCOUNT_TYPES)
            # account opened on or shortly after signup (realistic: 0-30 days after)
            opened_offset = random.randint(0, min(30, max(days_since_signup, 0)))
            opened = signup_date + timedelta(days=opened_offset)
            status = random.choices(["ACTIVE", "DORMANT", "CLOSED"], weights=[80, 15, 5])[0]
            # ~2% intentional data quality issue: account predating signup (upstream bug)
            if random.random() < 0.02:
                opened = signup_date - timedelta(days=random.randint(1, 15))
            accounts.append((account_id, cid, acc_type, opened, status))
            account_id += 1
    cur.executemany("INSERT INTO accounts VALUES (?, ?, ?, ?, ?)", accounts)

    transactions = []
    txn_id = 1
    for (acc_id, cid, acc_type, opened, status) in accounts:
        if status == "CLOSED":
            continue
        num_txns = random.randint(5, 60)
        for _ in range(num_txns):
            txn_type = random.choice(TXN_TYPES)
            channel = random.choice(TXN_CHANNELS)
            amount = round(random.uniform(500, 250000), 2)
            if txn_type == "WITHDRAWAL":
                amount = -amount
            txn_date = random_date(180, 0)
            transactions.append((txn_id, acc_id, txn_type, channel, amount, txn_date))
            txn_id += 1
    cur.executemany("INSERT INTO transactions VALUES (?, ?, ?, ?, ?, ?)", transactions)

    conn.commit()
    print(f"Loaded: {len(BRANCHES)} branches, {len(customers)} customers, "
          f"{len(accounts)} accounts, {len(transactions)} transactions")


def main():
    conn = sqlite3.connect(DB_PATH)
    build_schema(conn)
    populate(conn)
    conn.close()
    print(f"Database ready -> {DB_PATH}")


if __name__ == "__main__":
    main()
