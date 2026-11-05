#!/bin/sh
# Kilo Code models & free routers (static catalog of the kilo provider gateway).
printf '%s\n' \
  '# Kilo models & free routers' \
  'kilo/kilo-auto            # smart router (paid pool)' \
  'kilo/kilo-auto/free       # smart router (free pool)' \
  'kilo/zerolayer            # auto-routing across free providers' \
  'kilo/qwen3-coder-480b-a35b-instruct:free' \
  'kilo/deepseek-v3.2:free' \
  'kilo/kimi-k2-0905-preview:free' \
  'kilo/glm-4.6:free' \
  'kilo/claude-sonnet-4.5' \
  'kilo/gpt-5.1-codex-max' \
  'kilo/gemini-3-pro-preview'
