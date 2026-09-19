#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../scripts/shell/git-helpers.sh
source "$repo_root/scripts/shell/git-helpers.sh"

tmp_root="$(mktemp -d)"
trap 'rm -rf -- "$tmp_root"' EXIT

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

assert_ref() {
  git -C "$1" show-ref --verify --quiet "$2" || fail "missing ref: $2"
}

assert_no_ref() {
  if git -C "$1" show-ref --verify --quiet "$2"; then
    fail "unexpected ref: $2"
  fi
}

new_repo() {
  local name="$1"
  local default_branch="${2:-main}"
  local remote="$tmp_root/$name-remote.git"
  local repo="$tmp_root/$name"

  git init --quiet --bare "$remote"
  git -C "$remote" symbolic-ref HEAD "refs/heads/$default_branch"
  git init --quiet --initial-branch="$default_branch" "$repo"
  git -C "$repo" config user.name Test
  git -C "$repo" config user.email test@example.com
  printf 'initial\n' >"$repo/file.txt"
  git -C "$repo" add file.txt
  git -C "$repo" commit --quiet -m initial
  git -C "$repo" remote add origin "$remote"
  git -C "$repo" push --quiet --set-upstream origin "$default_branch"
  git -C "$repo" remote set-head origin --auto >/dev/null
  printf '%s\n' "$repo"
}

push_remote_update() {
  local repo="$1"
  local name="$2"
  local updater="$tmp_root/$name-updater"
  local default_branch

  git clone --quiet "$(git -C "$repo" remote get-url origin)" "$updater"
  git -C "$updater" config user.name Test
  git -C "$updater" config user.email test@example.com
  default_branch="$(git -C "$updater" branch --show-current)"
  printf '%s\n' "$name" >>"$updater/file.txt"
  git -C "$updater" commit --quiet -am "$name"
  git -C "$updater" push --quiet origin "$default_branch"
}

test_grb_from_linked_worktree() {
  local repo invoke_wt used_wt before_branch
  repo="$(new_repo grb-linked)"
  invoke_wt="$tmp_root/grb invoke"
  used_wt="$tmp_root/grb used"

  git -C "$repo" branch merged-delete
  git -C "$repo" branch merged-used
  git -C "$repo" push --quiet origin merged-delete
  git -C "$repo" worktree add --quiet "$used_wt" merged-used
  git -C "$repo" worktree add --quiet -b feature-invoke "$invoke_wt"
  printf 'feature\n' >"$invoke_wt/feature.txt"
  git -C "$invoke_wt" add feature.txt
  git -C "$invoke_wt" commit --quiet -m feature
  git -C "$repo" branch unmerged-unused "$(git -C "$invoke_wt" rev-parse HEAD)"
  push_remote_update "$repo" grb-linked

  cd -- "$invoke_wt"
  before_branch="$(git branch --show-current)"
  grb

  [[ "$(git branch --show-current)" == "$before_branch" ]] || fail 'grb switched the invoking worktree'
  [[ "$(git -C "$repo" rev-parse main)" == "$(git -C "$repo" rev-parse origin/main)" ]] || fail 'grb did not update checked-out main'
  assert_no_ref "$repo" refs/heads/merged-delete
  assert_ref "$repo" refs/heads/merged-used
  assert_ref "$repo" refs/heads/feature-invoke
  assert_ref "$repo" refs/heads/unmerged-unused
  assert_ref "$repo" refs/remotes/origin/merged-delete
}

