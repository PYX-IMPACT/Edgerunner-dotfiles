# ─────────────────────────────────────────────────────────────
#  ~/.zshrc  //  edgerunners
#  palette: cyan / bloodred / yellow / red on near-black
# ─────────────────────────────────────────────────────────────

# ───────── PATH ─────────
export PATH="$HOME/commands:$HOME/.local/bin:$PATH"
export EDITOR=fresh

# ───────── palette ─────────
typeset -A C
C[cyan]='#2de2e6'
C[bred]='#FB0A26'
C[yel]='#fcee0a'
C[red]='#ff3b5c'
C[dim]='#6b5a8a'
C[ink]='#e8e0ff'

# ───────── history ─────────
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS
setopt SHARE_HISTORY INC_APPEND_HISTORY

# ───────── behaviour ─────────
setopt AUTO_CD
setopt AUTO_PUSHD PUSHD_IGNORE_DUPS
setopt INTERACTIVE_COMMENTS
setopt PROMPT_SUBST
unsetopt BEEP

# ───────── completion ─────────
autoload -Uz compinit && compinit -d ~/.cache/zcompdump
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*:descriptions' format "%F{${C[bred]}}── %d ──%f"
zstyle ':completion:*:warnings'     format "%F{${C[red]}}no matches%f"

# ───────── keys ─────────
bindkey -e
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word

# ───────── git info for the prompt ─────────
autoload -Uz vcs_info
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' unstagedstr '*'
zstyle ':vcs_info:git:*' stagedstr '+'
zstyle ':vcs_info:git:*' formats ' %F{'${C[bred]}'}[%b%F{'${C[yel]}'}%u%c%F{'${C[bred]}'}]%f'

# ───────── command timer ─────────
zmodload zsh/datetime
typeset -g _cmd_start _cmd_took
preexec() { _cmd_start=$EPOCHREALTIME; print -Pn "\e]0;${1[1,60]}\a" }
precmd() {
  if [[ -n $_cmd_start ]]; then
    local d=$(( EPOCHREALTIME - _cmd_start ))
    (( d >= 2 )) && _cmd_took=$(printf '%.1fs' $d) || _cmd_took=''
    unset _cmd_start
  else
    _cmd_took=''
  fi
  vcs_info
  print -Pn "\e]0;%~\a"
}

# ───────── prompt ─────────
_arrow() { echo "%(?.%F{${C[cyan]}}.%F{${C[red]}})▶%f" }

PROMPT='%F{'${C[bred]}'}┌─%F{'${C[yel]}'}[%F{'${C[cyan]}'} %n%F{'${C[dim]}'}@%F{'${C[cyan]}'}%m %F{'${C[yel]}'}]%F{'${C[bred]}'}─%F{'${C[yel]}'}[%F{'${C[ink]}'} %~ %F{'${C[yel]}'}]%f${vcs_info_msg_0_}
%F{'${C[bred]}'}└─%f$(_arrow) '

RPROMPT='%F{'${C[red]}'}${_cmd_took}%f %F{'${C[dim]}'}%D{%H:%M}%f'
PROMPT2="%F{${C[bred]}}  ╎%f "

# ───────── colours for ls / grep ─────────
export LS_COLORS="di=1;38;2;45;226;230:ln=38;2;255;43;214:ex=1;38;2;252;238;10:so=38;2;255;59;92:*.md=38;2;232;224;255"
alias ls='ls --color=auto'
alias grep='grep --color=auto'
command -v eza >/dev/null && alias ls='eza --icons --group-directories-first' \
                          && alias ll='eza -l --icons --git --group-directories-first' \
                          && alias la='eza -la --icons --git --group-directories-first'
command -v bat >/dev/null && alias cat='bat --paging=never --style=plain'
alias ..='cd ..'
alias ...='cd ../..'
alias rz='source ~/.zshrc'

# ───────── fzf ─────────
export FZF_DEFAULT_OPTS="--height=40% --layout=reverse --border=sharp \
--color=bg:-1,bg+:#1a1030,fg:#e8e0ff,fg+:#ffffff,hl:#ff2bd6,hl+:#ff2bd6 \
--color=info:#6b5a8a,prompt:#2de2e6,pointer:#fcee0a,marker:#fcee0a,spinner:#ff2bd6,header:#6b5a8a,border:#ff2bd6 \
--prompt='▶ ' --pointer='▮' --marker='+'"
[[ -f /usr/share/fzf/key-bindings.zsh ]] && source /usr/share/fzf/key-bindings.zsh
[[ -f /usr/share/fzf/completion.zsh ]]   && source /usr/share/fzf/completion.zsh

# ───────── plugins ─────────
if [[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
  source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=${C[dim]}"
  bindkey '^[[Z' autosuggest-accept
fi

# syntax highlighting must be sourced last
if [[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
  ZSH_HIGHLIGHT_STYLES[command]="fg=${C[cyan]},bold"
  ZSH_HIGHLIGHT_STYLES[builtin]="fg=${C[cyan]},bold"
  ZSH_HIGHLIGHT_STYLES[alias]="fg=${C[cyan]},bold"
  ZSH_HIGHLIGHT_STYLES[function]="fg=${C[cyan]},bold"
  ZSH_HIGHLIGHT_STYLES[precommand]="fg=${C[yel]}"
  ZSH_HIGHLIGHT_STYLES[arg0]="fg=${C[cyan]}"
  ZSH_HIGHLIGHT_STYLES[path]="fg=${C[ink]},underline"
  ZSH_HIGHLIGHT_STYLES[single-quoted-argument]="fg=${C[yel]}"
  ZSH_HIGHLIGHT_STYLES[double-quoted-argument]="fg=${C[yel]}"
  ZSH_HIGHLIGHT_STYLES[globbing]="fg=${C[bred]}"
  ZSH_HIGHLIGHT_STYLES[comment]="fg=${C[dim]}"
  ZSH_HIGHLIGHT_STYLES[unknown-token]="fg=${C[red]},bold"
  ZSH_HIGHLIGHT_STYLES[commandseparator]="fg=${C[bred]}"
fi


netwatch-greet
