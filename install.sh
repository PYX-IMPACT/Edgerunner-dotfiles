#!/usr/bin/env bash
# Edgerunner-dotfiles installer
#
#   ./install.sh              interactive menu (arrow keys / j k, enter)
#                             (no terminal attached: toggles install/uninstall)
#   ./install.sh install      force install
#   ./install.sh uninstall    force uninstall (restores your old setup)
#   ./install.sh toggle       install if not installed, uninstall if installed
#   ./install.sh update       pull latest from git + sync changes (no uninstall needed)
#   ./install.sh pull         copy your LIVE configs (hyprland.lua, quickshell, kitty, ...) into the repo
#   ./install.sh status       show what's installed + where the backup lives
#   add -y / --yes to skip prompts,  NO_COLOR=1 for plain output
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
SKIP_PULL=0

# ================================================================== UI ====
# Cyberpunk palette (256-colour). Falls back to plain text without a tty.
if [[ -t 1 && -z ${NO_COLOR:-} ]]; then FANCY=1; else FANCY=0; fi
C_Y='38;5;226'   # edgerunner yellow
C_C='38;5;51'    # cyan
C_M='38;5;201'   # magenta
C_G='38;5;46'    # green
C_R='38;5;196'   # red
C_D='38;5;244'   # dim grey
W=66             # panel width

c() { if ((FANCY)); then printf '\e[%sm%s\e[0m' "$1" "$2"; else printf '%s' "$2"; fi; }
info() { echo "  $(c "$C_C" '::') $*"; }
ok()   { echo "  $(c "$C_G" '✔') $*"; }
warn() { ((FANCY)) && printf '\r\e[K' >&2 || true; echo "  $(c "$C_Y" '!!') $*" >&2; }
die()  { show_cursor; echo "  $(c "$C_R" '✘') $*" >&2; exit 1; }
hide_cursor() { ((FANCY)) && printf '\e[?25l' || true; }
show_cursor() { ((FANCY)) && printf '\e[?25h' || true; }

rep() { local s="" i; for ((i=0;i<$2;i++)); do s+=$1; done; printf '%s' "$s"; }

