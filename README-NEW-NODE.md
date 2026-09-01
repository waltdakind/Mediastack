# MediaStack Cluster Node Installation Guide

Welcome to your new MediaStack node.

## Quick Setup (1-Click)
1. Right-click ootstrap.bat -> **Run as Administrator** (or run .\Bootstrap-NewNode.ps1 in an elevated PowerShell).
2. The installer will automatically:
   - Create local mediasync, oltaireun, and oltairedeux network service accounts.
   - Create and grant Read-Write access to media folders (Music, TV, Videos, Radio, Podcasts).
   - Configure SMB network shares (\\<hostname>\\Public-Music, etc.).
   - Connect and mount peer shares from VoltaireUn (192.168.4.21) and VoltaireDeux (192.168.4.30).
   - Launch Caddy and Docker containers.

## Quick Management Menu
Run .\\s.ps1 to open the interactive single-key HUD.

