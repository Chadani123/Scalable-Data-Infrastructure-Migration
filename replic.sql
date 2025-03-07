-- ### Follow all steps from milestone 1 along with the step 2 for setup proc_UpdateSalesTax

-- ### **Step 2: Designate Instances and Configure Security Groups**

-- - **Tag the Instances** in AWS to avoid confusion:
--   - `Primary-DB` for the primary instance.
--   - `Replica1-DB` and `Replica2-DB` for the replicas.

-- - **Configure the Security Group**:
--   - Allow **SSH (port 22)** only from your IP address.
--   - Allow **MySQL/MariaDB traffic (port 3306)**:
--     - Open **port 3306** between the primary and replicas (using their private IP addresses).
--     - Do not allow port `3306` to be accessible from the public internet.


CREATE USER 'dgomillion'@'localhost' IDENTIFIED BY 'FurnitureFun!';
GRANT ALL PRIVILEGES ON *.* TO 'dgomillion'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;


-- ### **Step 3: Configure the Primary and Replica Servers**

-- #### **Primary Server Configuration**

-- 1. **Edit the Configuration File** (`/etc/my.cnf.d/server.cnf`):
--    - Add/modify the following settings under `[mysqld]`:
--      ```ini
     [mysqld]
     server_id = 1
     log_bin = /var/log/mysql/mysql-bin.log
     binlog_format = mixed
    --  ```
--    - Save and exit.

-- 2. **Restart MariaDB**:
--    ```bash
   sudo systemctl restart mariadb
--    ```

-- 3. **Create the Replication User**:
--    - Log into MariaDB:
--      ```bash
     mysql -u root -p
    --  ```
--    - Create the replication user (avoid using `root`, `admin`, or `dgomillion`):
--      ```sql
     CREATE USER 'replication_user'@'%' IDENTIFIED BY 'FurnitureFun!';
     GRANT REPLICATION SLAVE ON *.* TO 'replication_user'@'%';
     FLUSH PRIVILEGES;
    --  ```

-- #### **Replica Server Configuration**

-- 1. **Edit the Configuration File** (`/etc/my.cnf.d/server.cnf`) on each replica:
--    - Set a unique `server_id` for each replica (e.g., `2` for `Replica1-DB` and `3` for `Replica2-DB`):
--      ```ini
     [mysqld]
     server_id = 2  # Use 3 for the second replica
     relay_log = /var/log/mysql/mysql-relay-bin.log
     read_only = 1
    --  ```
--    - Save and exit.

-- 2. **Restart MariaDB** on each replica:
--    ```bash
   sudo systemctl restart mariadb
--    ```

-- 3. **Set Up Replication on Each Replica**:
--    - Log into MariaDB on each replica:
--      ```bash
     mysql -u root -p
    --  ```
--    - Configure the replica to replicate from the primary:
--      ```sql
     CHANGE MASTER TO 
         MASTER_HOST='Primary-DB-Private-IP',
         MASTER_USER='replication_user',
         MASTER_PASSWORD='FurnitureFun!',
         MASTER_LOG_FILE='mysql-bin.000001', 
         MASTER_LOG_POS=4;
     START SLAVE;
    --  ```
--    - Replace `'Primary-DB-Private-IP'` with the private IP of the primary server.

-- ### **Step 4: Verify and Test Replication**

-- 1. **Check Replication Status on Each Replica**:
--    - Run the following command on each replica:
--      ```sql
     SHOW SLAVE STATUS\G
--      ```
--    - Verify that `Slave_IO_Running` and `Slave_SQL_Running` are both `Yes`.


-- Stop and Reset the Slave (If Needed):
STOP SLAVE;
RESET SLAVE ALL;



CREATE USER 'dgomillion'@'%' IDENTIFIED BY 'FurnitureFun!';
GRANT REPLICATION SLAVE ON *.* TO 'replication_user'@'%';
FLUSH PRIVILEGES;





-- 2. **Restore the Production Database on the Primary**:
--    - On the primary server, unzip and restore the database:
--      ```bash
     unzip your-database-files.zip
     mysql -u root -p < views.sql
--      ```
--    - The changes should replicate to the replicas.

-- 3. **Test Replication**:
--    - Insert, update, and delete data on the primary server and verify that the changes are correctly replicated to the replicas.
--    - Example:
--      ```sql
     USE your_database;
     INSERT INTO orders (column1, column2) VALUES ('value1', 'value2');
--      ```
--    - Check on the replicas to see if the data appears after a short delay.

-- 4. **Ensure Read-Only Mode on Replicas**:
--    - Try inserting or deleting data on the replicas as the `dgomillion` user. It should fail due to the read-only configuration.

-- ### **Step 5: Final Validation**

-- 1. **Drop and Recreate the Database**:
--    - On the primary:
--      ```sql
     DROP DATABASE POS;
     SOURCE views.sql;
--      ```
--    - Verify that the data is available on the replicas after some time.

-- 2. **Insert and Delete Data**:
--    - Insert and delete new data on the primary, ensuring that these changes are visible on the replicas.

-- 3. **Check that Replicas Enforce Read-Only Mode**:
--    - Test deleting an entry on the replicas. It should fail as expected.

