# Restic Auto Backup Script

A lightweight, cron-compatible Bash script to automate secure backups using [Restic](https://restic.net/) and [Rclone](https://rclone.org/). This script supports multiple backup paths, healthchecks, excludes, logging, and dry-run functionality.

## Features

- 🔒 Uses [Restic](https://restic.net/) for encrypted, incremental backups
- 🗂 Supports multiple paths via `.env` config
- 🛑 Optional healthcheck integration via [healthchecks.io](https://healthchecks.io/)
- 📄 Exclude rules via file
- 🔄 Compatible with cron or systemd timers
- 📦 Environment-based configuration via `.env` and `.secret`
- 🧪 Dry-run mode for testing

## Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/your-username/restic-auto-backup.git
cd restic-auto-backup
```

### 2. Configuration

#### Create your configuration files

```bash
cp .env.example .env
cp .secret.example .secret
```

Edit `.env` and `.secret` to match your system and backup setup.

### 3. Make it executable

```bash
chmod +x backup.sh
```

### 4. Test it

Run the script manually:

```bash
./backup.sh --dry-run
```

### 5. Set up a cron job

Edit your crontab:

```bash
crontab -e
```

Add an entry like this to run daily at 3am:

```cron
0 3 * * * cd /path/to/backup && backup.sh > /dev/null
```

> [!IMPORTANT]  
> It's nessasary to `cd` into the working directory!

## Requirements

- Bash
- `restic`
- `curl`
- `uuidgen`

Install via apt on Debian/Ubuntu:

```bash
sudo apt install -y restic curl uuid-runtime
```

---

Back up smart. Back up safe. 💾

> Made with 💚 by [Jani](https://github.com/jnnkls)
