#!/bin/sh
# Curated free-model catalog: OpenCode Zen free tier + NVIDIA free-tier
# Nemotron models exposed through OpenCode. Edit to taste; keep secrets in .env.
printf '%s\n' \
  '# Free models (100% no-cost tier)' \
  'opencode/ilm-model-lite            # OpenCode Zen, free' \
  'opencode/big-pickle                # OpenCode Zen, free' \
  'opencode/ling-mini                 # OpenCode Zen, free' \
  'opencode/turbo                     # OpenCode Zen, free' \
  'opencode/north-mini-code           # OpenCode Zen, free' \
  'opencode/yuanban-1.5               # OpenCode Zen, free' \
  'opencode/minimax-m2                # OpenCode Zen, free' \
  'opencode/grok-code                 # OpenCode Zen, free' \
  '' \
  '# NVIDIA free-tier (requires NVIDIA_API_KEY / nvapi- key in .env or opencode auth login)' \
  'nvidia/nvidia/nemotron-compact-v1' \
  'nvidia/nvidia/nemotron-nano-15m-a2b' \
  'nvidia/nvidia/nemotron-nano-9b-v2' \
  'nvidia/nvidia/nemotron-h-acp-agent' \
  'nvidia/nvidia/llama-3.1-nemotron-70b-instruct' \
  '' \
  '# Kilo Code free routers (via kilo provider gateway)' \
  'kilo/kilo-auto/free' \
  'kilo/qwen3-coder-480b-a35b-instruct:free' \
  'kilo/deepseek-v3.2:free' \
  'kilo/kimi-k2-0905-preview:free' \
  'kilo/glm-4.6:free' \
  'kilo/zerolayer'