test_grb_updates_main_linked_worktree() {
  local repo main_wt before_branch
  repo="$(new_repo grb-main-linked)"
  git -C "$repo" switch --quiet -c primary-feature
  main_wt="$tmp_root/grb main linked"
  git -C "$repo" worktree add --quiet "$main_wt" main
  before_branch="$(git -C "$repo" branch --show-current)"
  push_remote_update "$repo" grb-main-linked

  cd -- "$repo"
  grb

  [[ "$(git branch --show-current)" == "$before_branch" ]] || fail 'grb switched the primary feature worktree'
  [[ "$(git -C "$main_wt" rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || fail 'grb did not update main in a linked worktree'
}

test_grb_without_main_worktree() {
  local repo before_branch
  repo="$(new_repo grb-no-main)"
  git -C "$repo" switch --quiet -c feature
  before_branch="$(git -C "$repo" branch --show-current)"
  push_remote_update "$repo" grb-no-main

  cd -- "$repo"
  grb

  [[ "$(git branch --show-current)" == "$before_branch" ]] || fail 'grb switched a feature primary worktree'
  [[ "$(git rev-parse main)" == "$(git rev-parse origin/main)" ]] || fail 'grb did not update an unchecked main ref'
}

test_grb_refuses_ahead_main() {
  local repo rc
  repo="$(new_repo grb-ahead)"
  git -C "$repo" branch merged-keep
  printf 'ahead\n' >>"$repo/file.txt"
  git -C "$repo" commit --quiet -am ahead

  cd -- "$repo"
  set +e
  grb >/dev/null 2>&1
  rc=$?
  set -e

  [[ $rc -ne 0 ]] || fail 'grb accepted an ahead main'
  assert_ref "$repo" refs/heads/merged-keep
}

test_grb_refuses_diverged_main() {
  local repo rc
  repo="$(new_repo grb-diverged)"
  git -C "$repo" branch merged-keep
  printf 'local\n' >>"$repo/file.txt"
  git -C "$repo" commit --quiet -am local
  push_remote_update "$repo" grb-diverged

  cd -- "$repo"
  set +e
  grb >/dev/null 2>&1
  rc=$?
  set -e

  [[ $rc -ne 0 ]] || fail 'grb accepted a diverged main'
  assert_ref "$repo" refs/heads/merged-keep
}

test_grb_continues_after_delete_failure() {
  local repo rc
  repo="$(new_repo grb-delete-failure)"
  command git -C "$repo" branch fail-one
  command git -C "$repo" branch z-delete-after

  cd -- "$repo"
  git() {
    if [[ "$*" == 'branch -D -- fail-one' ]]; then
      return 1
    fi
    command git "$@"
  }

  set +e
  grb >/dev/null 2>&1
  rc=$?
  set -e
  unset -f git

  [[ $rc -ne 0 ]] || fail 'grb ignored a branch deletion failure'
  assert_ref "$repo" refs/heads/fail-one
  assert_no_ref "$repo" refs/heads/z-delete-after
}

test_grw_removes_linked_worktrees() {
  local repo caller_wt detached_wt dirty_wt locked_wt rc
  repo="$(new_repo grw-remove)"
  caller_wt="$tmp_root/grw caller"
  detached_wt="$tmp_root/grw detached"
  dirty_wt="$tmp_root/grw dirty path"
  locked_wt="$tmp_root/grw locked"

  git -C "$repo" worktree add --quiet -b caller "$caller_wt"
  git -C "$repo" worktree add --quiet --detach "$detached_wt"
  git -C "$repo" worktree add --quiet -b dirty "$dirty_wt"
  printf 'dirty\n' >"$dirty_wt/untracked.txt"
  git -C "$repo" worktree add --quiet -b locked "$locked_wt"
  git -C "$repo" worktree lock --reason test "$locked_wt"

  cd -- "$caller_wt"
  set +e
  grw >/dev/null 2>&1
  rc=$?
  set -e

  [[ $rc -ne 0 ]] || fail 'grw ignored a locked worktree'
  [[ "$PWD" -ef "$repo" ]] || fail 'grw did not move to the primary worktree'
  [[ ! -e "$caller_wt" && ! -e "$detached_wt" && ! -e "$dirty_wt" ]] || fail 'grw left a removable linked worktree'
  [[ -d "$locked_wt" ]] || fail 'grw removed a locked worktree'
  assert_ref "$repo" refs/heads/caller
  assert_ref "$repo" refs/heads/dirty
  assert_ref "$repo" refs/heads/locked

  git -C "$repo" worktree unlock "$locked_wt"
  git -C "$repo" worktree remove --force "$locked_wt"
}

test_grw_refuses_non_main_primary() {
  local repo main_wt other_wt before rc
  repo="$(new_repo grw-refuse)"
  git -C "$repo" switch --quiet -c primary-feature
  main_wt="$tmp_root/grw refusal main"
  other_wt="$tmp_root/grw refusal other"
  git -C "$repo" worktree add --quiet "$main_wt" main
  git -C "$repo" worktree add --quiet -b other "$other_wt"
  before="$(git -C "$repo" worktree list --porcelain)"

  cd -- "$repo"
  set +e
  grw >/dev/null 2>&1
  rc=$?
  set -e

  [[ $rc -ne 0 ]] || fail 'grw accepted a non-main primary worktree'
  [[ "$(git worktree list --porcelain)" == "$before" ]] || fail 'grw changed worktrees before refusing cleanup'
}

test_grw_noop() {
  local repo output
  repo="$(new_repo grw-noop)"
  cd -- "$repo"
  output="$(grw)"
  [[ "$output" == 'grw: no linked worktrees' ]] || fail 'grw no-op output changed'
}

test_gr_combines_worktree_and_branch_cleanup() {
  local repo merged_wt unmerged_wt
  repo="$(new_repo gr-combined)"
  merged_wt="$tmp_root/gr merged"
  unmerged_wt="$tmp_root/gr unmerged"

  git -C "$repo" switch --quiet -c primary-feature
  git -C "$repo" worktree add --quiet -b merged-linked "$merged_wt" main
  git -C "$repo" worktree add --quiet -b unmerged-linked "$unmerged_wt" main
  printf 'unmerged\n' >"$unmerged_wt/unmerged.txt"
  git -C "$unmerged_wt" add unmerged.txt
  git -C "$unmerged_wt" commit --quiet -m unmerged
  push_remote_update "$repo" gr-combined

  cd -- "$merged_wt"
  gr

  [[ "$PWD" -ef "$repo" ]] || fail 'gr did not finish in the primary worktree'
  [[ "$(git branch --show-current)" == main ]] || fail 'gr did not switch the primary worktree to main'
  [[ ! -e "$merged_wt" && ! -e "$unmerged_wt" ]] || fail 'gr left a linked worktree'
  assert_no_ref "$repo" refs/heads/primary-feature
  assert_no_ref "$repo" refs/heads/merged-linked
  assert_ref "$repo" refs/heads/unmerged-linked
  [[ "$(git -C "$repo" rev-parse main)" == "$(git -C "$repo" rev-parse origin/main)" ]] || fail 'gr did not update checked-out main'
}

test_gr_relocates_default_branch_from_linked_worktree() {
  local repo default_wt unmerged_wt
  repo="$(new_repo gr-default-linked)"
  default_wt="$tmp_root/gr default linked"
  unmerged_wt="$tmp_root/gr default linked unmerged"

  git -C "$repo" switch --quiet -c primary-feature
  git -C "$repo" worktree add --quiet "$default_wt" main
  git -C "$repo" worktree add --quiet -b unmerged-linked "$unmerged_wt" main
  printf 'unmerged\n' >"$unmerged_wt/unmerged.txt"
  git -C "$unmerged_wt" add unmerged.txt
  git -C "$unmerged_wt" commit --quiet -m unmerged

  cd -- "$default_wt"
  gr

  [[ "$PWD" -ef "$repo" ]] || fail 'gr did not move from the default branch linked worktree to the primary worktree'
  [[ "$(git branch --show-current)" == main ]] || fail 'gr did not relocate main to the primary worktree'
  [[ ! -e "$default_wt" && ! -e "$unmerged_wt" ]] || fail 'gr left a linked worktree after relocating main'
  assert_no_ref "$repo" refs/heads/primary-feature
  assert_ref "$repo" refs/heads/unmerged-linked
}

test_gr_leaves_locked_default_worktree_detached() {
  local repo default_wt rc
  repo="$(new_repo gr-default-linked-locked)"
  default_wt="$tmp_root/gr default linked locked"

  git -C "$repo" switch --quiet -c primary-feature
  git -C "$repo" worktree add --quiet "$default_wt" main
  git -C "$repo" worktree lock --reason test "$default_wt"

  cd -- "$repo"
  set +e
  gr >/dev/null 2>&1
  rc=$?
  set -e

  [[ $rc -ne 0 ]] || fail 'gr ignored a locked default branch worktree'
  [[ "$(git branch --show-current)" == main ]] || fail 'gr did not relocate main before encountering a locked worktree'
  [[ -d "$default_wt" ]] || fail 'gr removed a locked default branch worktree'
  [[ -z "$(git -C "$default_wt" branch --show-current)" ]] || fail 'gr left main checked out in both worktrees'
  assert_ref "$repo" refs/heads/primary-feature

  git -C "$repo" worktree unlock "$default_wt"
  git -C "$repo" worktree remove --force "$default_wt"
}

test_gr_stops_before_cleanup_when_switch_fails() {
  local repo linked_wt grw_marker grb_marker rc
  repo="$(new_repo gr-switch-failure)"
  linked_wt="$tmp_root/gr switch failure linked"
  grw_marker="$tmp_root/grw-called-after-switch-failure"
  grb_marker="$tmp_root/grb-called-after-switch-failure"

  git -C "$repo" switch --quiet -c primary-feature
  printf 'feature\n' >"$repo/file.txt"
  git -C "$repo" commit --quiet -am feature
  printf 'dirty\n' >"$repo/file.txt"
  git -C "$repo" worktree add --quiet "$linked_wt" main

  cd -- "$linked_wt"
  set +e
  (
    grw() { touch "$grw_marker"; }
    grb() { touch "$grb_marker"; }
    gr >/dev/null 2>&1
  )
  rc=$?
  set -e

  [[ $rc -ne 0 ]] || fail 'gr ignored a default branch switch failure'
  [[ "$(git -C "$repo" branch --show-current)" == primary-feature ]] || fail 'gr changed the primary branch after a switch failure'
  [[ -d "$linked_wt" ]] || fail 'gr removed a linked worktree after a switch failure'
  [[ "$(git -C "$linked_wt" branch --show-current)" == main ]] || fail 'gr detached the default branch before rejecting a dirty primary worktree'
  [[ ! -e "$grw_marker" && ! -e "$grb_marker" ]] || fail 'gr started cleanup after a switch failure'
}

test_gr_stops_when_grw_fails() {
  local repo marker="$tmp_root/grb-called" rc

  repo="$(new_repo grw-failure)"
  cd -- "$repo"

  set +e
  (
    grw() { return 23; }
    grb() { touch "$marker"; }
    gr
  )
  rc=$?
  set -e

  [[ $rc -eq 23 ]] || fail 'gr did not return the grw failure status'
  [[ ! -e "$marker" ]] || fail 'gr ran grb after grw failed'
}

test_non_main_default_branch() {
  local repo linked_wt
  repo="$(new_repo non-main-default trunk)"
  git -C "$repo" branch merged-delete
  push_remote_update "$repo" non-main-default

  cd -- "$repo"
  grb

  [[ "$(git rev-parse trunk)" == "$(git rev-parse origin/trunk)" ]] || fail 'grb did not update the non-main default branch'
  assert_no_ref "$repo" refs/heads/merged-delete

  linked_wt="$tmp_root/non-main linked"
  git worktree add --quiet -b feature "$linked_wt"
  grw

  [[ ! -e "$linked_wt" ]] || fail 'grw did not preserve the non-main default primary worktree'
  assert_ref "$repo" refs/heads/feature
}

test_changed_remote_default_ignores_stale_origin_head() {
  local repo remote linked_wt before rc
  repo="$(new_repo changed-default)"
  remote="$(git -C "$repo" remote get-url origin)"
  git -C "$repo" branch trunk
  git -C "$repo" push --quiet origin trunk
  git -C "$remote" symbolic-ref HEAD refs/heads/trunk
  push_remote_update "$repo" changed-default

  [[ "$(git -C "$repo" symbolic-ref refs/remotes/origin/HEAD)" == refs/remotes/origin/main ]] || fail 'origin HEAD was not stale before the test'

  cd -- "$repo"
  before="$(git branch --show-current)"
  grb

  [[ "$(git branch --show-current)" == "$before" ]] || fail 'grb switched to a changed remote default branch'
  [[ "$(git rev-parse trunk)" == "$(git rev-parse origin/trunk)" ]] || fail 'grb trusted stale origin HEAD metadata'

  linked_wt="$tmp_root/changed default linked"
  git worktree add --quiet -b feature "$linked_wt"
  set +e
  grw >/dev/null 2>&1
  rc=$?
  set -e

  [[ $rc -ne 0 ]] || fail 'grw trusted stale origin HEAD metadata'
  [[ -d "$linked_wt" ]] || fail 'grw removed a worktree when primary was not the current default branch'
}

test_default_branch_with_narrow_fetch_refspec() {
  local repo remote
  repo="$(new_repo narrow-fetch)"
  remote="$(git -C "$repo" remote get-url origin)"
  git -C "$repo" branch trunk
  git -C "$repo" branch merged-delete trunk
  git -C "$repo" push --quiet origin trunk
  git -C "$remote" symbolic-ref HEAD refs/heads/trunk
  git -C "$repo" config --unset-all remote.origin.fetch
  git -C "$repo" config --add remote.origin.fetch '+refs/heads/main:refs/remotes/origin/main'
  git -C "$repo" update-ref -d refs/remotes/origin/trunk
  push_remote_update "$repo" narrow-fetch

  cd -- "$repo"
  grb

  assert_ref "$repo" refs/remotes/origin/trunk
  [[ "$(git rev-parse trunk)" == "$(git rev-parse origin/trunk)" ]] || fail 'grb did not update the default branch with a narrow fetch refspec'
  assert_no_ref "$repo" refs/heads/merged-delete
}

test_managed_env_sources_helpers() {
  local config_dir="$tmp_root/managed config"
  mkdir -p "$config_dir"
  cp "$repo_root/scripts/wsl/env.sh" "$config_dir/env.sh"
  cp "$repo_root/scripts/shell/git-helpers.sh" "$config_dir/git-helpers.sh"

  HOME="$tmp_root/home" PATH=/usr/bin:/bin bash --noprofile --norc -c '
    source "$1/env.sh"
    declare -F gr >/dev/null
    declare -F grb >/dev/null
    declare -F grw >/dev/null
  ' _ "$config_dir" || fail 'managed env did not source Git helpers'
}

test_grb_from_linked_worktree
test_grb_updates_main_linked_worktree
test_grb_without_main_worktree
test_grb_refuses_ahead_main
test_grb_refuses_diverged_main
test_grb_continues_after_delete_failure
test_grw_removes_linked_worktrees
test_grw_refuses_non_main_primary
test_grw_noop
test_gr_combines_worktree_and_branch_cleanup
test_gr_relocates_default_branch_from_linked_worktree
test_gr_leaves_locked_default_worktree_detached
test_gr_stops_before_cleanup_when_switch_fails
test_gr_stops_when_grw_fails
test_non_main_default_branch
test_changed_remote_default_ignores_stale_origin_head
test_default_branch_with_narrow_fetch_refspec
test_managed_env_sources_helpers

printf '[PASS] git helper integration tests\n'
