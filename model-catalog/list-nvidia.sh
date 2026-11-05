#!/bin/sh
# NVIDIA Nemotron & NIM model catalog.
# NIM endpoint is OpenAI-compatible: https://integrate.api.nvidia.com/v1
# Live catalogue listing needs an NVIDIA_API_KEY (nvapi-...); set it in .env.
KEY="${NVIDIA_API_KEY:-${NVIDIA_API_KEY_ENV:-}}"
if [ -n "$KEY" ]; then
  curl -fsSL --max-time 15 -H "Authorization: Bearer $KEY" \
    https://integrate.api.nvidia.com/v1/models \
  | python3 -c 'import json,sys; [print("nvidia/"+m["id"]) for m in json.load(sys.stdin)["data"]]'
else
  printf '%s\n' \
    '# NVIDIA Nemotron & NIM models (static catalog; export NVIDIA_API_KEY in .env for live listing)' \
    'nvidia/nvidia/nemotron-compact-v1' \
    'nvidia/nvidia/nemotron-nano-15m-a2b' \
    'nvidia/nvidia/nemotron-nano-9b-v2' \
    'nvidia/nvidia/nemotron-h-acp-agent' \
    'nvidia/nvidia/nemotron-3-nano-30b-a3b' \
    'nvidia/nvidia/nemotron-3-super-120b-a12b' \
    'nvidia/nvidia/llama-3.1-nemotron-70b-instruct' \
    'nvidia/nvidia/llama-3.3-nemotron-super-49b-v1' \
    'nvidia/meta/llama-3.3-70b-instruct' \
    'nvidia/deepseek-ai/deepseek-r1' \
    'nvidia/mistralai/ministral-14b'
fi
