#!/usr/bin/env bash
# Edgerunner-dotfiles installer  (run once = install, run again = uninstall)
#
#   ./install.sh              toggle: install if not installed, uninstall if installed
#   ./install.sh install      force install
#   ./install.sh uninstall    force uninstall (restores your old setup)
#   ./install.sh pull         copy your LIVE configs (hyprland.lua, quickshell, kitty, ...) into the repo
#   ./install.sh status       show what's installed + where the backup lives
#   add -y / --yes to skip prompts
#
# Repo layout:
#   home/   -> ~/        (home/.config/hypr/hyprland.lua, home/commands/, ...)
#   etc/    -> /etc      (sudo; greetd etc. Stock Arch files are excluded, see EXCLUDES)
#   extras/dconf.ini     loaded with `dconf load /`
#   packages.txt         installed with --needed (optional)
#
# Your existing ~/.bashrc is never overwritten: home/.bashrc (if present) is
# appended as a marked block that uninstall removes cleanly.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/edgerunner-dotfiles"
MANIFEST="$STATE_DIR/manifest.tsv"
META="$STATE_DIR/meta"
BACKUP_ROOT="$HOME/.dotfiles-backup"
MARK_BEGIN="# >>> edgerunner-dotfiles >>>"
MARK_END="# <<< edgerunner-dotfiles <<<"

# Never installed from the repo. Stock Arch files (fontconfig, gtk, zsh) must not
# be copied over /etc - they belong to packages and would go stale.
EXCLUDES=('*/.git/*' '*.md' 'LICENSE*' 'install.sh' '*.bak' '*.bak.*' '*~'
          'Gallery/*' 'extras/*' 'packages.txt'
          'etc/fonts/*' 'etc/gtk-3.0/*' 'etc/zsh/*')

# `pull` copies these from your live system into the repo (relative to ~).
PULL=(.config/hypr .config/quickshell .config/kitty .config/qutebrowser commands)
PULL_ETC=(/etc/greetd)
PULL_EXCLUDES=('*.sqlite*' '*/cache/*' '*/Cache/*' '*/sessions/*' '*history*' '*cookies*'
               '*.log' '*.bak' '*.bak.*' '*~' '*/state' '*/qsettings/*' '*/webengine/*'
               '*/blocked-hosts' '*/crash*' '*/quickmarks' '*/bookmarks/*')

YES=0
c() { printf '\e[%sm%s\e[0m' "$1" "$2"; }
info() { echo "$(c 36 '::') $*"; }
warn() { echo "$(c 33 '!!') $*" >&2; }
die()  { echo "$(c 31 'xx') $*" >&2; exit 1; }
confirm() { [[ $YES == 1 ]] && return 0; read -rp "$1 [y/N] " a; [[ $a =~ ^[Yy]$ ]]; }

matches() { local p=$1; shift; local e; for e in "$@"; do [[ $p == $e ]] && return 0; done; return 1; }
excluded() { matches "$1" "${EXCLUDES[@]}"; }
is_installed() { [[ -f $MANIFEST ]]; }

# ---------------------------------------------------------------- backup ---
backup_one() { # backup_one <dest> <home|root>
  local dest=$1 kind=$2 t
  [[ -e $dest || -L $dest ]] || return 0
  if [[ $kind == home ]]; then t="$BACKUP_DIR/home/${dest#"$HOME"/}"; else t="$BACKUP_DIR/root/${dest#/}"; fi
  [[ -e $t || -L $t ]] && return 0
  if [[ $kind == home ]]; then mkdir -p "$(dirname "$t")"; cp -a "$dest" "$t"
  else sudo mkdir -p "$(dirname "$t")"; sudo cp -a "$dest" "$t"; fi
}

