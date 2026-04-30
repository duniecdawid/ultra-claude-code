# tmux Cheatsheet

Prefix key: `Ctrl+b` (press and release, then the action key)

## Panes (splits within a window)

| Keys | Action |
|------|--------|
| `Ctrl+b %` | Split vertically (left/right) |
| `Ctrl+b "` | Split horizontally (top/bottom) |
| `Ctrl+b arrow` | Move focus between panes |
| `Ctrl+b Ctrl+arrow` | Resize pane |
| `Ctrl+b z` | Zoom pane (toggle fullscreen) |
| `Ctrl+b q` | Flash pane numbers (press number to jump) |
| `Ctrl+b x` | Kill current pane |

## Windows (tabs along the bottom bar)

| Keys | Action |
|------|--------|
| `Ctrl+b c` | Create new window |
| `Ctrl+b n` / `Ctrl+b p` | Next / previous window |
| `Ctrl+b 0-9` | Jump to window by number |
| `Ctrl+b ,` | Rename current window |
| `Ctrl+b &` | Kill current window |

## Sessions

| Keys | Action |
|------|--------|
| `Ctrl+b d` | Detach (session keeps running) |
| `Ctrl+b s` | List and switch sessions |

Shell: `tmux ls` to list, `tmux attach -t name` to reattach.

## Copy & Scroll

| Keys | Action |
|------|--------|
| `Ctrl+b [` | Enter copy/scroll mode |
| `Ctrl+b PgUp` | Enter copy mode and scroll up one page |
| Mouse drag | Select text (copies to clipboard, stays scrolled) |
| Mouse scroll down to bottom | Auto-exits copy mode |
| `q` | Exit copy mode (returns to bottom) |

### Vi navigation in copy mode

| Keys | Action |
|------|--------|
| `k` / `j` | Line up / down |
| `Ctrl+u` / `Ctrl+d` | Half page up / down |
| `Ctrl+b` / `Ctrl+f` | Full page up / down |
| `/` | Search forward |
| `?` | Search backward |
| `n` / `N` | Next / previous search match |
| `g` | Jump to top of history |
| `G` | Jump to bottom |

## Links

VS Code terminal supports clickable links, but tmux captures mouse events.
Use **Shift+Cmd+click** to bypass tmux and open links.

## Config

| Command | Action |
|---------|--------|
| `Ctrl+b :` | Open tmux command prompt |
| `tmux source-file ~/.tmux.conf` | Reload config |
