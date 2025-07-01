<h1 align="center">Phishkit</h1>

<p align="center"><i>Automated Gophish + Webhook + Certbot Installer with tmux session handling</i></p>

<p align="center">
  <img src="https://img.shields.io/badge/last%20commit-July%202025-blue" />
  <img src="https://img.shields.io/badge/shell-100%25-blue" />
  <img src="https://img.shields.io/badge/languages-1-grey" />
  <img src="https://img.shields.io/badge/tested%20on-Ubuntu%2024.04%20LTS-green" />
</p>

<p align="center"><i>Built with the tools and technologies:</i></p>

<p align="center">
  <img src="https://img.shields.io/badge/-GNU%20Bash-4EAA25?logo=gnubash&logoColor=white" />
  <img src="https://img.shields.io/badge/-Gophish-blueviolet" />
  <img src="https://img.shields.io/badge/-tmux-1BB91F" />
  <img src="https://img.shields.io/badge/-Certbot-007EC6" />
</p>

---

## 🚀 What is Phishkit?

**Phishkit** is a one-click Bash installer that:
- Automatically installs and configures **Gophish**
- Runs a **webhook listener** using Go
- Sets up **HTTPS certificates** with Certbot
- Uses **tmux** to manage background sessions
- Outputs admin panel credentials and IP info

> ✅ Tested and working on **Ubuntu 24.04 LTS**

Perfect for red teamers, phishing simulation, or security labs.

---

## ⚙️ How to Use

```bash
git clone https://github.com/pashamajied/phishkit.git
cd phishkit
chmod +x phishkit-setup.sh
sudo ./phishkit-setup.sh
