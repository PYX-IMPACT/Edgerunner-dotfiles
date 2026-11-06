<div align="center">

```text
███████╗██████╗  ██████╗ ███████╗██████╗ ██╗   ██╗███╗   ██╗███╗   ██╗███████╗██████╗ 
██╔════╝██╔══██╗██╔════╝ ██╔════╝██╔══██╗██║   ██║████╗  ██║████╗  ██║██╔════╝██╔══██╗
█████╗  ██║  ██║██║  ███╗█████╗  ██████╔╝██║   ██║██╔██╗ ██║██╔██╗ ██║█████╗  ██████╔╝
██╔══╝  ██║  ██║██║   ██║██╔══╝  ██╔══██╗██║   ██║██║╚██╗██║██║╚██╗██║██╔══╝  ██╔══██╗
███████╗██████╔╝╚██████╔╝███████╗██║  ██║╚██████╔╝██║ ╚████║██║ ╚████║███████╗██║  ██║
╚══════╝╚═════╝  ╚═════╝ ╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝
```

### `> NEON // CHROME // WAYLAND <`

*A cyberpunk-flavoured Hyprland rice for Arch Linux.*
*Near-black glass, cyan signal lines, magenta hot-spots, yellow warnings.*

![Arch](https://img.shields.io/badge/ARCH-LINUX-2de2e6?style=for-the-badge&logo=archlinux&logoColor=black&labelColor=0a0a14)
![Hyprland](https://img.shields.io/badge/HYPRLAND-WAYLAND-ff2bd6?style=for-the-badge&labelColor=0a0a14)
![Zsh](https://img.shields.io/badge/SHELL-ZSH-fcee0a?style=for-the-badge&logo=gnubash&logoColor=black&labelColor=0a0a14)
![Status](https://img.shields.io/badge/STATUS-ONLINE-fb0a26?style=for-the-badge&labelColor=0a0a14)

</div>

<!-- TODO: add screenshots. Drop images in a `screenshots/` folder and uncomment: -->
<!--
<p align="center">
  <img src="screenshots/desktop.png" width="49%">
  <img src="screenshots/terminal.png" width="49%">
</p>
-->

---

## `// 00` SYSTEM OVERVIEW

This repo is the full configuration for my daily-driver desktop, codename **edgerunners**. It covers everything from the login screen to the prompt in my terminal: the compositor, the bar, the launcher, the shell, the theming, and a small collection of custom commands that glue it all together.

The design goal is simple: **one consistent look, minimal clutter, everything reproducible.** If my machine died tonight, I should be able to clone this repo on a fresh Arch install, run one script, and be back in the grid within minutes.

The visual identity is built on a single palette (see [`// 02`](#-02-palette)) that is reused everywhere: the shell prompt, `ls` colors, `fzf`, syntax highlighting, and the GUI configs. That's what makes it feel like one system instead of a pile of dotfiles.

> **Heads up:** these are *my* configs. They are meant to be read, borrowed from, and adapted, not blindly applied over a setup you care about. The install script backs up what it replaces, but read the [warnings](#-04-install) first.

---

## `// 01` THE STACK

| Layer | Component | Role |
|:--|:--|:--|
| **Login** | `greetd` | Minimal login manager, configured in `/etc/greetd` |
| **Compositor** | `Hyprland` | Wayland tiling compositor, config in `~/.config/hypr` |
| **Bar** | `waybar` | Status bar: workspaces, clock, system info |
| **Shell widgets** | `quickshell` | QML-based custom shell components |
| **Launcher** | `rofi` | App launcher and menus |
| **Terminal** | `kitty` | GPU-accelerated terminal emulator |
| **Shell** | `zsh` | Custom two-line prompt, command timer, git status, fzf |
| **Editor** | `fresh` | Terminal text editor, also used by the `newcmd` helper |
| **Wallpaper** | `swaybg` | Driven by my `wall` command |
| **Files** | `Thunar` (+ `xfce4` settings) | Graphical file manager |
| **Media** | `mpv`, `spotify` + `spicetify` | Video player; Spotify with a custom theme |
| **Sysinfo** | `fastfetch` | The obligatory neofetch flex |
| **Packages** | `yay`, `pacseek` | AUR helper and a TUI for browsing packages |
| **Theming** | `gtk-3.0`, `dconf` | GTK appearance and desktop settings |
| **Background services** | `systemd` (user units) | Autostart services and helpers |

---

## `// 02` PALETTE

One palette, used everywhere. Neon on near-black.

| | Name | Hex | Used for |
|:-:|:--|:--|:--|
| ![](https://img.shields.io/badge/-%20%20%20-2de2e6?style=flat-square) | **Cyan** | `#2de2e6` | Commands, directories, prompt arrow, primary accent |
| ![](https://img.shields.io/badge/-%20%20%20-ff2bd6?style=flat-square) | **Bloodred** | `#FB0A26` | Symlinks, fzf highlights and borders |
| ![](https://img.shields.io/badge/-%20%20%20-fcee0a?style=flat-square) | **Yellow** | `#fcee0a` | Brackets, strings, executables, warnings |
| ![](https://img.shields.io/badge/-%20%20%20-fb0a26?style=flat-square) | **Red** | `#fb0a26` | Prompt frame, git branch, separators |
| ![](https://img.shields.io/badge/-%20%20%20-ff3b5c?style=flat-square) | **Alert red** | `#ff3b5c` | Errors, failed-command arrow, unknown tokens |
| ![](https://img.shields.io/badge/-%20%20%20-6b5a8a?style=flat-square) | **Dim violet** | `#6b5a8a` | Comments, suggestions, secondary text |
| ![](https://img.shields.io/badge/-%20%20%20-e8e0ff?style=flat-square) | **Ink** | `#e8e0ff` | Main foreground text |
| ![](https://img.shields.io/badge/-%20%20%20-1a1030?style=flat-square) | **Deep purple** | `#1a1030` | Selection backgrounds |

---

## `// 03` REPO LAYOUT

```text
Edgerunner-dotfiles/
├── README.md          ← you are here
├── install.sh         ← deploys everything
├── packages.txt       ← explicitly installed packages
├── .gitignore
│
├── home/              ← mirrors $HOME
│   ├── .zshrc
│   ├── .config/       ← hypr, waybar, kitty, rofi, quickshell, ...
│   ├── commands/      ← custom scripts (added to PATH)
│   └── Pictures/
│       └── wallpapers/
│
├── etc/               ← mirrors /etc (needs root)
│   ├── zsh/
│   ├── gtk-3.0/
│   ├── greetd/
│   └── fonts/
│
└── extras/
    └── dconf.ini      ← exported desktop settings
```

The `home/` folder mirrors your home directory exactly, so `home/.config/hypr` belongs at `~/.config/hypr`. The `etc/` folder does the same for `/etc`, but those files are **copied**, not symlinked, because a broken symlink in a system folder like `/etc/greetd` could stop you from logging in.

---

## `// 04` INSTALL

> ⚠️ **Read before you run.** The install script touches your home directory and, with `sudo`, parts of `/etc` including the **login manager config**. Existing files are moved to `~/.dotfiles_backup/<timestamp>/` first, but if you only want some of this, copy the pieces by hand instead.

**1. Get an AUR helper** (needed for some packages):

```bash
sudo pacman -S --needed git base-devel
git clone https://aur.archlinux.org/yay.git /tmp/yay
cd /tmp/yay && makepkg -si
```

**2. Clone the repo:**

```bash
git clone https://github.com/YOURUSERNAME/Edgerunner-dotfiles ~/Edgerunner-dotfiles
cd ~/Edgerunner-dotfiles
```

**3. Install the packages** (review `packages.txt` first, it's a superset of what you strictly need):

```bash
yay -S --needed $(cat packages.txt)
```

**4. Deploy:**

```bash
chmod +x install.sh
./install.sh
```

**5. Log out and back in** (or reboot, if you replaced the greetd config).

---

## `// 05` CUSTOM COMMANDS

Everything in `~/commands` is on `$PATH` (set in `.zshrc`), so these work from anywhere.

| Command | What it does |
|:--|:--|
| **`wall [image]`** | Sets the wallpaper. With an image argument, copies it to `~/Pictures/Current.jpg` and applies it. With no argument, just reloads the current one. Restarts `swaybg` cleanly each time. |
| **`detach <cmd>`** | Runs any command fully detached from the terminal, so closing the window won't kill it. Handy for launching GUI apps. |
| **`newcmd <name>`** | Scaffolds a new command in `~/commands`: creates the file, adds the shebang, makes it executable, and opens it in the editor. Refuses to overwrite existing ones. |
| **`watchcmds`** | A background watcher (built on `inotifywait`) that monitors `~/commands` and runs my `compile` helper on newly dropped-in files. |
| **`compile`** | Helper used by `watchcmds` to process new command files. |

**Example:**

```bash
wall ~/Pictures/wallpapers/city-rain.jpg   # change the wallpaper
detach firefox                             # launch and forget
newcmd backup                              # start a new command
```

> `watchcmds` needs to be started at login to be useful. See `home/.config/hypr` or `home/.config/systemd` for how it's launched.

---

## `// 06` THE SHELL

The `.zshrc` is where a lot of the personality lives. Highlights:

- **Two-line cyberpunk prompt.** A red/yellow frame showing `user@host`, the working directory, and git branch status, with the arrow on the second line turning **cyan on success** and **red on failure**.
- **Command timer.** Any command that takes longer than 2 seconds shows its duration on the right side of the prompt, next to the clock.
- **Git awareness.** Branch name plus `*` for unstaged and `+` for staged changes, via `vcs_info`.
- **History that doesn't suck.** 50,000 entries, shared across terminals, duplicates and blank-padded entries removed.
- **Smart completion.** Case-insensitive, menu-style, with themed headings.
- **Autosuggestions.** Fish-style ghost text in dim violet. Press **Shift+Tab** to accept.
- **Syntax highlighting.** Valid commands glow cyan, strings are yellow, unknown tokens go red *as you type*.
- **`fzf` integration.** Fuzzy history search (`Ctrl+R`) and file finding, fully themed to match.
- **Modern replacements, if installed.** `eza` replaces `ls` (with icons and git info), and `bat` replaces `cat`. Without them, it falls back to plain colored `ls`.
- **Shortcuts.** `..` and `...` to go up directories, `rz` to reload the config, and `AUTO_CD` so typing a folder name just goes there.

---

## `// 07` DEPENDENCIES

The full list lives in `packages.txt`, but the important ones are:

```text
hyprland  waybar  kitty  rofi  quickshell  swaybg  greetd
zsh  zsh-autosuggestions  zsh-syntax-highlighting  fzf  eza  bat
inotify-tools  fastfetch  mpv  thunar  spotify  spicetify-cli
yay  pacseek  fresh
```

**Fonts:** the prompt uses box-drawing characters and `eza --icons` needs glyphs, so you need a **Nerd Font**.

<!-- TODO: name the exact font you use, e.g. "JetBrainsMono Nerd Font" -->
> Font used: **`YOUR NERD FONT HERE`**

Without it, you'll see empty squares where the icons should be.

---

## `// 08` SYSTEM-LEVEL CONFIG

A few things live outside the home directory and are installed to `/etc` by the script:

| Path | Purpose |
|:--|:--|
| `/etc/greetd/` | Login manager configuration (the first screen you see) |
| `/etc/zsh/` | System-wide zsh settings, loaded before `.zshrc` |
| `/etc/gtk-3.0/` | System-wide GTK defaults |
| `/etc/fonts/` | Font configuration |

These need `sudo`, and a mistake in `greetd` can leave you without a graphical login. **If that happens**, switch to a TTY (`Ctrl+Alt+F3`), log in, and restore the backup from `~/.dotfiles_backup/`.

---

## `// 09` KEYBINDINGS

<!-- TODO: fill this in from home/.config/hypr/hyprland.conf -->

| Keys | Action |
|:--|:--|
| `SUPER + Enter` | Open terminal |
| `SUPER + D` | Open launcher |
| `SUPER + Q` | Close window |

*Placeholder values. Replace with the real binds from the Hyprland config.*

---

## `// 10` KEEPING IT UPDATED

The repo is a **snapshot** of my live configs. I keep it current with two private helper scripts that aren't shipped in this repo:

1. **`dotsync`** copies the live files from `~` and `/etc` into this folder and refreshes the dconf export.
2. **`dotpush "message"`** commits everything and pushes to GitHub.

```bash
dotsync
dotpush "tweak waybar colors"
```

---

## `// 11` TROUBLESHOOTING

| Symptom | Likely cause |
|:--|:--|
| Boxes or `?` instead of icons | Nerd Font not installed, or the terminal isn't using it |
| `wall` does nothing | `swaybg` missing, or `~/Pictures/Current.jpg` doesn't exist yet |
| Custom commands not found | `~/commands` isn't on `$PATH`: check `.zshrc` was loaded |
| Prompt looks plain | Plugins missing: install `zsh-autosuggestions` and `zsh-syntax-highlighting` |
| `watchcmds` errors out | `inotify-tools` not installed |
| Black screen after reboot | `greetd` config issue: use a TTY and restore the backup |

---

## `// 12` CREDITS & LICENSE

Built on the shoulders of the Hyprland, Waybar, Quickshell, and Arch communities, and the endless inspiration of r/unixporn.

Feel free to take whatever's useful. A star is appreciated but never required.

<!-- TODO: add a LICENSE file (MIT is a common choice for dotfiles) and wallpaper credits if you ship images you didn't make. -->

<div align="center">

```text
> END OF TRANSMISSION_
```

</div>
