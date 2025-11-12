
# Scalable Data Infrastructure Migration
**Course:** ISTM 622 — Advanced Database Management  
**Author:** Chadani Acharya

A hands-on project that takes a legacy POS dataset from a small furniture company and builds a **scalable data stack**: secure Linux + MariaDB on AWS, clean ETL into a normalized schema, performance views & indexes, **transactions & prepared statements**, **stored procedures & triggers**, **replication (primary–replica) and Galera peer-to-peer**, JSON exports, and a **MongoDB** migration for document-style access.

> 📄 Reflection paper (methods, design choices, lessons):  
> https://drive.google.com/file/d/1xBF-yzBjy5EwP5DFxXFEIcKRF6LOLCWW/view?usp=sharing

---

## Highlights (what I built)
- **Infrastructure (AWS EC2 + Linux hardening):** SSH key auth, security groups, package repos; installed **MariaDB** and created least-privilege DB users.
- **Schema & ETL:** Implemented ERD; cleaned messy CSV (prices with `$`, invalid dates, empty strings) using SQL transforms (`REPLACE`, `CAST`, `STR_TO_DATE`, `NULLIF`) and staged temp tables.
- **Views & Indexes:** Readable reporting views (e.g., `v_ProductBuyers`), simulated materialized views (`mv_*` tables), and selective functional indexes for faster lookups.
- **Transactions & Prepared Statements:** Atomic multi-step ops; parameterized inserts to prevent SQL injection and speed bulk loads.
- **Stored Procedures & Triggers:** Automated price history, order totals, and inventory updates; transaction-safe refresh of materialized views.
- **Replication:**  
  - *Standard:* primary→replica for read scaling and HA.  
  - *Peer-to-peer:* **Galera** 3-node cluster for multi-master writes.
- **JSON & NoSQL:** Generated nested JSON via SQL (`JSON_OBJECT`, `JSON_ARRAYAGG`), then imported to **MongoDB** (`mongoimport`) and wrote aggregation pipelines for analysis.

---

## Tech Stack
Linux (Amazon Linux 2) · MariaDB · SQL (DDL/DML) · Bash · AWS EC2/Security Groups · Galera · JSON · MongoDB

---

## Quick Start

### 1) Provision & Secure
- Launch EC2; allow **22** (SSH) from your IP; DB port **3306** only within VPC.
- Set SSH permissions: `chmod 600 ~/.ssh/yourkey.pem`

### 2) Install MariaDB & Configure
`/etc/my.cnf` (primary):
```ini
[mysqld]
server_id=1
log_bin=/var/log/mysql/mysql-bin.log
binlog_format=mixed
````

Replicas:

```ini
[mysqld]
server_id=2   # unique per replica
relay_log=/var/log/mysql/mysql-relay-bin.log
read_only=1
```

### 3) Create Schema & Load Clean Data

```bash
mysql -u root -p < sql/schema.sql
mysql -u root -p < sql/etl_clean_transform.sql
```

ETL includes cleaning prices, dates, NULL standardization, FK-safe load order, and quantity aggregation.

### 4) Views, Indexes, Procedures, Triggers

```bash
mysql -u root -p < sql/views_and_indexes.sql
mysql -u root -p < sql/stored_procedures.sql
mysql -u root -p < sql/triggers.sql
```

### 5) Replication (Primary→Replica)

On replica:

```sql
CHANGE MASTER TO
  MASTER_HOST='PRIMARY_PRIVATE_IP',
  MASTER_USER='replication_user',
  MASTER_PASSWORD='secure-password',
  MASTER_LOG_FILE='mysql-bin.000001',
  MASTER_LOG_POS=4;
START SLAVE;
```

### 6) Galera (Peer-to-Peer) — optional

`/etc/my.cnf`:

```ini
[mysqld]
wsrep_on=ON
wsrep_provider=/usr/lib64/galera/libgalera_smm.so
wsrep_cluster_name="ISTM622Cluster"
wsrep_cluster_address="gcomm://NODE1_IP,NODE2_IP,NODE3_IP"
wsrep_node_address="THIS_NODE_IP"
wsrep_sst_method=rsync
```

Init first node: `galera_new_cluster`; start others normally.

### 7) JSON Export → MongoDB

SQL export (example pattern):

```sql
SELECT JSON_OBJECT(
  'customer_id', c.id,
  'name', CONCAT(c.firstName,' ',c.lastName),
  'orders', (
    SELECT JSON_ARRAYAGG(JSON_OBJECT(
      'order_id', o.id,
      'items', (SELECT JSON_ARRAYAGG(JSON_OBJECT(
                  'product', p.name,
                  'qty', ol.quantity,
                  'price', ol.unitPrice))
               FROM Orderline ol JOIN Product p ON p.id=ol.product_id
               WHERE ol.order_id=o.id)
    ))
    FROM `Order` o WHERE o.customer_id=c.id
  )
) AS doc
FROM Customer c
INTO OUTFILE '/var/lib/mysql/POS/customers.json';
```

Import:

```bash
mongoimport --db POS --collection Customers --file customers.json --jsonArray
```

---

## Key Code Patterns

**Prepared insert (defends against injection & speeds bulk):**

```sql
PREPARE ins FROM 'INSERT INTO Customer (id, firstName, lastName) VALUES (?,?,?)';
SET @id=100002, @fn='John', @ln='Doe';
EXECUTE ins USING @id,@fn,@ln;
DEALLOCATE PREPARE ins;
```

**Trigger (price history & order totals):**

```sql
CREATE TRIGGER trg_Product_AfterUpdate
AFTER UPDATE ON Product FOR EACH ROW
BEGIN
  IF NEW.currentPrice <> OLD.currentPrice THEN
    INSERT INTO PriceHistory (oldPrice,newPrice,product_id)
    VALUES (OLD.currentPrice,NEW.currentPrice,NEW.id);
  END IF;
END;
```

---

## Repository Layout (suggested)

```
sql/
  schema.sql
  etl_clean_transform.sql
  views_and_indexes.sql
  stored_procedures.sql
  triggers.sql
replication/
  primary.cnf
  replica.cnf
  galera_sample.cnf
json/
  export_examples.sql
mongo/
  import_commands.sh
docs/
  reflection_link.md  # points to Google Drive reflection
```

---

## My Role & Outcomes

* Designed and implemented the **entire pipeline** end-to-end.
* Resolved infra issues (repos, SSH, permissions), enforced least privilege.
* Built **transaction-safe** procedures & **auditable** triggers.
* Deployed **read scaling** via replication; tested conflict/lag scenarios.
* Delivered JSON exports and **MongoDB** aggregation analyses.

---

## Notes

* Credentials in examples are placeholders—use secrets management.
* For TRUNCATE rollback needs, prefer `DELETE` inside a transaction.
* Index selectively; verify with `EXPLAIN` and workload tests.

---

## License

Educational use. Remove any institution-specific details before reuse.

```

