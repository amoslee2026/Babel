#!/usr/bin/env python3
"""
KLayout GDS Export from DEF/LEF using Ruby script
NPU_top ASAP7 PD flow
"""

import subprocess
import os
import sys
import json
from datetime import datetime

# Configuration
DESIGN_NAME = "NPU_top"
DEF_FILE = "/home/lxx/wrk/Babel/designs/NPU_top/pd/placed_20260521_164027.def"
LEF_FILE = "/home/lxx/wrk/libs/asap7_reference_design/lef/asap7sc7p5t_28_L_1x_220121a.lef"
OUTPUT_DIR = "/home/lxx/wrk/Babel/designs/NPU_top/gdsii"
EDA_ENV = "~/wrk/eda_opensources/eda_env.sh"
STAMP = datetime.now().strftime("%Y%m%d_%H%M%S")
GDS_PATH = os.path.join(OUTPUT_DIR, f"NPU_top_{STAMP}.gds")
LOG_PATH = os.path.join(OUTPUT_DIR, f"export_{STAMP}.log")

# KLayout Ruby script
KAYOUT_RB = f"""
# KLayout DEF-to-GDS Export Script
# Generated: {datetime.now().isoformat()}

# Load LEF file
begin
  lef = RBA::LEFReader::new
  lef.read("{LEF_FILE}")
rescue => e
  puts "LEF read error: #{e.message}"
  exit 1
end

puts "LEF loaded successfully"

# Load DEF file
begin
  def_reader = RBA::DEFReader::new
  layout = RBA::Layout::new
  def_reader.read("{DEF_FILE}", layout)
rescue => e
  puts "DEF read error: #{e.message}"
  exit 1
end

puts "DEF loaded successfully"

# Set DBU (database units)
layout.dbu = 0.001  # 1nm precision

# Get top cell
top_cell = layout.top_cell
puts "Top cell: #{top_cell ? top_cell.name : 'none'}"
puts "Cell count: #{layout.cells}"
puts "Layer count: #{layout.layers}"

# Export to GDS
begin
  layout.write("{GDS_PATH}")
  puts "GDS written to: {GDS_PATH}"
rescue => e
  puts "GDS write error: #{e.message}"
  exit 1
end

puts "Export complete"
"""

def run_klayout_export():
    """Run KLayout with Ruby script."""
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # Write Ruby script
    rb_path = os.path.join(OUTPUT_DIR, f"export_{STAMP}.rb")
    with open(rb_path, 'w') as f:
        f.write(KAYOUT_RB)

    # Run KLayout with xvfb
    cmd = f"source {EDA_ENV} && xvfb-run -a klayout -z -r {rb_path} > {LOG_PATH} 2>&1"
    print(f"Running: {cmd}")
    result = subprocess.run(cmd, shell=True)

    # Check if GDS was created
    if os.path.exists(GDS_PATH):
        size = os.path.getsize(GDS_PATH)
        print(f"GDS created: {GDS_PATH} ({size} bytes)")
        return {
            'status': 'success',
            'gds_path': GDS_PATH,
            'rb_path': rb_path,
            'size': size,
            'log_path': LOG_PATH,
            'valid': True,
            'error': None
        }
    else:
        if os.path.exists(LOG_PATH):
            with open(LOG_PATH) as f:
                log_content = f.read()
        else:
            log_content = "No log file"
        print(f"GDS export failed")
        print(f"Log: {log_content}")
        return {
            'status': 'error',
            'log_path': LOG_PATH,
            'error': log_content,
            'valid': False
        }

def verify_gds(gds_path):
    """Verify GDS file with KLayout."""
    cmd = f"source {EDA_ENV} && xvfb-run -a klayout -z -c {gds_path}"
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)

    if result.returncode == 0:
        print(f"GDS verified: {gds_path}")
        return True
    else:
        print(f"GDS verification issue: {result.stderr}")
        return False

def main():
    """Main execution."""
    print(f"=== KLayout DEF-to-GDS Export for {DESIGN_NAME} ===")
    print(f"DEF: {DEF_FILE}")
    print(f"LEF: {LEF_FILE}")
    print(f"Output: {OUTPUT_DIR}")
    print(f"Stamp: {STAMP}")

    result = run_klayout_export()

    if result['valid']:
        verified = verify_gds(result['gds_path'])
        result['verified'] = verified

        # Save result
        result_path = os.path.join(OUTPUT_DIR, f"export_result_{STAMP}.json")
        with open(result_path, 'w') as f:
            json.dump(result, f, indent=2)
        print(f"Result: {result_path}")

    print(f"\n=== Export complete ===")
    return result

if __name__ == "__main__":
    main()