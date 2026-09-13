#!/usr/bin/env python3
"""Render CDC check configuration from MAS clock domain spec."""
import sys
import json

def render_cdc_config(mas_spec: dict) -> dict:
    """Generate CDC configuration from MAS spec."""
    cdc_config = {'clocks': [], 'domain_crossings': [], 'synchronizers': []}
    for clk in mas_spec.get('clocks', []):
        cdc_config['clocks'].append({
            'name': clk['name'], 'frequency_mhz': clk.get('frequency_mhz', 100),
            'duty_cycle': clk.get('duty_cycle', 50)})
    for domain in mas_spec.get('clock_domains', []):
        for crossing in domain.get('crossings', []):
            cdc_config['domain_crossings'].append({
                'signal': crossing['signal'], 'source_domain': crossing['from'],
                'dest_domain': crossing['to'], 'sync_type': crossing.get('sync_type', '2ff')})
    return cdc_config

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: render_cdc_py.py <mas_spec.json>", file=sys.stderr)
        sys.exit(1)
    with open(sys.argv[1], 'r') as f:
        print(json.dumps(render_cdc_config(json.load(f)), indent=2))
