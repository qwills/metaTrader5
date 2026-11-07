#!/usr/bin/env bash
# Run once in your own Terminal to import the workspace into its root repository.
set -euo pipefail
cd -- "$(dirname -- "$0")/../.."

git rev-parse --git-dir >/dev/null
if git rev-parse --verify HEAD >/dev/null 2>&1; then
    echo 'This repository already has a commit; no changes made.' >&2
    exit 1
fi

commit_name=$(git config user.name || true)
commit_email=$(git config user.email || true)
# Reuse an existing local identity only when its name matches the root config.
if [[ -n "$commit_name" && -z "$commit_email" ]]; then
    for project in exeAutoSL exeMyCalc; do
        if [[ -d "Experts/$project/.git" ]]; then
            previous_name=$(git -C "Experts/$project" log -1 --format=%an)
            if [[ "$previous_name" == "$commit_name" ]]; then
                commit_email=$(git -C "Experts/$project" log -1 --format=%ae)
                [[ -n "$commit_email" ]] && break
            fi
        fi
    done
fi
if [[ -z "$commit_name" || -z "$commit_email" ]]; then
    echo 'Set git config user.name and git config user.email, then run this script again.' >&2
    exit 1
fi

# Preflight both moves. Preserve histories and uncommitted work; do not delete them.
for project in exeAutoSL exeMyCalc; do
    if [[ -f "Experts/$project/.git" ]]; then
        echo "Experts/$project uses a linked Git worktree; import it manually." >&2
        exit 1
    fi
    if [[ -d "Experts/$project/.git" && -e "archive/git-history/$project.git" ]]; then
        echo "archive/git-history/$project.git already exists; no history overwritten." >&2
        exit 1
    fi
done

git config --local user.name "$commit_name"
git config --local user.email "$commit_email"
mkdir -p archive/git-history
for project in exeAutoSL exeMyCalc; do
    if [[ -d "Experts/$project/.git" ]]; then
        mv -- "Experts/$project/.git" "archive/git-history/$project.git"
    fi
done

git add --all
if git ls-files --stage | awk '$1 == "160000" { found=1 } END { exit !found }'; then
    echo 'An embedded repository remains. Inspect git status before committing.' >&2
    exit 1
fi
git diff --cached --stat
git commit -m "Initial commit: MetaTrader 5 workspace and myFibo 2.10"
git status --short
