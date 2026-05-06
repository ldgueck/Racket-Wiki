# Racket OO-Wiki 🗂️ (Milestone 10.0)

Hey there! Welcome to my custom-built, lightweight knowledge base. It’s written entirely in Racket using its Object-Oriented features (`racket/class`). 

Instead of stressing over rigid folder structures, this wiki lets you organize as you go. Just write, link things together, and let your web of notes grow naturally! 

## ✨ Why it's cool

*   **Link Everything:** Just type `[[Page Name]]` to connect your thoughts. It handles spaces and special characters with no problem!
*   **Markdown Magic:** Write normally and it automatically renders headers, lists, bold, italics, and code blocks.
*   **Bulletproof Saving:** It uses a "Save-to-Temp-then-Rename" trick, so a sudden power outage won't nuke your database. 
*   **Plays Well With Others:** Under the hood, it uses Semaphore locks. This means if two people are editing at the same time, the data won't get corrupted.
*   **Smart Tracking:** It automatically tracks **Backlinks** (what links here?), finds **Wanted Pages** (links you haven't written yet), and spots **Orphans** (lonely pages with no links pointing to them).
*   **Media Gallery:** Upload and serve images directly from the local `/images/` folder.

## 🛠 What You Need
*   **Racket:** Version 9.1 [CS] or higher.
*   **External Package:** The Racket `markdown` library.

## 🚀 How to Run It Locally

### 1. Grab Racket
*   **Windows/Mac:** Download the installer from [racket-lang.org](https://racket-lang.org/).
*   **Ubuntu Linux:** 
    ```bash
    sudo add-apt-repository ppa:plt/racket
    sudo apt update
    sudo apt install racket
    ```

### 2. Install the Markdown Package
*   **If you use DrRacket:** Go to `File -> Package Manager`, search for `markdown`, and click **Install**.
*   **If you use the Terminal:**
    ```bash
    raco pkg install --auto markdown
    ```

### 3. Fire it up!
Just run the main file from your terminal:
```bash
racket wiki.rkt
```
Boom! Your wiki is now live at `http://localhost:8889`.

## 🐳 Running it on a Server (Docker)

Want to run this 24/7 on a Linux server? Docker makes it super easy:

1. Build the image:
   ```bash
   docker build -t wiki .
   ```
2. Run it in the background:
   ```bash
   docker run -it --rm -p 8889:8889 wiki
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

## 🗺 What's Next?
*   [x] Milestone 1: Core Engine & Server Deployment.
*   [x] Milestone 2: Markdown & Local Media Support.
*[x] Milestone 3: Image Uploads & Security.
*   [x] Milestone 9: Code refactoring, separated classes, and UI polish!
*   [ ] Milestone 10: The next big adventure! (Multi-user accounts, APIs, static exports... we're building it out now!)

## ⚖ License
*(Add your license here!)*

--- 

