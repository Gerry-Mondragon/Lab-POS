# Abarrotes Anny POS: database server on Ubuntu (Docker)

Goal: the Ubuntu PC on the store's Wi-Fi runs PostgreSQL 16 in a Docker container. The store's Windows PC (the checkout) talks to it over the local network. Nothing is opened to the internet.

```
[Windows PC, Chrome, POS app]  --Wi-Fi/LAN-->  [Ubuntu PC: Docker → postgres:16.4 on port 5432 (+ POS API later)]
   sales saved locally first                     data in a Docker volume, nightly backups
```

Important: the checkout never waits for this server. Sales are saved on the Windows PC first and sync when the Ubuntu PC is reachable, so if it is off or the Wi-Fi drops, the store keeps selling.

Why Docker: the same `compose.yaml` runs on the Ubuntu PC, on a developer's laptop and later on a hosted server, with the exact same PostgreSQL version. Upgrades and moves are a matter of changing one line and restoring a backup.

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

The Windows PC must always find the server at the same address, and the container only listens on that address, so if it changes the database becomes unreachable.

- **Best:** in the router's admin page (usually `http://192.168.1.1`, the address from `ip route`), find "DHCP reservation" / "IP fija" / "Reserva de dirección" and reserve the Ubuntu PC's current IP.
- **If you can't open the router:** Settings → Wi-Fi (or Network) → gear icon of the connection → IPv4 → Manual. Address: the current IP, Netmask: `255.255.255.0`, Gateway: the router address, DNS: `1.1.1.1, 8.8.8.8`. Save and turn the connection off and on.

## Step 3. Keep the PC awake and updated

```bash
sudo apt update && sudo apt -y upgrade
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
sudo apt -y install unattended-upgrades git
```

Also: in the BIOS, set "Restore on AC power loss" to **On** if available, so it boots after a power cut. A small UPS (no-break) is strongly recommended.

## Step 4. Install Docker

Use Docker's official repository (not the `docker.io` snap):

```bash
sudo apt -y install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt update
sudo apt -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
```

Log out and back in (or reboot) so your user can run `docker` without `sudo`. Check:

```bash
docker run --rm hello-world
docker compose version
```

## Step 5. Get the project and set the passwords

```bash
cd ~
git clone https://github.com/Gerry-Mondragon/Lab-POS.git lab-pos
cd lab-pos
cp .env.example .env
nano .env
```

In `.env` set `DB_BIND_IP` to the Ubuntu PC's fixed IP and pick three strong passwords (superuser, owner, app). Keep them in a password manager. Do not send them to Claude, put them in chat, or commit `.env` (git already ignores it). Save with Ctrl+O, Enter, exit with Ctrl+X, then:

```bash
chmod 600 .env
```

(If the repo is private, `git clone` asks for your GitHub username and a personal access token instead of your password.)

## Step 6. Start the database

```bash
docker compose up -d
docker compose ps          # STATUS should say "healthy" after ~10 seconds
docker compose logs db | tail -20
```

On the first start, `db/init/01-roles.sh` creates the database `abarrotes_pos` and two users:

- `pos_owner` owns the tables and runs migrations.
- `pos_app` is what the POS app uses; it gets only the permissions it needs.

The data lives in the Docker volume `lab-pos_pgdata`, so it survives restarts, reboots and image updates. `restart: unless-stopped` brings the container back after a reboot.

## Step 7. Create the tables

```bash
docker exec -i pos-db psql -U pos_owner -d abarrotes_pos -v ON_ERROR_STOP=1 < db/migrations/0001_mvp_inventory.sql
docker exec -it pos-db psql -U pos_owner -d abarrotes_pos -c '\dt'
```

The second command should list `supplier`, `product`, `stock_lot`, `stock_movement` and the other tables. Each new migration file is applied the same way, in order.

## Step 8. Firewall

Docker publishes port 5432 on its own and **does not go through `ufw`**. What keeps the database off the internet is: the container listens only on the LAN address from `.env`, the router has no port forwarding to it, and every user has a strong password. Still turn on `ufw` for everything else on the PC:

```bash
sudo apt -y install ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow from 192.168.1.0/24 to any port 22 proto tcp   # only if you will use SSH
sudo ufw enable
sudo ufw status verbose
```

Never create a "port forwarding" rule for 5432 on the router. Remote access, when needed, will go through Tailscale, not an open port.

## Step 9. Test from the Windows PC

In **Windows PowerShell** on the store PC:

```powershell
Test-NetConnection 192.168.1.50 -Port 5432
```

`TcpTestSucceeded : True` means the network part is done. (Optional: install pgAdmin or DBeaver on Windows and connect with user `pos_owner` to database `abarrotes_pos`.)

## Step 10. Nightly backups

```bash
mkdir -p ~/pos-backups
./db/backup.sh             # test it once by hand
ls -lh ~/pos-backups
crontab -e
```

Choose `nano` if asked and add this line (every night at 23:30, keeps 30 days; replace `youruser` with your Ubuntu username, see `whoami`):

```
30 23 * * * /home/youruser/lab-pos/db/backup.sh >> /home/youruser/pos-backups/backup.log 2>&1
```

A backup that stays on the same PC does not survive a theft or a dead disk. Next step: copy the newest dump weekly to a USB drive kept outside the store, or to encrypted cloud storage. Practise a restore once:

```bash
docker exec -i pos-db createdb -U postgres restore_test
docker exec -i pos-db pg_restore -U postgres -d restore_test < ~/pos-backups/abarrotes_pos_YYYY-MM-DD.dump
docker exec -i pos-db dropdb -U postgres restore_test
```

## Step 11. Tell Claude it is done

Send the output of (no passwords):

```bash
hostname -I; docker compose ps; sudo ufw status; ls -lh ~/pos-backups
```

---

### Everyday commands

| What | Command (inside `~/lab-pos`) |
| --- | --- |
| Is it running? | `docker compose ps` |
| Logs | `docker compose logs --tail 50 db` |
| Restart | `docker compose restart db` |
| SQL console | `docker exec -it pos-db psql -U pos_owner -d abarrotes_pos` |
| Get the latest repo changes | `git pull` |

Never run `docker compose down -v`: the `-v` deletes the data volume.

### Upgrading PostgreSQL later

Minor versions (16.4 → 16.5): change the `image:` line in `compose.yaml`, then `docker compose pull && docker compose up -d`. Major versions (16 → 17) need a backup and restore into a fresh volume; do that with Claude or Alex, not by changing the line alone.

### Later (not today)

- The POS API (Node) will run as a second service in the same `compose.yaml`; the browser app talks to the API, never straight to the database.
- When the system moves to a hosted server with a domain, the same `compose.yaml`, migrations and a backup restore move the data over.
