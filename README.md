



# Racket OO-Wiki 🗂️ 

Hey there! Welcome to my custom-built, lightweight knowledge base. It’s written entirely in Racket using its Object-Oriented features (`racket/class`). 

Instead of stressing over rigid folder structures, this wiki lets you organize as you go. Just write, link things together, and let your web of notes grow naturally! It recently underwent a massive refactoring to separate the backend logic, authentication, and frontend UI into clean, modular files.

## ✨ Why it's cool

*   **Link Everything:** Just type `[[Page Name]]` to connect your thoughts. It handles spaces and special characters with no problem, and automatically color-codes existing vs. "wanted" pages.
*   **Markdown Magic:** Write normally and it automatically renders headers, lists, bold, italics, and code blocks.
*   **Bulletproof Saving:** It uses an atomic "Save-to-Temp-then-Rename" trick, so a sudden power outage won't nuke your database. 
*   **Multi-User Safe:** Under the hood, it uses Semaphore locks (`mutex`). This means if two people are editing at the same time, the data won't get corrupted.
*   **Smart Tracking:** It automatically tracks **Backlinks** (what links here?), finds **Wanted Pages** (links you haven't written yet), and spots **Orphans** (lonely pages with no links pointing to them).
*   **The Janitor:** Upload and serve images directly from the local `/images/` folder. The system actively scans your pages to identify which images are in use and which are orphaned.
*   **Super Backup:** Download your entire wiki as a `.zip` file with a single click, using a streaming response to bypass RAM limits.

## 📦 Packages & Dependencies

This project relies on a mix of Racket's robust standard libraries and a few external packages.

**Built-in Racket Libraries Used (No installation required):**
*   `web-server/servlet` & `web-server/http` (The web framework)
*   `racket/class` (Object-Oriented system)
*   `xml` (For rendering frontend X-Expressions)
*   `file/zip` (For generating backups)

**External Packages Required:**
You will need to install the Markdown package for the parser to work.
```bash
raco pkg install --auto markdown
```
*(Note: If you are using Minimal Racket, you may also need to install the web server via `raco pkg install web-server-lib`)*.

## 🚀 How to Run It Locally

### 1. Grab Racket
*   **Windows/Mac:** Download the installer from[racket-lang.org](https://racket-lang.org/).
*   **Ubuntu Linux:** 
    ```bash
    sudo add-apt-repository ppa:plt/racket
    sudo apt update
    sudo apt install racket
    ```

### 2. Fire it up!
Just run the main file from your terminal:
```bash
racket wiki.rkt
```
Boom! Your wiki is now live at `http://localhost:8889`.

## 🐧 Deploying on a Linux Server (Systemd)

Want to run this 24/7 on a Linux server completely hands-free? Use `systemd` so it automatically restarts on crashes and reboots.

1. Create a service file:
   ```bash
   sudo nano /etc/systemd/system/racket-wiki.service
   ```
2. Paste this configuration (update the `User` and `WorkingDirectory` to match your setup):
   ```ini
   [Unit]
   Description=Racket OO-Wiki Service
   After=network.target

   [Service]
   Type=simple
   User=lynn
   WorkingDirectory=/home/lynn/mywiki
   ExecStart=/usr/bin/racket wiki.rkt
   Restart=always
   RestartSec=3

   [Install]
   WantedBy=multi-user.target
   ```
3. Enable and start it:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable racket-wiki
   sudo systemctl start racket-wiki
   ```

## 📝 Quick Syntax Guide

| Want to do this? | Type this! |
| :--- | :--- |
| **Link to a wiki page** | `[[My Cool Page]]` |
| **Link to the outside web** | `[Click Here](https://google.com)` |
| **Add an image** | `![Picture](/images/photo.png)` |
| **Format text** | `**Bold**` or `*Italic*` |

## 💾 Where does my data go?
Everything is saved in a single file called `wiki_storage.rktd`. It's a native Racket Association List, which is just a fancy way of saying it's saved as plain text. This makes it incredibly easy to read, back up, or drop into Git!

## 🗺 Roadmap
*   [x] Milestone 1: Core Engine & Server Deployment.
*   [x] Milestone 2: Markdown & Local Media Support.
*   [x] Milestone 3: Image Uploads & Security.
*   [x] Milestone 9: Code refactoring, separated classes, UI polish, and Linux daemonization!
*   [ ] Milestone 10: The next big adventure! (Multi-user accounts, APIs, static exports... under construction!)

## ⚖ License
