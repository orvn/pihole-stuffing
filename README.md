# Pihole Stuffing

A tool that customizes DNS endpoints for better quick access to pihole functionality straight from a URL.

## Usage

1. Log in to the Rasberry Pi running Pihole via SSH e.g., `ssh pi@192.168.x.x`

2. On the Pi, download the `stuff.sh` script from this repo 
```sh
curl -o stuff.sh https://raw.githubusercontent.com/orvn/pihole-stuffing/refs/heads/main/stuff.sh
```
3. Make it executable with `sudo chmod +x stuff.sh`

4. Change the IP address within the script to match your Rasberry Pi's dedicated local network IP

5. Run the script (as sudo)

```sh
sudo ./stuff.sh
```

All set! 🎉

Test by going to `unblock.ads` from any device on your local network.
