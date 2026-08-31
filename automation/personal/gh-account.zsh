# gh account routing — sourced from zsh, not executed.
#
# Wraps `gh` so the right GitHub account is used per directory without ever
# running `gh auth switch`: work account inside ~/CultureX, personal everywhere
# else. Both accounts stay logged in; only the injected GH_TOKEN changes.

GH_PERSONAL_ACCOUNT="surajkuushwaha"
GH_WORK_ACCOUNT="cx-suraj"

typeset -gA _gh_token_cache

_gh_account_for_pwd() {
  case "$PWD/" in
    "$HOME"/CultureX/*) print -r -- "$GH_WORK_ACCOUNT" ;;
    *)                  print -r -- "$GH_PERSONAL_ACCOUNT" ;;
  esac
}

gh() {
  # `gh auth ...` must never see an injected token or it refuses to manage accounts
  if [[ "$1" == "auth" ]]; then
    command gh "$@"
    return
  fi

  local acct token
  acct="$(_gh_account_for_pwd)"
  token="${_gh_token_cache[$acct]}"
  if [[ -z "$token" ]]; then
    token="$(command gh auth token -u "$acct" 2>/dev/null)"
    [[ -n "$token" ]] && _gh_token_cache[$acct]="$token"
  fi

  if [[ -n "$token" ]]; then
    GH_TOKEN="$token" command gh "$@"
  else
    # account not logged in yet — fall back to whatever gh considers active
    command gh "$@"
  fi
}

# which account will gh use here?
ghwho() {
  local acct="$(_gh_account_for_pwd)"
  print -r -- "dir:  $PWD"
  print -r -- "acct: $acct"
  gh api user -q .login 2>/dev/null | sed 's/^/api:  /'
}
