#!/usr/bin/env sh

set -e

cd "$(dirname "$0")"

# Deploy current folder to Netlify Production in one command.
if command -v netlify >/dev/null 2>&1; then
  netlify deploy --prod --dir .
  exit 0
fi

if command -v npx >/dev/null 2>&1; then
  npx --yes netlify-cli deploy --prod --dir .
  exit 0
fi

cat <<'EOFMSG'
未检测到 netlify CLI，也没有 npx。
请先安装 Node.js（含 npx），或在当前终端运行：
  npm install -g netlify-cli
然后重试：sh deploy.sh
EOFMSG
exit 1
