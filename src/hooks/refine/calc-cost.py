#!/usr/bin/env python3
"""Refine Loop - 비용 계산 스크립트
transcript 파싱 + 모델별 가격 계산 로직.

사용법: python3 calc-cost.py <transcript_path>
출력: JSON {"total_cost_usd": 0.42, "token_summary": {...}}
"""
import json
import sys
import os

PRICING = {
    'claude-opus-4-6':   {'input': 15.0, 'output': 75.0, 'cache_read': 1.50, 'cache_create': 18.75},
    'claude-sonnet-4-5': {'input': 3.0,  'output': 15.0, 'cache_read': 0.30, 'cache_create': 3.75},
    'claude-haiku-4-5':  {'input': 0.80, 'output': 4.0,  'cache_read': 0.08, 'cache_create': 1.0},
}


def get_pricing(model_name):
    for key, price in PRICING.items():
        if key in model_name:
            return price
    return PRICING['claude-sonnet-4-5']


def calculate_cost(transcript_path):
    last_by_id = {}
    if not transcript_path or not os.path.isfile(transcript_path):
        return {"total_cost_usd": 0.0, "token_summary": {}}

    with open(transcript_path) as f:
        for line in f:
            try:
                entry = json.loads(line.strip())
            except Exception:
                continue
            if entry.get('type') != 'assistant':
                continue
            msg = entry.get('message', {})
            usage = msg.get('usage')
            model = msg.get('model', 'unknown')
            mid = msg.get('id', '')
            if not usage:
                continue
            last_by_id[mid or id(line)] = {'model': model, 'usage': usage}

    usage_by_model = {}
    for rec in last_by_id.values():
        model = rec['model']
        usage = rec['usage']
        if model not in usage_by_model:
            usage_by_model[model] = {'input': 0, 'output': 0, 'cacheRead': 0, 'cacheCreation': 0}
        usage_by_model[model]['input'] += usage.get('input_tokens', 0)
        usage_by_model[model]['output'] += usage.get('output_tokens', 0)
        usage_by_model[model]['cacheRead'] += usage.get('cache_read_input_tokens', 0)
        usage_by_model[model]['cacheCreation'] += usage.get('cache_creation_input_tokens', 0)

    total_cost = 0.0
    for model, tokens in usage_by_model.items():
        p = get_pricing(model)
        total_cost += tokens['input'] * p['input'] / 1_000_000
        total_cost += tokens['output'] * p['output'] / 1_000_000
        total_cost += tokens['cacheRead'] * p['cache_read'] / 1_000_000
        total_cost += tokens['cacheCreation'] * p['cache_create'] / 1_000_000

    return {"total_cost_usd": round(total_cost, 6), "token_summary": usage_by_model}


if __name__ == '__main__':
    path = sys.argv[1] if len(sys.argv) > 1 else ''
    result = calculate_cost(path)
    print(json.dumps(result))
