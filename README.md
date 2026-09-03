# United Bar

A macOS menu bar app that can track your United flight offline in real-time.
It works by reading local flight information available on the in-flight Wi-Fi
which is free for everyone.

```
✈ LAX → EWR 1h 52m
```

Clicking it opens the panel:

![The United Bar panel, tracking UA 1981 from LAX to EWR](docs/screenshot.png)

## Install

```sh
brew install --cask tale/tap/united-bar
```

Apple Silicon, macOS 14 or later. Builds are signed and notarized, so there is
no Gatekeeper prompt. Every push to `main` publishes a new one and `brew
upgrade` picks it up.

## How it works

When you connect to in-flight Wi-Fi, you're able to go to `unitedwifi.com` and
view live flight information. The data runs on a machine in the plane which we
poll once a minute, and every few seconds once you're inside 15 minutes of
landing and the countdown starts moving:

```
https://www.unitedwifi.com/api/flight/portal/v1/flifo
```

From there it's as simple as parsing some JSON and rendering it nicely!

