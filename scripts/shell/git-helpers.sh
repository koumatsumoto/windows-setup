#!/usr/bin/env bash

_windows_setup_default_branch() {
  local remote_head first_line

  remote_head="$(git ls-remote --symref origin HEAD)" || {
    echo "git helpers: could not determine origin's default branch" >&2
    return 1
  }
  first_line="${remote_head%%$'\n'*}"

  case "$first_line" in
    'ref: refs/heads/'*$'\tHEAD') ;;
    *)
      echo "git helpers: origin HEAD does not identify a branch" >&2
      return 1
      ;;
  esac

  first_line="${first_line#ref: refs/heads/}"
  printf '%s\n' "${first_line%$'\t'HEAD}"
}

_windows_setup_primary_worktree() {
  local field

  while IFS= read -r -d '' field; do
    case "$field" in
      'worktree '*)
        printf '%s\n' "${field#worktree }"
        return 0
        ;;
    esac
  done < <(git worktree list --porcelain -z)

  echo "git helpers: could not determine the primary worktree" >&2
  return 1
}

# Update the default branch by fast-forward, then delete merged local branches
# that are not checked out in any worktree.
grb() {
  local default_branch default_ref remote_default_ref default_wt branch
  local rc=0

  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "grb: not inside a Git worktree" >&2
    return 1
  }

  default_branch="$(_windows_setup_default_branch)" || return 1
  default_ref="refs/heads/$default_branch"
  remote_default_ref="refs/remotes/origin/$default_branch"

  git show-ref --verify --quiet "$default_ref" || {
    echo "grb: local default branch '$default_branch' does not exist" >&2
    return 1
  }

  git fetch origin \
    "refs/heads/$default_branch:$remote_default_ref" ||
    return 1

  git show-ref --verify --quiet "$remote_default_ref" || {
    echo "grb: remote-tracking branch 'origin/$default_branch' does not exist" >&2
    return 1
  }

  if ! git merge-base --is-ancestor "$default_ref" "$remote_default_ref"; then
    echo "grb: local '$default_branch' cannot be fast-forwarded to 'origin/$default_branch'" >&2
    return 1
  fi

  default_wt="$(git for-each-ref \
    --format='%(worktreepath)' \
    "$default_ref"
  )"

  if [[ -n "$default_wt" ]]; then
    git -C "$default_wt" merge --ff-only "$remote_default_ref" || return 1
  else
    git branch -f "$default_branch" "$remote_default_ref" || return 1
  fi

  while IFS= read -r branch; do
    [[ -z "$branch" || "$branch" == "$default_branch" ]] && continue

    if ! git branch -D -- "$branch"; then
      rc=1
    fi
  done < <(
    git for-each-ref \
      --merged="$default_ref" \
      --format='%(if)%(worktreepath)%(then)%(else)%(refname:short)%(end)' \
      refs/heads/
  )

  return "$rc"
}

# Keep the primary default-branch worktree and remove every linked worktree.
# Local branch refs remain available for a later grb or combined gr cleanup.
grw() {
  local default_branch field wt branch primary_wt primary_branch
  local first_record=1 rc=0
  local -a worktrees=()

  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "grw: not inside a Git worktree" >&2
    return 1
  }

  default_branch="$(_windows_setup_default_branch)" || return 1

  wt=
  branch=

  while IFS= read -r -d '' field; do
    if [[ -z "$field" ]]; then
      if [[ -n "$wt" ]]; then
        if (( first_record )); then
          primary_wt="$wt"
          primary_branch="$branch"
          first_record=0
        else
          worktrees+=("$wt")
        fi
      fi

      wt=
      branch=
      continue
    fi

    case "$field" in
      'worktree '*) wt="${field#worktree }" ;;
      'branch '*) branch="${field#branch }" ;;
    esac
  done < <(git worktree list --porcelain -z)

  if [[ -z "$primary_wt" ]]; then
    echo "grw: could not determine the primary worktree" >&2
    return 1
  fi

  if [[ "$primary_branch" != "refs/heads/$default_branch" ]]; then
    echo "grw: primary worktree is not on '$default_branch'; refusing cleanup" >&2
    echo "grw: primary worktree: $primary_wt" >&2
    return 1
  fi

  if (( ${#worktrees[@]} == 0 )); then
    echo "grw: no linked worktrees"
    return 0
  fi

  cd -- "$primary_wt" || return 1

  for wt in "${worktrees[@]}"; do
    printf 'Removing worktree: %s\n' "$wt"

    if ! git worktree remove --force -- "$wt"; then
      rc=1
    fi
  done

  return "$rc"
}

# Move to the primary default-branch worktree, remove linked worktrees, then
# update the default branch and delete merged local branches no longer in use.
gr() {
  local default_branch default_wt primary_status primary_wt

  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "gr: not inside a Git worktree" >&2
    return 1
  }

  primary_wt="$(_windows_setup_primary_worktree)" || return 1
  cd -- "$primary_wt" || return 1

  default_branch="$(_windows_setup_default_branch)" || return 1

  default_wt="$(git for-each-ref \
    --format='%(worktreepath)' \
    "refs/heads/$default_branch"
  )"

  if [[ -n "$default_wt" && ! "$default_wt" -ef "$primary_wt" ]]; then
    primary_status="$(git status --porcelain)" || return 1
    if [[ -n "$primary_status" ]]; then
      echo "gr: primary worktree has changes; cannot safely relocate '$default_branch'" >&2
      return 1
    fi

    git -C "$default_wt" switch --detach || return 1
  fi

  git switch -- "$default_branch" || return 1

  grw && grb
}
