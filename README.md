# Racket OO-Wiki (Milestone 2.1)

A private, lightweight, modern knowledge base built entirely in Racket using Object-Oriented principles. This wiki follows the "Emergent Structure" philosophy, where organization is created through linking rather than folders.

## 🚀 Features
*   **Object-Oriented Backend:** Data and logic encapsulated in a robust `wiki%` class.
*   **Modern Linking:** Supports `[[Double Bracket]]` style internal links with support for spaces and special characters.
*   **Markdown Support:** Full rendering of headers, lists, bold, italics, and code blocks via the Racket `markdown` library.
*   **Atomic Persistence:** Uses a "Save-to-Temp-then-Rename" strategy to ensure data integrity during crashes or power failures.
*   **Thread-Safe:** Multi-user support via Semaphore locks to prevent data corruption.
*   **Media Support:** Local image serving from a dedicated `/images/` directory.
*   **Intelligence Tools:** Built-in logic for **Backlinks**, **Wanted Pages** (unwritten links), and **Orphan Detection**.

## 🛠 Technical Requirements
*   **Racket Version:** 9.1 [CS] or higher.
*   **Language:** `#lang racket`.

## 📦 Installation & Setup

### 1. Install Racket
*   **Windows:** Download the installer from [racket-lang.org](https://racket-lang.org/).
*   **Linux (Ubuntu):** 
    ```bash
    sudo add-apt-repository ppa:plt/racket
    sudo apt update
    sudo apt install racket
    ```

### 2. Install Required Packages
This project requires the external `markdown` package.

*   **Windows (DrRacket):** 
    Go to `File -> Package Manager`. Type `markdown` and click **Install**.
*   **Linux (Terminal):**
    ```bash
    raco pkg install --auto markdown
    ```

### 3. Run the Wiki
Save `wiki.rkt` and run it:
```bash
racket wiki.rkt
```
The wiki will be live at `http://localhost:8889`.

## 🐧 Deployment on Ubuntu Server
To run this as a persistent background service:

1. Create a service file: `sudo nano /etc/systemd/system/wiki.service`
2. Add your user details and paths to the service file.
3. Start the service:
   ```bash
   sudo systemctl enable wiki
   sudo systemctl start wiki
   ```
4. Open the firewall: `sudo ufw allow 8889`

## 📝 Wiki Syntax
| Feature | Syntax |
| :--- | :--- |
| **Internal Link** | `[[Page Name]]` |
| **External Link** | `[Title](URL)` |
| **Embed Image** | `![Alt Text](/images/filename.png)` |
| **Bold/Italic** | `**Bold**` / `*Italic*` |

## 💾 Storage
Data is stored in `wiki_storage.rktd` as a native Racket Association List. This makes the database human-readable and easy to back up using standard tools like `git` or `cron`.

## 🗺 Roadmap
*   [x] Milestone 1: Core OO Engine & Server Deployment.
*   [x] Milestone 2: Markdown & Local Media Support.
*   [ ] Milestone 3: Image Upload GUI and User Authentication.

## ⚖ License


---

### Tips for your GitHub Repository:
1.  **Add a `.gitignore` file:** Inside this file, put `*.tmp` and `*.rktd`. This tells GitHub **not** to upload your personal notes or temporary files, only your code.
2.  **Screenshot:** Take a screenshot of your `HomePage` and upload it to GitHub, then link to it at the top of the README.
3.  **About Section:** On the right side of the GitHub page, add a short description and tags like `racket`, `wiki`, and `functional-programming`.
