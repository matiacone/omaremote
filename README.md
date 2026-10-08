# Omaremote

Open the desktop of any other computer on your tailnet from the [Omarchy](https://omarchy.org/) bar.

Click the remote-desktop icon, pick a machine, and its desktop opens fullscreen. The remote gets a virtual screen at your screen's resolution and scale, so it fills your display as sharply as a local session. While you're connected its physical monitors are switched off. They come back on when you disconnect, or 20 seconds after the connection drops.

## Install

On the machine you connect **from**:

```bash
omarchy pkg add tigervnc
omarchy plugin add https://github.com/matiacone/omaremote.git --enable
ln -sf ~/.config/omarchy/plugins/io.github.matiacone.omaremote/bin/omaremote ~/.local/bin/omaremote
```

On each Linux machine you connect **to**: Hyprland, `wayvnc`, and SSH access from your user (either [Tailscale SSH](https://tailscale.com/kb/1193/tailscale-ssh) or a normal `sshd` with your key).

```bash
omarchy pkg add wayvnc
```

wayvnc runs without a password, so it never listens on a network port: it listens on a Unix socket in your runtime directory (`/run/user/<uid>`, readable only by you), and one SSH connection forwards that to another private socket on your machine. The same connection runs the setup and restore.

macOS machines connect straight to Screen Sharing (`:5900`) over the tailnet. On the Mac, turn on System Settings → Sharing → Screen Sharing, and under its options "VNC viewers may control screen with password". TigerVNC can't do Apple's account login.

## Use

The panel lists your online tailnet machines. The ones you can open (your own Linux and macOS machines) come first. Machines shared into your tailnet by someone else are listed but not offered.

| Key | Does |
| --- | --- |
| `Enter` / click | Connect |
| `m` | Toggle **Mirror the real monitor**: show the remote's own monitor in a window instead of the virtual screen |
| `h` | Toggle **H.264**: hardware video encoding, smoother on slow links and for video; colors come out slightly washed out |
| `r` | Refresh the list |

In the viewer, press **F8 → Exit viewer** to disconnect. Fullscreen sends Super shortcuts to the remote.

From a terminal:

```bash
omaremote                  # pick a machine (fzf)
omaremote my-desktop       # connect
omaremote --mirror host    # show the real monitor
omaremote --h264 host      # hardware H.264
omaremote user@host        # SSH as someone else
omaremote list             # online machines as JSON
```

## If a monitor stays off

The remote restores itself when the session ends. If it somehow doesn't, run `hyprctl reload` on it.

## License

MIT
