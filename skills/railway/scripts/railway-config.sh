#!/usr/bin/env bash
# Railway multi-account config manager
# Usage: railway-config.sh <command> [args]
#
# Commands:
#   init                          Create config file if missing
#   get-token [dir]               Get token for directory (default: $PWD)
#   get-account [dir]             Get account name for directory
#   get-defaults [dir]            Get default service/environment for directory
#   add-account <name> <token> [description]
#   remove-account <name>
#   map-project <dir> <account> [service] [environment]
#   unmap-project <dir>
#   list-accounts
#   list-projects
#   set-default <account-name>

set -euo pipefail

CONFIG_DIR="$HOME/.config/railway-cli"
CONFIG_FILE="$CONFIG_DIR/config.json"

ensure_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    mkdir -p "$CONFIG_DIR"
    echo '{"accounts":{},"projects":{},"default_account":""}' > "$CONFIG_FILE"
    echo "Created config at $CONFIG_FILE"
  fi
}

case "${1:-help}" in
  init)
    ensure_config
    cat "$CONFIG_FILE"
    ;;

  get-token)
    ensure_config
    local_dir="${2:-$PWD}"
    # Try exact match first, then walk up the directory tree
    token=$(python3 -c "
import json, sys, os
with open('$CONFIG_FILE') as f:
    cfg = json.load(f)
d = os.path.realpath('$local_dir')
while d != '/':
    if d in cfg.get('projects', {}):
        acct = cfg['projects'][d].get('account', '')
        if acct in cfg.get('accounts', {}):
            print(cfg['accounts'][acct]['token'])
            sys.exit(0)
    d = os.path.dirname(d)
# Fallback to default account
da = cfg.get('default_account', '')
if da and da in cfg.get('accounts', {}):
    print(cfg['accounts'][da]['token'])
    sys.exit(0)
sys.exit(1)
" 2>/dev/null) || { echo "ERROR: No token found for $local_dir" >&2; exit 1; }
    echo "$token"
    ;;

  get-account)
    ensure_config
    local_dir="${2:-$PWD}"
    python3 -c "
import json, os
with open('$CONFIG_FILE') as f:
    cfg = json.load(f)
d = os.path.realpath('$local_dir')
while d != '/':
    if d in cfg.get('projects', {}):
        print(cfg['projects'][d].get('account', ''))
        exit(0)
    d = os.path.dirname(d)
print(cfg.get('default_account', ''))
"
    ;;

  get-defaults)
    ensure_config
    local_dir="${2:-$PWD}"
    python3 -c "
import json, os
with open('$CONFIG_FILE') as f:
    cfg = json.load(f)
d = os.path.realpath('$local_dir')
while d != '/':
    if d in cfg.get('projects', {}):
        p = cfg['projects'][d]
        svc = p.get('service', '')
        env = p.get('environment', '')
        if svc: print(f'-s {svc}', end=' ')
        if env: print(f'-e {env}', end=' ')
        exit(0)
    d = os.path.dirname(d)
"
    ;;

  add-account)
    ensure_config
    name="${2:?Usage: add-account <name> <token> [description]}"
    token="${3:?Usage: add-account <name> <token> [description]}"
    desc="${4:-}"
    python3 -c "
import json
with open('$CONFIG_FILE') as f:
    cfg = json.load(f)
cfg.setdefault('accounts', {})['$name'] = {'token': '$token', 'description': '''$desc'''}
if not cfg.get('default_account'):
    cfg['default_account'] = '$name'
with open('$CONFIG_FILE', 'w') as f:
    json.dump(cfg, f, indent=2)
print('Added account: $name')
"
    ;;

  remove-account)
    ensure_config
    name="${2:?Usage: remove-account <name>}"
    python3 -c "
import json
with open('$CONFIG_FILE') as f:
    cfg = json.load(f)
if '$name' in cfg.get('accounts', {}):
    del cfg['accounts']['$name']
    # Warn about orphaned projects
    orphaned = [d for d, p in cfg.get('projects', {}).items() if p.get('account') == '$name']
    if orphaned:
        print(f'WARNING: These projects still reference account \"$name\":')
        for d in orphaned: print(f'  {d}')
    if cfg.get('default_account') == '$name':
        cfg['default_account'] = ''
        print('WARNING: Cleared default account (was $name)')
    with open('$CONFIG_FILE', 'w') as f:
        json.dump(cfg, f, indent=2)
    print('Removed account: $name')
