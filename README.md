# Pihole Stuffing

A tool that customizes DNS endpoints for better quick access to pihole functionality straight from a URL.

## Requirements
- Must have a Rasberry Pi running Pihole connected to the local network on a dedicated IP
- Assumes DNS is configured through the Pihole
- Tested on [Rasberry Pi OS](https://www.raspberrypi.com/software/), should be compatible with other distros

## Usage

1. Log in to the Rasberry Pi running Pihole via SSH e.g., `ssh pi@192.168.x.x` (you may need to run `sudo raspi-config` to enable SSH)

2. On the Pi, download the `stuff.sh` script from this repo 
```sh
curl -o stuff.sh https://raw.githubusercontent.com/orvn/pihole-stuffing/refs/heads/main/stuff.sh && chmod +x stuff.sh
```
3. Run the script (as sudo), and ensure it detects the correct IP for the Rasberry Pi

```sh
sudo ./stuff.sh
```

All set! 🎉

Try by going to `unblock.ads` from any device on your local network.
