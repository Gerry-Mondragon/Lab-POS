# Abarrotes Anny POS: database server on Ubuntu

Goal: the Ubuntu PC on the store's Wi-Fi runs PostgreSQL. The store's Windows PC (the checkout) talks to it over the local network. Nothing is opened to the internet.

```
[Windows PC, Chrome, POS app]  --Wi-Fi/LAN-->  [Ubuntu PC: PostgreSQL 5432 (+ POS API later)]
   sales saved locally first                     nightly backups
```

Important: the checkout never waits for this server. Sales are saved on the Windows PC first and sync when the Ubuntu PC is reachable, so if it is off or the Wi-Fi drops, the store keeps selling.

Run every command on the **Ubuntu PC**, in a Terminal (Ctrl+Alt+T), unless it says Windows.
Replace `192.168.1.50` with the Ubuntu PC's real address and `192.168.1.0/24` with your network (step 1 tells you both).

---

## Step 1. Check the machine (send Claude the output)

```bash
lsb_release -ds          # Ubuntu version
hostname -I              # the PC's IP address(es)
ip route | grep default  # the router's address
nproc; free -h; df -h /  # CPU, memory, disk
```

If the IP is `192.168.1.x`, your network is `192.168.1.0/24`. If it is `192.168.0.x`, it is `192.168.0.0/24`.

Tip: a network cable from the Ubuntu PC to the router is more reliable than Wi-Fi for a server. Wi-Fi works for the pilot.

## Step 2. Give the Ubuntu PC a fixed IP

The Windows PC must always find the server at the same address.

- **Best:** in the router's admin page (usually `http://192.168.1.1`, the address from `ip route`), find "DHCP reservation" / "IP fija" / "Reserva de dirección" and reserve the Ubuntu PC's current IP.
- **If you can't open the router:** Settings → Wi-Fi (or Network) → gear icon of the connection → IPv4 → Manual. Address: the current IP, Netmask: `255.255.255.0`, Gateway: the router address, DNS: `1.1.1.1, 8.8.8.8`. Save and turn the connection off and on.

## Step 3. Keep the PC awake and updated

```bash
sudo apt update && sudo apt -y upgrade
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
sudo apt -y install unattended-upgrades
```

Also: in the BIOS, set "Restore on AC power loss" to **On** if available, so it boots after a power cut. A small UPS (no-break) is strongly recommended.

## Step 4. Install PostgreSQL

```bash
sudo apt -y install postgresql postgresql-contrib ufw
psql --version
sudo systemctl enable --now postgresql
```

Note the major version (for example 16 on Ubuntu 24.04, 14 on 22.04). It appears in the paths below as `16`; change it if yours differs.

## Step 5. Create the database and users

Pick two strong passwords and keep them in a password manager. Do not send them to Claude or put them in chat.

```bash
sudo -u postgres psql
```

Inside `psql` (the prompt shows `postgres=#`):

```sql
CREATE ROLE pos_owner LOGIN PASSWORD 'CHANGE-ME-owner';
CREATE ROLE pos_app   LOGIN PASSWORD 'CHANGE-ME-app';
CREATE DATABASE abarrotes_pos OWNER pos_owner ENCODING 'UTF8' TEMPLATE template0;
\c abarrotes_pos
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO pos_app;
ALTER DATABASE abarrotes_pos SET timezone TO 'America/Mexico_City';
\q
```

- `pos_owner` owns the tables and runs migrations.
- `pos_app` is what the POS app uses; it gets only the permissions it needs.

## Step 6. Let only the store network connect

```bash
sudo nano /etc/postgresql/16/main/postgresql.conf
```

Find `#listen_addresses = 'localhost'` and change it to (remove the `#`):

```
listen_addresses = 'localhost,192.168.1.50'
```

Save with Ctrl+O, Enter, exit with Ctrl+X. Then:

```bash
sudo nano /etc/postgresql/16/main/pg_hba.conf
```

Add at the very end:

```
host  abarrotes_pos  pos_owner,pos_app  192.168.1.0/24  scram-sha-256
```

```bash
sudo systemctl restart postgresql
sudo ss -ltnp | grep 5432      # should show 127.0.0.1:5432 and 192.168.1.50:5432
```

## Step 7. Firewall: LAN only

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow from 192.168.1.0/24 to any port 5432 proto tcp
sudo ufw allow from 192.168.1.0/24 to any port 22 proto tcp   # only if you will use SSH
sudo ufw enable
sudo ufw status verbose
```

Never create a "port forwarding" rule for 5432 on the router. Remote access, when needed, will go through Tailscale, not an open port.

## Step 8. Test from the Windows PC

In **Windows PowerShell** on the store PC:

```powershell
Test-NetConnection 192.168.1.50 -Port 5432
```

`TcpTestSucceeded : True` means the network part is done. (Optional: install pgAdmin or DBeaver on Windows and connect with user `pos_owner` to database `abarrotes_pos`.)

## Step 9. Nightly backups

```bash
sudo mkdir -p /var/backups/pos && sudo chown postgres:postgres /var/backups/pos
sudo -u postgres crontab -e
```

Choose `nano` if asked and add this line (runs every night at 23:30, keeps 30 days):

```
30 23 * * * pg_dump -Fc abarrotes_pos > /var/backups/pos/abarrotes_pos_$(date +\%F).dump && find /var/backups/pos -name '*.dump' -mtime +30 -delete
```

Test it once by hand:

```bash
sudo -u postgres pg_dump -Fc abarrotes_pos > /tmp/test.dump && ls -lh /tmp/test.dump
```

A backup that stays on the same PC does not survive a theft or a dead disk. Next step: copy the newest dump weekly to a USB drive kept outside the store, or to encrypted cloud storage. Practise a restore once (`pg_restore -d abarrotes_pos_test file.dump`).

## Step 10. Tell Claude it is done

Send the output of:

```bash
psql --version; hostname -I; sudo ufw status; sudo ss -ltnp | grep 5432; ls /var/backups/pos
```

(no passwords). Next: Claude creates the MVP tables (suppliers, products, stock lots with expiry, alerts) as versioned migrations in the project repository.

---

### Later (not today)

- The POS API (Node) runs on this same PC on port 3000; the browser app talks to the API, never straight to the database. Its firewall rule will be added the same way as step 7.
- When the system moves to a hosted server with a domain, these same migrations and a backup restore move the data over.