else:
    print('Account not found: $name')
    exit(1)
"
    ;;

  map-project)
    ensure_config
    dir="${2:?Usage: map-project <dir> <account> [service] [environment]}"
    account="${3:?Usage: map-project <dir> <account> [service] [environment]}"
    service="${4:-}"
    environment="${5:-}"
    dir=$(realpath "$dir")
    python3 -c "
import json
with open('$CONFIG_FILE') as f:
    cfg = json.load(f)
if '$account' not in cfg.get('accounts', {}):
    print('ERROR: Account \"$account\" not found. Add it first.')
    exit(1)
cfg.setdefault('projects', {})['$dir'] = {
    'account': '$account',
    $( [[ -n "$service" ]] && echo "'service': '$service'," || true )
    $( [[ -n "$environment" ]] && echo "'environment': '$environment'," || true )
}
with open('$CONFIG_FILE', 'w') as f:
    json.dump(cfg, f, indent=2)
print(f'Mapped $dir → $account')
"
    ;;

  unmap-project)
    ensure_config
    dir=$(realpath "${2:?Usage: unmap-project <dir>}")
    python3 -c "
import json
with open('$CONFIG_FILE') as f:
    cfg = json.load(f)
if '$dir' in cfg.get('projects', {}):
    del cfg['projects']['$dir']
    with open('$CONFIG_FILE', 'w') as f:
        json.dump(cfg, f, indent=2)
    print('Unmapped: $dir')
else:
    print('No mapping found for: $dir')
    exit(1)
"
    ;;

  list-accounts)
    ensure_config
    python3 -c "
import json
with open('$CONFIG_FILE') as f:
    cfg = json.load(f)
da = cfg.get('default_account', '')
for name, info in cfg.get('accounts', {}).items():
    default = ' ← default' if name == da else ''
    desc = info.get('description', '')
    desc_str = f' — {desc}' if desc else ''
    print(f'  {name}{desc_str}{default}')
if not cfg.get('accounts'):
    print('  (no accounts configured)')
"
    ;;

  list-projects)
    ensure_config
    python3 -c "
import json
with open('$CONFIG_FILE') as f:
    cfg = json.load(f)
for dir_path, info in cfg.get('projects', {}).items():
    acct = info.get('account', '?')
    svc = info.get('service', '')
    env = info.get('environment', '')
    extras = []
    if svc: extras.append(f'service={svc}')
    if env: extras.append(f'env={env}')
    extra_str = f' ({", ".join(extras)})' if extras else ''
    print(f'  {dir_path} → {acct}{extra_str}')
if not cfg.get('projects'):
    print('  (no projects mapped)')
"
    ;;

  set-default)
    ensure_config
    name="${2:?Usage: set-default <account-name>}"
    python3 -c "
import json
with open('$CONFIG_FILE') as f:
    cfg = json.load(f)
if '$name' not in cfg.get('accounts', {}):
    print('ERROR: Account \"$name\" not found')
    exit(1)
cfg['default_account'] = '$name'
with open('$CONFIG_FILE', 'w') as f:
    json.dump(cfg, f, indent=2)
print('Default account set to: $name')
"
    ;;

  help|*)
    echo "Railway multi-account config manager"
    echo ""
    echo "Commands:"
    echo "  init                                    Create config if missing"
    echo "  get-token [dir]                         Get token for directory"
    echo "  get-account [dir]                       Get account name for directory"
    echo "  get-defaults [dir]                      Get default -s/-e flags"
    echo "  add-account <name> <token> [desc]       Add an account"
    echo "  remove-account <name>                   Remove an account"
    echo "  map-project <dir> <account> [svc] [env] Map directory to account"
    echo "  unmap-project <dir>                     Remove directory mapping"
    echo "  list-accounts                           List all accounts"
    echo "  list-projects                           List all project mappings"
    echo "  set-default <name>                      Set default account"
    ;;
esac