banner_row() { # banner_row <plain text> <coloured text>
  local pad=$((W-4-${#1}))
  echo "  $(c "$C_Y" '▌')  $2$(rep ' ' "$pad")$(c "$C_Y" '▐')"
}
banner() {
  ((FANCY)) && printf '\e[2J\e[H' || true
  local t1='E D G E R U N N E R  //  dotfiles installer'
  local t2='hyprland · quickshell · kitty · greetd'
  echo
  echo "  $(c "$C_Y" "▛$(rep '▀' $((W-2)))▜")"
  banner_row "$t1" "$(c "1;$C_C" 'E D G E R U N N E R')  $(c "$C_M" '//')  $(c "$C_D" 'dotfiles installer')"
  banner_row "$t2" "$(c "$C_D" "$t2")"
  echo "  $(c "$C_Y" "▙$(rep '▄' $((W-2)))▟")"
  echo
}

section() { echo; echo "  $(c "1;$C_M" "▌ $1")"; echo "  $(c "$C_D" "$(rep '─' $((W-2)))")"; }

# panel "Title" line1 line2 ...   (plain text lines only)
panel() {
  local title=$1; shift
  local inner=$((W-4)) line
  printf '  %s%s%s\n' "$(c "$C_C" '╭─ ')" "$(c "1;$C_Y" "$title")" "$(c "$C_C" " $(rep '─' $((W-5-${#title})))╮")"
  for line in "$@"; do
    ((${#line} > inner)) && line="${line:0:$((inner-1))}…"
    printf '  %s %-*s %s\n' "$(c "$C_C" '│')" "$inner" "$line" "$(c "$C_C" '│')"
  done
  printf '  %s\n' "$(c "$C_C" "╰$(rep '─' $((W-2)))╯")"
}

# bar current total label
bar() {
  local cur=$1 tot=$2 label=${3:-} wd=28 f pct
  ((tot > 0)) || tot=1
  f=$((cur*wd/tot)); pct=$((cur*100/tot))
  if ((FANCY)); then
    printf '\r\e[K  %s%s %3d%%  %s' "$(c "$C_M" "$(rep '█' "$f")")" "$(c "$C_D" "$(rep '░' $((wd-f)))")" "$pct" "$(c "$C_D" "${label: -28}")"
  fi
}
bar_done() { ((FANCY)) && printf '\r\e[K' || true; }

# spin "label" cmd args...   (runs cmd in background with a spinner; rc!=0 => warning, not fatal)
spin() {
  local label=$1; shift
  if ((!FANCY)); then info "$label"; "$@" && return 0; warn "$label: finished with warnings"; return 0; fi
  local fr=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏) i=0 pid rc=0
  hide_cursor
  "$@" & pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    printf '\r  %s %s' "$(c "$C_C" "${fr[i%10]}")" "$label"
    i=$((i+1)); sleep 0.08
  done
  wait "$pid" || rc=$?
  printf '\r\e[K'; show_cursor
  if ((rc == 0)); then ok "$label"; else warn "$label  $(c "$C_D" '(some files skipped, continuing)')"; fi
  return 0
}

confirm() {
  [[ $YES == 1 ]] && return 0
  local a
  read -rp "  $(c "1;$C_Y" '?') $1 $(c "$C_D" '[y/N]') " a || return 1
  [[ $a =~ ^[Yy]$ ]]
}

SUDO_KEEPALIVE=""
need_sudo() {
  info "sudo needed for system files (greetd, /etc, ...)"
  sudo -v || die "sudo failed"
  ( while true; do sudo -n true 2>/dev/null; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) &
  SUDO_KEEPALIVE=$!
}
cleanup() { show_cursor; [[ -n $SUDO_KEEPALIVE ]] && kill "$SUDO_KEEPALIVE" 2>/dev/null || true; }
trap cleanup EXIT
trap 'echo; exit 130' INT

# ------------------------------------------------------------ menu ---------
MENU_CHOICE=""
menu() {
  local items labels sel=0 key k2 i n
  if is_installed; then
    items=(update uninstall pull status quit)
    labels=("Update      sync with the latest repo version" "Uninstall   restore your old setup" "Pull        copy live configs into the repo" "Status      what's installed + backup path" "Quit")
  else
    items=(install pull status quit)
    labels=("Install     back up current build & apply dotfiles" "Pull        copy live configs into the repo" "Status      what's installed + backup path" "Quit")
  fi
  n=${#items[@]}
  echo "  $(c "$C_D" '↑/↓ or j/k to move · enter to select · q to quit')"; echo
  hide_cursor
  while true; do
    for i in "${!items[@]}"; do
      if ((i == sel)); then printf '\e[K  %s %s\n' "$(c "$C_M" '▶')" "$(c "1;$C_Y" "${labels[i]}")"
      else printf '\e[K    %s\n' "$(c "$C_D" "${labels[i]}")"; fi
    done
    IFS= read -rsn1 key || key=q
    if [[ $key == $'\e' ]]; then k2=""; read -rsn2 -t 0.05 k2 || true; key=$k2; fi
    case $key in
      '[A'|k) sel=$(( (sel + n - 1) % n )) ;;
      '[B'|j) sel=$(( (sel + 1) % n )) ;;
      q|Q) MENU_CHOICE=quit; break ;;
      '') MENU_CHOICE=${items[sel]}; break ;;
    esac
    printf '\e[%dA' "$n"
  done
  show_cursor
}

matches() { local p=$1; shift; local e; for e in "$@"; do [[ $p == $e ]] && return 0; done; return 1; }
excluded() { matches "$1" "${EXCLUDES[@]}"; }
is_installed() { [[ -f $MANIFEST ]]; }
tilde() { local p=$1; printf '%s' "${p/#$HOME/~}"; }

# ---------------------------------------------------------------- backup ---
backup_one() { # backup_one <dest> <home|root>
  local dest=$1 kind=$2 t
  [[ -e $dest || -L $dest ]] || return 0
  if [[ $kind == home ]]; then t="$BACKUP_DIR/home/${dest#"$HOME"/}"; else t="$BACKUP_DIR/root/${dest#/}"; fi
  [[ -e $t || -L $t ]] && return 0
  if [[ $kind == home ]]; then mkdir -p "$(dirname "$t")"; cp -a "$dest" "$t"
  else sudo mkdir -p "$(dirname "$t")"; sudo cp -a "$dest" "$t"; fi
}

snap_user() {
  tar -czf "$BACKUP_DIR/user-snapshot.tar.gz" -C "$HOME" \
      --ignore-failed-read --warning=no-file-changed \
      --exclude='.config/*/Cache' --exclude='.config/*/cache' --exclude='.config/*/Code Cache' \
      --exclude='.config/*/GPUCache' --exclude='.config/*/Service Worker' \
      --exclude='.config/google-chrome' --exclude='.config/chromium' \
      --exclude='.config/discord' --exclude='.config/Code' --exclude='.config/Slack' \
      "$@" 2>/dev/null
}
snap_system() {
  sudo tar -czf "$BACKUP_DIR/system-snapshot.tar.gz" -C / --ignore-failed-read "$@" 2>/dev/null
}
snap_meta() {
  pacman -Qqen > "$BACKUP_DIR/pacman-explicit.txt" 2>/dev/null || true
  pacman -Qqem > "$BACKUP_DIR/pacman-aur.txt" 2>/dev/null || true
  systemctl list-unit-files --state=enabled --no-legend > "$BACKUP_DIR/systemd-system-enabled.txt" 2>/dev/null || true
  systemctl --user list-unit-files --state=enabled --no-legend > "$BACKUP_DIR/systemd-user-enabled.txt" 2>/dev/null || true
  if command -v dconf >/dev/null; then dconf dump / > "$BACKUP_DIR/dconf.ini" 2>/dev/null || true; fi
  if command -v gsettings >/dev/null; then gsettings list-recursively > "$BACKUP_DIR/gsettings.txt" 2>/dev/null || true; fi
  if command -v hyprctl >/dev/null; then hyprctl version > "$BACKUP_DIR/hyprland-version.txt" 2>/dev/null || true; fi
  return 0
}

full_snapshot() {
  section "Backing up your current build"
  info "-> $(tilde "$BACKUP_DIR")"
  mkdir -p "$BACKUP_DIR"

  local paths=() p
  for p in .config .local/bin .local/share/fonts .local/share/icons .local/share/themes \
           .local/share/applications .local/share/quickshell .local/share/color-schemes \
           .local/share/qutebrowser commands Pictures pictures .icons .themes .fonts \
           .bashrc .bash_profile .bash_login .profile .zshrc .zprofile .zshenv \
           .gtkrc-2.0 .Xresources .XCompose .inputrc .gitconfig .tmux.conf; do
    [[ -e $HOME/$p || -L $HOME/$p ]] && paths+=("$p")
  done
  spin "Archiving user files (~/.config, shell rc, themes...)" snap_user "${paths[@]}"

  local rpaths=()
  for p in /etc/greetd /etc/sddm.conf /etc/sddm.conf.d /etc/environment /etc/xdg \
           /etc/systemd/system /etc/udev/rules.d /etc/modprobe.d /etc/vconsole.conf \
           /etc/fonts /etc/gtk-3.0 /etc/zsh /usr/share/sddm/themes /usr/share/wayland-sessions /usr/local/bin; do
    [[ -e $p ]] && rpaths+=("${p#/}")
  done
  if ((${#rpaths[@]})); then
    spin "Archiving system files (greetd, systemd units...)" snap_system "${rpaths[@]}"
  fi
  spin "Recording packages, services & dconf state" snap_meta
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
  section "Install"
  [[ -f $REPO/home/.config/hypr/hyprland.lua ]] \
    || warn "home/.config/hypr/hyprland.lua is not in the repo yet - run './install.sh pull' first"
  local plan=() line kind src dest
  mapfile -t plan < <(collect)
  ((${#plan[@]})) || [[ -f $REPO/home/.bashrc ]] || die "nothing to install - run this from the repo root"

  local rows=() shown=0 max=18
  for line in "${plan[@]}"; do
    IFS=$'\t' read -r kind src dest <<< "$line"
    ((shown++ < max)) && rows+=("$( [[ $kind == root ]] && echo '⚡ sys ' || echo '▸ home')  $(tilde "$dest")")
  done
  ((${#plan[@]} > max)) && rows+=("… and $((${#plan[@]}-max)) more files")
  [[ -f $REPO/home/.bashrc ]] && rows+=("▸ home  ~/.bashrc  (managed block appended)")
  [[ -f $REPO/extras/dconf.ini ]] && rows+=("◆ dconf  extras/dconf.ini  (asked separately)")
  panel "Will be installed (${#plan[@]} files)" "${rows[@]}"
  echo
  confirm "Install the above? Your current build gets backed up first." || die "aborted"

  need_sudo
  BACKUP_DIR="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
  full_snapshot
  mkdir -p "$STATE_DIR"; : > "$MANIFEST"
  echo "BACKUP_DIR=$BACKUP_DIR" > "$META"

  section "Copying files"
  local i=0 total=${#plan[@]}
  for line in "${plan[@]}"; do
    IFS=$'\t' read -r kind src dest <<< "$line"
    [[ -n $kind ]] || continue
    backup_one "$dest" "$kind"
    if [[ $kind == home ]]; then
      mkdir -p "$(dirname "$dest")"; cp -a --remove-destination "$src" "$dest"
    else
      sudo mkdir -p "$(dirname "$dest")"; sudo cp -a --remove-destination "$src" "$dest"
    fi
    printf '%s\t%s\n' "$kind" "$dest" >> "$MANIFEST"
    i=$((i+1)); bar "$i" "$total" "$(basename "$dest")"
  done
  bar_done
  ok "Copied $total files"

  if [[ -f $REPO/home/.bashrc ]]; then
    backup_one "$HOME/.bashrc" home
    touch "$HOME/.bashrc"
    { echo "$MARK_BEGIN"; cat "$REPO/home/.bashrc"; echo "$MARK_END"; } >> "$HOME/.bashrc"
    echo "bashrc" >> "$MANIFEST"
    ok "Appended managed block to ~/.bashrc"
  fi

  [[ -d $HOME/commands ]] && chmod +x "$HOME"/commands/* 2>/dev/null || true

  if [[ -f $REPO/extras/dconf.ini ]] && command -v dconf >/dev/null \
     && confirm "Load extras/dconf.ini into dconf (GTK/theme settings)?"; then
    if dconf load / < "$REPO/extras/dconf.ini"; then echo "dconf" >> "$MANIFEST"; ok "dconf settings loaded"; else warn "dconf load failed"; fi
  fi

  if [[ -f $REPO/packages.txt ]] && confirm "Install packages from packages.txt?"; then
    section "Packages"
    local pm=(sudo pacman -S --needed --noconfirm); command -v yay >/dev/null && pm=(yay -S --needed --noconfirm)
    grep -vE '^\s*(#|$)' "$REPO/packages.txt" | xargs "${pm[@]}" || warn "some packages failed"
  fi

  echo
  panel "INSTALLED" \
    "Files:   $total" \
    "Backup:  $(tilde "$BACKUP_DIR")" \
    "" \
    "Reload:  hyprctl reload" \
    "Log out/in for greetd + shell changes" \
    "Run ./install.sh again to uninstall & restore"
}

# ------------------------------------------------------------- uninstall ---
do_uninstall() {
  section "Uninstall"
  is_installed || die "not installed (no manifest at $MANIFEST)"
  # shellcheck disable=SC1090
  source "$META"
  [[ -d ${BACKUP_DIR:-} ]] || warn "backup dir ${BACKUP_DIR:-?} is gone - files will be removed but can't be restored"
  panel "Restore point" "Backup:   $(tilde "${BACKUP_DIR:-?}")" "Entries:  $(grep -c . "$MANIFEST")"
  echo
  confirm "Uninstall Edgerunner-dotfiles and restore your old setup?" || die "aborted"
  need_sudo

  section "Removing files"
  local kind path d i=0 total
  total=$(grep -c . "$MANIFEST" || true)
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
    i=$((i+1)); bar "$i" "$total" "$(basename "${path:-$kind}")"
  done < "$MANIFEST"
  bar_done
  ok "Removed $total entries"

  if [[ -d ${BACKUP_DIR:-} ]]; then
    [[ -d $BACKUP_DIR/home ]] && cp -a "$BACKUP_DIR/home/." "$HOME/" && ok "Restored your user files"
    [[ -d $BACKUP_DIR/root ]] && sudo cp -a "$BACKUP_DIR/root/." / && ok "Restored your system files"
  fi

  rm -rf "$STATE_DIR"
  echo
  panel "RESTORED" \
    "Backup kept at: $(tilde "${BACKUP_DIR:-?}")" \
    "(full tarballs inside - delete it when you're happy)" \
    "" \
    "Packages from packages.txt were left installed." \
    "Run: hyprctl reload"
}

# ---------------------------------------------------------------- update ---
# Re-syncs an existing install with the repo: adds new files, overwrites changed
# ones, removes files that were deleted upstream. Keeps your ORIGINAL backup, and
# saves anything it overwrites to <backup>/updates/<timestamp>/ first.
do_update() {
  section "Update"
  is_installed || die "not installed yet - run './install.sh install' first"
  # shellcheck disable=SC1090
  source "$META"
  [[ -d ${BACKUP_DIR:-} ]] || die "backup dir ${BACKUP_DIR:-?} is gone - run uninstall, then install again"

  # 1. grab the newest repo version, then re-run so the NEW installer logic is used
  if [[ ${SKIP_PULL:-0} != 1 && -d $REPO/.git ]] && command -v git >/dev/null \
     && confirm "Fetch the latest version from git first?"; then
    git -C "$REPO" pull --ff-only || die "git pull failed (local changes in the repo?)"
    local args=(update --skip-pull); ((YES)) && args+=(--yes)
    exec bash "$REPO/install.sh" "${args[@]}"
  fi

  # 2. work out what differs between the repo and what is installed
  local plan=() line kind src dest
  mapfile -t plan < <(collect)
  declare -A want=()
  local add=() chg=() rem=() rows=()
  for line in "${plan[@]}"; do
    IFS=$'\t' read -r kind src dest <<< "$line"
    want[$dest]=$kind
    if [[ ! -e $dest && ! -L $dest ]]; then add+=("$line")
    elif ! cmp -s "$src" "$dest"; then chg+=("$line"); fi
  done
  while IFS=$'\t' read -r kind dest; do
    [[ $kind == home || $kind == root ]] || continue
    [[ -n ${want[$dest]:-} ]] || rem+=("$kind"$'\t'"$dest")
  done < "$MANIFEST"

  # ~/.bashrc managed block
  local had_rc=0 rc_change=0 cur=""
  grep -qx 'bashrc' "$MANIFEST" && had_rc=1
  if [[ -f $REPO/home/.bashrc ]]; then
    [[ -f $HOME/.bashrc ]] && cur=$(sed -n "\|^$MARK_BEGIN\$|,\|^$MARK_END\$|p" "$HOME/.bashrc" | sed '1d;$d')
    if ((!had_rc)) || [[ $cur != "$(cat "$REPO/home/.bashrc")" ]]; then rc_change=1; fi
  elif ((had_rc)); then rc_change=1; fi

  local n=$(( ${#add[@]} + ${#chg[@]} + ${#rem[@]} + rc_change ))
  if ((n == 0)); then
    echo; panel "UP TO DATE" "Nothing to change - the installed files match the repo."
    return 0
  fi

  local max=20
  for line in "${add[@]}"; do IFS=$'\t' read -r kind src dest <<< "$line"; rows+=("+ new      $(tilde "$dest")"); done
  for line in "${chg[@]}"; do IFS=$'\t' read -r kind src dest <<< "$line"; rows+=("~ changed  $(tilde "$dest")"); done
  for line in "${rem[@]}"; do IFS=$'\t' read -r kind dest <<< "$line"; rows+=("- removed  $(tilde "$dest")"); done
  ((rc_change)) && rows+=("~ changed  ~/.bashrc (managed block)")
  local more=$(( ${#rows[@]} - max ))
  ((more > 0)) && rows=("${rows[@]:0:$max}" "… and $more more")
  panel "Update: ${#add[@]} new, ${#chg[@]} changed, ${#rem[@]} removed" "${rows[@]}"
  echo
  confirm "Apply the update? (files it overwrites are saved to the backup first)" || die "aborted"

  need_sudo
  local UPD="$BACKUP_DIR/updates/$(date +%Y%m%d-%H%M%S)" t
  save_old() { # save_old <dest> <home|root>  -> copy into the updates folder before overwriting
    local d=$1 k=$2
    [[ -e $d || -L $d ]] || return 0
    if [[ $k == home ]]; then t="$UPD/home/${d#"$HOME"/}"; mkdir -p "$(dirname "$t")"; cp -a "$d" "$t"
    else t="$UPD/root/${d#/}"; sudo mkdir -p "$(dirname "$t")"; sudo cp -a "$d" "$t"; fi
  }
  put() { # put <kind> <src> <dest>
    if [[ $1 == home ]]; then mkdir -p "$(dirname "$3")"; cp -a --remove-destination "$2" "$3"
    else sudo mkdir -p "$(dirname "$3")"; sudo cp -a --remove-destination "$2" "$3"; fi
  }

  section "Applying"
  local i=0 total=$(( ${#add[@]} + ${#chg[@]} + ${#rem[@]} ))
  for line in "${add[@]}"; do
    IFS=$'\t' read -r kind src dest <<< "$line"
    backup_one "$dest" "$kind"; put "$kind" "$src" "$dest"
    i=$((i+1)); bar "$i" "$total" "$(basename "$dest")"
  done
  for line in "${chg[@]}"; do
    IFS=$'\t' read -r kind src dest <<< "$line"
    save_old "$dest" "$kind"; put "$kind" "$src" "$dest"
    i=$((i+1)); bar "$i" "$total" "$(basename "$dest")"
  done
  local d orig
  for line in "${rem[@]}"; do
    IFS=$'\t' read -r kind dest <<< "$line"
    save_old "$dest" "$kind"
    if [[ $kind == home ]]; then
      rm -f -- "$dest"; d=$(dirname "$dest")
      while [[ $d != "$HOME" && $d != / ]] && rmdir "$d" 2>/dev/null; do d=$(dirname "$d"); done
      orig="$BACKUP_DIR/home/${dest#"$HOME"/}"; [[ -e $orig || -L $orig ]] && cp -a "$orig" "$dest"
    else
      sudo rm -f -- "$dest"; d=$(dirname "$dest")
      while [[ $d != / && $d != /etc && $d != /usr ]] && sudo rmdir "$d" 2>/dev/null; do d=$(dirname "$d"); done
      orig="$BACKUP_DIR/root/${dest#/}"; [[ -e $orig || -L $orig ]] && sudo cp -a "$orig" "$dest"
    fi
    i=$((i+1)); bar "$i" "$total" "$(basename "$dest")"
  done
  bar_done
  ((total)) && ok "Synced $total files"

  if ((rc_change)); then
    [[ -f $HOME/.bashrc ]] && sed -i "\|^$MARK_BEGIN\$|,\|^$MARK_END\$|d" "$HOME/.bashrc"
    if [[ -f $REPO/home/.bashrc ]]; then
      backup_one "$HOME/.bashrc" home
      touch "$HOME/.bashrc"
      { echo "$MARK_BEGIN"; cat "$REPO/home/.bashrc"; echo "$MARK_END"; } >> "$HOME/.bashrc"
    fi
    ok "Updated ~/.bashrc managed block"
  fi

  # 3. rewrite the manifest so uninstall knows about the new file set
  local keep_dconf=0; grep -qx 'dconf' "$MANIFEST" && keep_dconf=1
  { for line in "${plan[@]}"; do IFS=$'\t' read -r kind src dest <<< "$line"; printf '%s\t%s\n' "$kind" "$dest"; done
    [[ -f $REPO/home/.bashrc ]] && echo "bashrc"
    ((keep_dconf)) && echo "dconf"
    true; } > "$MANIFEST.new" && mv "$MANIFEST.new" "$MANIFEST"

  [[ -d $HOME/commands ]] && chmod +x "$HOME"/commands/* 2>/dev/null || true

  echo
  panel "UPDATED" \
    "+${#add[@]} new   ~${#chg[@]} changed   -${#rem[@]} removed" \
    "Old versions saved in: $(tilde "$UPD")" \
    "" \
    "Reload:  hyprctl reload" \
    "(log out/in if greetd or shell files changed)"
}

# ------------------------------------------------------------------ pull ---
do_pull() {
  section "Pull live configs into the repo"
  local p f rel n=0 list=()
  for p in "${PULL[@]}"; do
    [[ -e $HOME/$p ]] || { warn "skip ~/$p (not found)"; continue; }
    while IFS= read -r -d '' f; do
      rel=${f#"$HOME"/}
      matches "$rel" "${PULL_EXCLUDES[@]}" && continue
      list+=("home"$'\t'"$f"$'\t'"$REPO/home/$rel")
    done < <(find "$HOME/$p" \( -type f -o -type l \) -print0)
  done
  for p in "${PULL_ETC[@]}"; do
    [[ -d $p ]] || continue
    while IFS= read -r -d '' f; do
      rel=${f#/}
      matches "$rel" "${PULL_EXCLUDES[@]}" && continue
      list+=("root"$'\t'"$f"$'\t'"$REPO/$rel")
    done < <(find "$p" \( -type f -o -type l \) -print0 2>/dev/null)
  done
  ((${#list[@]})) || die "nothing found to pull"

  local rows=() line kind src dest shown=0 max=22
  for line in "${list[@]}"; do
    IFS=$'\t' read -r kind src dest <<< "$line"
    ((shown++ < max)) && rows+=("▸ ${dest#"$REPO"/}")
  done
  ((${#list[@]} > max)) && rows+=("… and $((${#list[@]}-max)) more files")
  panel "Files to pull (${#list[@]})" "${rows[@]}"
  echo
  warn "The repo is PUBLIC - skim the list for tokens, passwords or personal paths first."
  confirm "Copy these ${#list[@]} files into the repo (overwrites repo copies)?" || die "aborted"

  local i=0
  for line in "${list[@]}"; do
    IFS=$'\t' read -r kind src dest <<< "$line"
    mkdir -p "$(dirname "$dest")"; cp -a --remove-destination "$src" "$dest"
    n=$((n+1)); bar "$n" "${#list[@]}" "$(basename "$dest")"
  done
  bar_done
  ok "Pulled $n files.  Review with: git -C '$REPO' status"

  local d name others=()
  for d in "$HOME"/.config/*/; do
    name=$(basename "$d")
    [[ " ${PULL[*]} " == *" .config/$name "* ]] || others+=(".config/$name")
  done
  if ((${#others[@]})); then
    echo
    info "Other things in ~/.config you did NOT pull (add to PULL at the top if you want them):"
    printf '     %s\n' "${others[@]}" | column -c "$W" 2>/dev/null || printf '     %s\n' "${others[@]}"
  fi
}

do_status() {
  section "Status"
  if is_installed; then
    # shellcheck disable=SC1090
    source "$META"
    panel "● INSTALLED" "Entries:  $(grep -c . "$MANIFEST")" "Backup:   $(tilde "$BACKUP_DIR")"
  else
    local olds=() b
    for b in "$BACKUP_ROOT"/*; do [[ -e $b ]] && olds+=("$(tilde "$b")"); done
    panel "○ NOT INSTALLED" "${olds[@]:-No old backups found}"
  fi
}

# ------------------------------------------------------------------ main ---
usage() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; }

cmd=""
for a in "$@"; do
  case $a in
    -y|--yes) YES=1 ;;
    install|uninstall|status|toggle|pull|update) cmd=$a ;;
    --skip-pull) SKIP_PULL=1 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown arg: $a" ;;
  esac
done
[[ $EUID -eq 0 ]] && die "run as your normal user (it uses sudo only where needed)"

if [[ -z $cmd ]]; then
  if [[ -t 0 && -t 1 ]]; then cmd=menu; else cmd=toggle; fi
fi

banner
case $cmd in
  menu)
    menu
    case $MENU_CHOICE in
      install)   do_install ;;
      uninstall) do_uninstall ;;
      pull)      do_pull ;;
      update)    do_update ;;
      status)    do_status ;;
      *)         echo "  $(c "$C_D" 'bye.')" ;;
    esac ;;
  install)   is_installed && die "already installed - run './install.sh uninstall' first"; do_install ;;
  uninstall) do_uninstall ;;
  pull)      do_pull ;;
  update)    do_update ;;
  status)    do_status ;;
  toggle)    if is_installed; then do_uninstall; else do_install; fi ;;
esac
echo
