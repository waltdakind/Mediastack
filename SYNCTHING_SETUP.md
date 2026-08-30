# Syncthing Configuration for MediaStack
# 
# This file documents the Syncthing setup for syncing config files
# between OrdinateurdeVolt (remote) and VoltaireDeux (local).
#
# Syncthing Web UI: http://localhost:8384
#
# Setup Instructions:
# 1. Start the stack: docker compose up -d
# 2. Open http://localhost:8384 in your browser
# 3. Configure two "devices":
#    - OrdinateurdeVolt (remote machine)
#    - VoltaireDeux (this machine)
# 4. Create a shared folder with path: /var/syncthing/data
# 5. Share it between both devices
#
# Volume Mapping:
# - ./syncthing/config  → Container's /var/syncthing/config (Syncthing settings)
# - ./syncthing/data    → Container's /var/syncthing/data (Shared sync data)
#
# Network Shares:
# - //OrdinateurdeVolt (remote media libraries)
# - //VoltaireDeux (local media libraries at c:\Users\Public\)
#
# To add more services:
# 1. Uncomment the example services in docker-compose.yml
# 2. Configure volumes to point to ../Music, ../Videos, etc.
# 3. Run: docker compose up -d
