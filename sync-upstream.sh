#!/bin/sh
# sync-upstream.sh — 同步上游 deepseek-ai/deepseek-harness 到本地 stack。
#
# 栈结构（2026-08-30）：master(镜像上游) → fix/llm-deepseek-tool-name-empty-delta → dev
# 用法：在任意目录执行 ./sync-upstream.sh（或 sh sync-upstream.sh）
# 分支增减时修改下方 STACK 列表即可。

set -e

MAIN_WT="/d/ai/deepseek-harness"
DEV_WT="/d/ai/deepseek-harness-dev"
STACK="fix/llm-deepseek-tool-name-empty-delta dev"

# 前置检查：两个 worktree 必须干净，否则 rebase 中途会被脏状态打断
for wt in "$MAIN_WT" "$DEV_WT"; do
  if [ -n "$(git -C "$wt" status --porcelain)" ]; then
    echo "✗ $wt 有未提交修改，先提交或 stash 再同步：" >&2
    git -C "$wt" status --short >&2
    exit 1
  fi
done

# 1. master 快进到上游（推送失败不阻断——fork 的 master 只是镜像展示，
#    若报 workflow scope 错误：GitHub PAT 需勾选 workflow 权限，或改用 SSH remote）
cd "$MAIN_WT"
git fetch upstream
git checkout master
git merge --ff-only upstream/master
git push origin master || echo "⚠ master 推送失败（不阻断同步，fork 上 master 落后无碍开发）"

# 2. 按栈序 rebase（下层先搬，上层跟着搬）
prev=master
cd "$DEV_WT"
for branch in $STACK; do
  echo "== rebase $branch onto $prev =="
  git checkout "$branch"
  git rebase "$prev"
  prev="$branch"
done

# 3. 哨兵测试：确认 fix 语义在新代码上仍成立
pnpm exec vitest run packages/llm/llm-deepseek/tests/translate.spec.ts

# 4. 回到日常开发分支并推送
git checkout dev
git push origin fix/llm-deepseek-tool-name-empty-delta --force-with-lease
git push origin dev --force-with-lease

echo "✓ 同步完成，当前在 dev 分支"
