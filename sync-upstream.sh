#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later

# 同步上游更新到当前维护分支（私有 Intel x86 支持分支专用）。
#
# 背景：官方 Vorssaint 保持 Apple Silicon only，本分支携带私有 Intel 改动，
# 因此采用 "fork + 定期 merge" 模式维护：上游更新一律用 merge（而非 rebase），
# 只在真正重叠的区域产生冲突，历史可回溯。
#
# 用法：
#   ./sync-upstream.sh               # fetch + merge + 跑测试
#   ./sync-upstream.sh --install     # 合并后重建并安装 Developer app
#   ./sync-upstream.sh --push        # 合并后推送到远端
#   ./sync-upstream.sh --no-test     # 跳过回归测试
#   ./sync-upstream.sh --dry-run     # 只检查上游是否有更新，不做任何修改
set -euo pipefail
cd "$(dirname "$0")"

# Flags
TEST=1
INSTALL=0
PUSH=0
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --no-test)  TEST=0 ;;
        --install)  INSTALL=1 ;;
        --push)     PUSH=1 ;;
        --dry-run)  DRY_RUN=1 ;;
        -h|--help)
            sed -n 's/^# \{0,1\}//p' "$0" | sed -n '/^用法/,$p'
            exit 0
            ;;
        *) echo "未知参数: $arg（用 --help 查看用法）" >&2; exit 1 ;;
    esac
done

# ── 前置检查 ──────────────────────────────────────────────────────────
if ! git remote | grep -qx upstream; then
    echo "✗ 没有 upstream remote。先添加官方仓库：" >&2
    echo "  git remote add upstream https://github.com/vorssaint/vorssaint-utils.git" >&2
    exit 1
fi

if [[ "$(git branch --show-current)" == "main" ]]; then
    echo "⚠ 当前在 main 分支。维护分支通常是 tweak/… 或专门的同步分支。" >&2
    echo "  继续前请确认这不是官方仓库的 main。" >&2
fi

if ! git diff --quiet HEAD; then
    echo "✗ 工作树有未提交的改动，先提交或 stash 再同步：" >&2
    git status --short >&2
    exit 1
fi

# ── 拉取并检查更新 ────────────────────────────────────────────────────
echo "▸ 拉取 upstream…"
git fetch upstream

NEW_COMMITS=$(git rev-list --count HEAD..upstream/main)
if (( NEW_COMMITS == 0 )); then
    if (( ! INSTALL && ! PUSH )); then
        echo "✓ 已是最新，无需同步（upstream/main 无新提交）"
        exit 0
    fi
    echo "▸ upstream/main 无新提交，跳过合并，继续后续步骤…"
else
    echo "▸ upstream/main 有 $NEW_COMMITS 个新提交："
    git log --oneline HEAD..upstream/main

    if (( DRY_RUN )); then
        echo "（--dry-run，未做任何修改）"
        exit 0
    fi

    # ── 合并上游 ──────────────────────────────────────────────────────
    echo "▸ 合并 upstream/main…"
    if ! git merge upstream/main --no-edit; then
        echo "✗ 合并产生冲突，请手动解决：" >&2
        echo >&2
        git diff --name-only --diff-filter=U | sed 's/^/    /' >&2
        echo >&2
        echo "  解决提示（保留双方改动）：" >&2
        echo "    - 上游删了你没改的区域      → 接受上游" >&2
        echo "    - 上游改了你没改的区域      → 接受上游" >&2
        echo "    - 双方改了同一行            → 保留你的 Intel 改动 + 并入上游新逻辑" >&2
        echo "    - build.sh 的 TARGET 分支   → 你的私有区域，逐行核对" >&2
        echo >&2
        echo "  解决完成后：" >&2
        echo "    git add <文件>" >&2
        echo "    git commit" >&2
        echo "    ./sync-upstream.sh --test --install --push   # 补跑后续步骤" >&2
        exit 1
    fi
    echo "✓ 合并完成"
fi

# ── 回归测试 ──────────────────────────────────────────────────────────
if (( TEST )); then
    echo "▸ 跑回归测试（./build.sh --test）…"
    if ! ./build.sh --test; then
        echo "✗ 测试失败！上游改动与本分支不兼容，请排查后再推送。" >&2
        exit 1
    fi
    echo "✓ 测试通过"
fi

# ── 重建 Developer app（可选）────────────────────────────────────────
if (( INSTALL )); then
    echo "▸ 重建并安装 Developer app（./build.sh --dev --install）…"
    ./build.sh --dev --install
    echo "✓ app 已更新：/Applications/Vorssaint (Developer).app"
fi

# ── 推送（可选）───────────────────────────────────────────────────────
if (( PUSH )); then
    echo "▸ 推送 $(git branch --show-current)…"
    git push -u origin "$(git branch --show-current)"
    echo "✓ 已推送"
fi

echo "✓ 同步完成"