full_snapshot() {
  info "Snapshotting your current build -> $BACKUP_DIR"
  mkdir -p "$BACKUP_DIR"

  local paths=() p
  for p in .config .local/bin .local/share/fonts .local/share/icons .local/share/themes \
           .local/share/applications .local/share/quickshell .local/share/color-schemes \
           .local/share/qutebrowser commands Pictures pictures .icons .themes .fonts \
           .bashrc .bash_profile .bash_login .profile .zshrc .zprofile .zshenv \
           .gtkrc-2.0 .Xresources .XCompose .inputrc .gitconfig .tmux.conf; do
    [[ -e $HOME/$p || -L $HOME/$p ]] && paths+=("$p")
  done
  tar -czf "$BACKUP_DIR/user-snapshot.tar.gz" -C "$HOME" \
      --ignore-failed-read --warning=no-file-changed \
      --exclude='.config/*/Cache' --exclude='.config/*/cache' --exclude='.config/*/Code Cache' \
      --exclude='.config/*/GPUCache' --exclude='.config/*/Service Worker' \
      --exclude='.config/google-chrome' --exclude='.config/chromium' \
      --exclude='.config/discord' --exclude='.config/Code' --exclude='.config/Slack' \
      "${paths[@]}" 2>/dev/null || warn "some user files could not be read (continuing)"

  local rpaths=()
  for p in /etc/greetd /etc/sddm.conf /etc/sddm.conf.d /etc/environment /etc/xdg \
           /etc/systemd/system /etc/udev/rules.d /etc/modprobe.d /etc/vconsole.conf \
           /etc/fonts /etc/gtk-3.0 /etc/zsh /usr/share/sddm/themes /usr/share/wayland-sessions /usr/local/bin; do
    [[ -e $p ]] && rpaths+=("${p#/}")
  done
  if ((${#rpaths[@]})); then
    info "Need sudo to snapshot system files (greetd, systemd units, ...)"
    sudo tar -czf "$BACKUP_DIR/system-snapshot.tar.gz" -C / --ignore-failed-read \
        "${rpaths[@]}" 2>/dev/null || warn "some system files could not be read (continuing)"
  fi

  pacman -Qqen > "$BACKUP_DIR/pacman-explicit.txt" 2>/dev/null || true
  pacman -Qqem > "$BACKUP_DIR/pacman-aur.txt" 2>/dev/null || true
  systemctl list-unit-files --state=enabled --no-legend > "$BACKUP_DIR/systemd-system-enabled.txt" 2>/dev/null || true
  systemctl --user list-unit-files --state=enabled --no-legend > "$BACKUP_DIR/systemd-user-enabled.txt" 2>/dev/null || true
  if command -v dconf >/dev/null; then dconf dump / > "$BACKUP_DIR/dconf.ini" 2>/dev/null || true; fi
  if command -v gsettings >/dev/null; then gsettings list-recursively > "$BACKUP_DIR/gsettings.txt" 2>/dev/null || true; fi
  if command -v hyprctl >/dev/null; then hyprctl version > "$BACKUP_DIR/hyprland-version.txt" 2>/dev/null || true; fi
}

# --------------------------------------------------------------- install ---
collect() { # prints "kind<TAB>src<TAB>dest"
  local f rel
  if [[ -d $REPO/home ]]; then
    while IFS= read -r -d '' f; do
      rel=${f#"$REPO"/home/}
      [[ $rel == .bashrc ]] && continue
      excluded "home/$rel" && continue
      printf 'home\t%s\t%s\n' "$f" "$HOME/$rel"
    done < <(find "$REPO/home" \( -type f -o -type l \) -print0)
  fi
  if [[ -d $REPO/etc ]]; then
    while IFS= read -r -d '' f; do
      rel=${f#"$REPO"/}
      excluded "$rel" && continue
      printf 'root\t%s\t/%s\n' "$f" "$rel"
    done < <(find "$REPO/etc" \( -type f -o -type l \) -print0)
  fi
}

do_install() {
  [[ -f $REPO/home/.config/hypr/hyprland.lua ]] \
    || warn "home/.config/hypr/hyprland.lua is not in the repo yet - run './install.sh pull' first"
  local plan; plan=$(collect)
  [[ -n $plan || -f $REPO/home/.bashrc ]] || die "nothing to install - run this from the repo root"

  echo "$plan" | awk -F'\t' '{print "  " $1 "  " $3}'
  [[ -f $REPO/home/.bashrc ]] && echo "  home  ~/.bashrc (managed block appended)"
  [[ -f $REPO/extras/dconf.ini ]] && echo "  dconf extras/dconf.ini (asked separately)"
  confirm "Install the above? (your current build gets backed up first)" || die "aborted"

  BACKUP_DIR="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
  full_snapshot
  mkdir -p "$STATE_DIR"; : > "$MANIFEST"
  echo "BACKUP_DIR=$BACKUP_DIR" > "$META"

  local kind src dest
  while IFS=$'\t' read -r kind src dest; do
    [[ -n $kind ]] || continue
    backup_one "$dest" "$kind"
    if [[ $kind == home ]]; then
      mkdir -p "$(dirname "$dest")"; cp -a --remove-destination "$src" "$dest"
    else
      sudo mkdir -p "$(dirname "$dest")"; sudo cp -a --remove-destination "$src" "$dest"
    fi
    printf '%s\t%s\n' "$kind" "$dest" >> "$MANIFEST"
  done <<< "$plan"

  if [[ -f $REPO/home/.bashrc ]]; then
    backup_one "$HOME/.bashrc" home
    touch "$HOME/.bashrc"
    { echo "$MARK_BEGIN"; cat "$REPO/home/.bashrc"; echo "$MARK_END"; } >> "$HOME/.bashrc"
    echo "bashrc" >> "$MANIFEST"
  fi

  [[ -d $HOME/commands ]] && chmod +x "$HOME"/commands/* 2>/dev/null || true

  if [[ -f $REPO/extras/dconf.ini ]] && command -v dconf >/dev/null \
     && confirm "Load extras/dconf.ini into dconf (GTK/theme settings)?"; then
    dconf load / < "$REPO/extras/dconf.ini" && echo "dconf" >> "$MANIFEST" || warn "dconf load failed"
  fi

  if [[ -f $REPO/packages.txt ]] && confirm "Install packages from packages.txt?"; then
    local pm=(sudo pacman -S --needed --noconfirm); command -v yay >/dev/null && pm=(yay -S --needed --noconfirm)
    grep -vE '^\s*(#|$)' "$REPO/packages.txt" | xargs "${pm[@]}" || warn "some packages failed"
  fi

  info "Installed. Backup: $BACKUP_DIR"
  info "Reload with: hyprctl reload   (log out/in for greetd + shell changes)"
  info "Run ./install.sh again to uninstall and restore your old setup."
}

# ------------------------------------------------------------- uninstall ---
do_uninstall() {
  is_installed || die "not installed (no manifest at $MANIFEST)"
  # shellcheck disable=SC1090
  source "$META"
  [[ -d ${BACKUP_DIR:-} ]] || warn "backup dir ${BACKUP_DIR:-?} is gone - files will be removed but can't be restored"
  confirm "Uninstall Edgerunner-dotfiles and restore your old setup from ${BACKUP_DIR:-?}?" || die "aborted"

  local kind path d
  while IFS=$'\t' read -r kind path; do
    case $kind in
      home) rm -f -- "$path"
            d=$(dirname "$path")
            while [[ $d != "$HOME" && $d != / ]] && rmdir "$d" 2>/dev/null; do d=$(dirname "$d"); done ;;
      root) sudo rm -f -- "$path"
            d=$(dirname "$path")
            while [[ $d != / && $d != /etc && $d != /usr ]] && sudo rmdir "$d" 2>/dev/null; do d=$(dirname "$d"); done ;;
      bashrc) [[ -f $HOME/.bashrc ]] && sed -i "\|^$MARK_BEGIN\$|,\|^$MARK_END\$|d" "$HOME/.bashrc" ;;
      dconf) [[ -f ${BACKUP_DIR:-}/dconf.ini ]] && dconf load / < "$BACKUP_DIR/dconf.ini" \
               || warn "couldn't restore dconf (note: dconf load merges, it can't delete keys that were added)" ;;
    esac
  done < "$MANIFEST"

  if [[ -d ${BACKUP_DIR:-} ]]; then
    [[ -d $BACKUP_DIR/home ]] && cp -a "$BACKUP_DIR/home/." "$HOME/"
    [[ -d $BACKUP_DIR/root ]] && sudo cp -a "$BACKUP_DIR/root/." /
  fi

  rm -rf "$STATE_DIR"
  info "Restored. Backup kept at ${BACKUP_DIR:-?} (full tarballs inside, delete it when you're happy)."
  info "Packages from packages.txt were left installed. Run: hyprctl reload"
}

# ------------------------------------------------------------------ pull ---
do_pull() {
  local p f rel n=0 list=()
  for p in "${PULL[@]}"; do
    [[ -e $HOME/$p ]] || { warn "skip ~/$p (not found)"; continue; }
    while IFS= read -r -d '' f; do
      rel=${f#"$HOME"/}
      matches "$rel" "${PULL_EXCLUDES[@]}" && continue
      list+=("home	$f	$REPO/home/$rel")
    done < <(find "$HOME/$p" \( -type f -o -type l \) -print0)
  done
  for p in "${PULL_ETC[@]}"; do
    [[ -d $p ]] || continue
    while IFS= read -r -d '' f; do
      rel=${f#/}
      matches "$rel" "${PULL_EXCLUDES[@]}" && continue
      list+=("root	$f	$REPO/$rel")
    done < <(find "$p" \( -type f -o -type l \) -print0 2>/dev/null)
  done
  ((${#list[@]})) || die "nothing found to pull"

  printf '%s\n' "${list[@]}" | awk -F'\t' '{print "  " $3}' | sed "s|$REPO/||"
  warn "The repo is PUBLIC - skim the list above for tokens, passwords or personal paths first."
  confirm "Copy these ${#list[@]} files into the repo (overwrites repo copies)?" || die "aborted"
  local kind src dest
  for line in "${list[@]}"; do
    IFS=$'\t' read -r kind src dest <<< "$line"
    mkdir -p "$(dirname "$dest")"; cp -a --remove-destination "$src" "$dest"; n=$((n+1))
  done
  info "Pulled $n files. Review with: git -C '$REPO' status"

  echo; info "Other things in ~/.config you did NOT pull (add to PULL at the top if you want them):"
  local d name
  for d in "$HOME"/.config/*/; do
    name=$(basename "$d")
    [[ " ${PULL[*]} " == *" .config/$name "* ]] || echo "  .config/$name"
  done
}

do_status() {
  if is_installed; then
    source "$META"
    info "INSTALLED - $(grep -c . "$MANIFEST") entries, backup at $BACKUP_DIR"
  else
    info "not installed"; ls -1d "$BACKUP_ROOT"/* 2>/dev/null | sed 's/^/  old backup: /' || true
  fi
}

# ------------------------------------------------------------------ main ---
cmd=toggle
for a in "$@"; do
  case $a in
    -y|--yes) YES=1 ;;
    install|uninstall|status|toggle|pull) cmd=$a ;;
    -h|--help) sed -n '2,19p' "$0"; exit 0 ;;
    *) die "unknown arg: $a" ;;
  esac
done
[[ $EUID -eq 0 ]] && die "run as your normal user (it uses sudo only where needed)"

case $cmd in
  install)   is_installed && die "already installed - run './install.sh uninstall' first"; do_install ;;
  uninstall) do_uninstall ;;
  pull)      do_pull ;;
  status)    do_status ;;
  toggle)    if is_installed; then do_uninstall; else do_install; fi ;;
esac
