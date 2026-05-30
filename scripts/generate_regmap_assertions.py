#!/usr/bin/env python3
"""
Generate SystemVerilog Assertions for register map from regmap.md register definitions.

Inputs:
  - spec/MAS/<module>/regmap.md (standalone register definition file)

Assertion types:
  - Reset value: register resets to specified value
  - Read-only protection: write to RO register has no effect
  - Write-1-to-clear (W1C): write 1 clears, write 0 has no effect
  - Reserved bits: write to reserved bits is ignored
  - Address range: access within valid address range

Usage:
    uv run scripts/generate_regmap_assertions.py --regmap <regmap_file> --output <output_file>
    uv run scripts/generate_regmap_assertions.py --regmap spec/MAS/M01_DataflowController/regmap.md --output rtl/designs/M01_DataflowController/rtl_src/M01_DataflowController_regmap_assertions.sv
"""

import argparse
import re
import sys
from pathlib import Path
from datetime import datetime


def parse_register_table(regmap_content: str) -> list[dict]:
    """Parse register definition table from regmap.md §1."""
    registers = []

    reg_section = re.search(
        r'## 1\.\s*(?:寄存器列表|Register List)(.*?)(?=## \d+\.|$)',
        regmap_content,
        re.DOTALL
    )

    if not reg_section:
        return registers

    section_text = reg_section.group(1)

    table_pattern = r'\|\s*(\w+)\s*\|\s*(0x[0-9A-Fa-f_]+)\s*\|\s*(\d+)\s*\|\s*(\w+)\s*\|\s*(0x[0-9A-Fa-f_]+)\s*\|\s*([\w-]+)\s*\|\s*(.*?)\s*\|'

    for match in re.finditer(table_pattern, section_text):
        registers.append({
            'name': match.group(1),
            'offset': int(match.group(2).replace('_', ''), 16),
            'width': int(match.group(3)),
            'access': match.group(4).upper(),
            'reset': int(match.group(5).replace('_', ''), 16),
            'req_id': match.group(6),
            'description': match.group(7).strip()
        })

    return registers


def parse_bit_fields(regmap_content: str, reg_name: str) -> list[dict]:
    """Parse bit field definitions for a specific register.

    Expected format in regmap.md §2.x:
    ### 2.1 CTRL (0x00) - 控制寄存器
    #### 位域定义
    | 位 | 名称 | 访问 | 复位值 | 功能 |
    """
    bit_fields = []

    # Match §2.x subsection: ### 2.x REG_NAME (0xNN)
    reg_pattern = rf'###\s*2\.\d+\s*{re.escape(reg_name)}\s*\(0x[0-9A-Fa-f]+\)(.*?)(?=###\s*2\.\d+|\Z)'
    reg_match = re.search(reg_pattern, regmap_content, re.DOTALL)

    if not reg_match:
        return bit_fields

    section_text = reg_match.group(1)

    field_pattern = r'\|\s*\[(\d+)(?::(\d+))?\]\s*\|\s*(\w+)\s*\|\s*([\w-]+)\s*\|\s*(0x[0-9A-Fa-f_]+|\d+)\s*\|\s*(.*?)\s*\|'

    for match in re.finditer(field_pattern, section_text):
        high_bit = int(match.group(1))
        low_bit = int(match.group(2)) if match.group(2) else high_bit
        width = high_bit - low_bit + 1

        bit_fields.append({
            'name': match.group(3),
            'bit_offset': low_bit,
            'bit_width': width,
            'access': match.group(4).upper(),
            'reset': int(match.group(5).replace('_', ''), 0),
            'description': match.group(6).strip()
        })

    return bit_fields


def compute_max_offset(registers: list[dict]) -> int:
    """Compute the maximum address offset (for address range assertion)."""
    if not registers:
        return 0
    return max(r['offset'] for r in registers)


def generate_assertions(design_name: str, regmap_path: str, registers: list[dict], regmap_content: str) -> str:
    """Generate SystemVerilog assertion file."""

    lines = []

    # File header (Spec Header format compatible with compute_spec_hash.py)
    lines.append(f"//==============================================================================")
    lines.append(f"// Module: {design_name}_regmap_assertions")
    lines.append(f"//")
    lines.append(f"// SPEC HEADER")
    lines.append(f"// ─────────────────────────────────────────────────────────────────────────────")
    lines.append(f"// Source:       {regmap_path}")
    lines.append(f"// Version:      1.0")
    lines.append(f"// Status:       AUTO-GENERATED")
    lines.append(f"// Spec Hash:    {{{{ sha256:xxxxxxxx }}}}  ← Run: uv run scripts/compute_spec_hash.py {regmap_path} --inject <this_file>")
    lines.append(f"// Generated:    {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append(f"//")
    lines.append(f"// Purpose:")
    lines.append(f"//   SVA assertions for {design_name} register map (reset, RO, W1C, reserved, addr range)")
    lines.append(f"//")
    lines.append(f"// Traceability:")
    lines.append(f"//   REGMAP: {regmap_path}")
    lines.append(f"//==============================================================================")
    lines.append(f"")
    lines.append(f"module {design_name}_regmap_assertions (")
    lines.append(f"    input  logic        clk,")
    lines.append(f"    input  logic        rst_n,")
    lines.append(f"    input  logic [31:0] addr,")
    lines.append(f"    input  logic        sel,")
    lines.append(f"    input  logic        enable,")
    lines.append(f"    input  logic        write,")
    lines.append(f"    input  logic [31:0] wdata,")
    lines.append(f"    input  logic [31:0] rdata,")
    for i, reg in enumerate(registers):
        comma = "," if i < len(registers) - 1 else ""
        lines.append(f"    input  logic [{reg['width']-1}:0] {reg['name']}_reg{comma}")
    lines.append(f");")
    lines.append(f"")

    # Generate assertions for each register
    for reg in registers:
        reg_name = reg['name']
        reg_upper = reg_name.upper()
        req_id = reg['req_id']
        offset = reg['offset']
        reset_val = reg['reset']
        access = reg['access']

        lines.append(f"    // ══ {reg_name} (0x{offset:02X}) ════════════════════════════════════════")
        lines.append(f"")

        # 1. Reset value assertion
        lines.append(f"    // @verifies {req_id}")
        lines.append(f"    // @spec_ref MAS/{design_name}/regmap.md §1")
        lines.append(f"    // @constraint {reg_name} 复位值必须为 0x{reset_val:X}")
        lines.append(f"    property p_{reg_name.lower()}_reset;")
        lines.append(f"        @(posedge clk)")
        lines.append(f"        $rose(rst_n) |-> ({reg_name}_reg == {reg['width']}'h{reset_val:0{reg['width']//4}X});")
        lines.append(f"    endproperty")
        lines.append(f"    assert property (p_{reg_name.lower()}_reset)")
        lines.append(f"        else $error(\"[REGMAP §1] {reg_name} reset value violation: %h\", {reg_name}_reg);")
        lines.append(f"")

        # 2. Read-only protection (for RO registers)
        if access == 'RO':
            lines.append(f"    // @verifies {req_id}")
            lines.append(f"    // @spec_ref MAS/{design_name}/regmap.md §1")
            lines.append(f"    // @constraint {reg_name} 是只读寄存器，写操作无效")
            lines.append(f"    property p_{reg_name.lower()}_readonly;")
            lines.append(f"        @(posedge clk) disable iff (!rst_n)")
            lines.append(f"        (sel && enable && write && addr == 32'h{offset:08X})")
            lines.append(f"        |-> ({reg_name}_reg == $past({reg_name}_reg));")
            lines.append(f"    endproperty")
            lines.append(f"    assert property (p_{reg_name.lower()}_readonly)")
            lines.append(f"        else $error(\"[REGMAP §1] {reg_name} write attempted (read-only)\");")
            lines.append(f"")

        # 3. Parse bit fields and generate field-level assertions
        bit_fields = parse_bit_fields(regmap_content, reg_name)

        for field in bit_fields:
            field_name = field['name']
            field_access = field['access']
            bit_offset = field['bit_offset']
            bit_width = field['bit_width']
            field_reset = field['reset']

            if bit_width == 1:
                bit_range = f"[{bit_offset}]"
            else:
                bit_range = f"[{bit_offset+bit_width-1}:{bit_offset}]"

            # W1C (Write-1-to-Clear) fields
            if 'W1C' in field_access or 'w1c' in field_name.lower():
                lines.append(f"    // @verifies {req_id}")
                lines.append(f"    // @spec_ref MAS/{design_name}/regmap.md §2")
                lines.append(f"    // @constraint {reg_name}.{field_name} 写 1 清零，写 0 无效")
                lines.append(f"    property p_{reg_name.lower()}_{field_name.lower()}_w1c;")
                lines.append(f"        @(posedge clk) disable iff (!rst_n)")
                lines.append(f"        (sel && enable && write && addr == 32'h{offset:08X})")
                lines.append(f"        |-> (")
                lines.append(f"            (wdata{bit_range} == 1'b1) |-> ({reg_name}_reg{bit_range} == 1'b0)")
                lines.append(f"            &&")
                lines.append(f"            (wdata{bit_range} == 1'b0) |-> ({reg_name}_reg{bit_range} == $past({reg_name}_reg{bit_range}))")
                lines.append(f"        );")
                lines.append(f"    endproperty")
                lines.append(f"    assert property (p_{reg_name.lower()}_{field_name.lower()}_w1c);")
                lines.append(f"")

            # Reserved bits (write ignored)
            if 'RESERVED' in field_name.upper() or 'RSVD' in field_name.upper():
                # Use bit offset in property name to avoid collisions when multiple RESERVED fields exist
                prop_suffix = f"{field_name.lower()}_{bit_offset+bit_width-1}_{bit_offset}" if bit_width > 1 else f"{field_name.lower()}_{bit_offset}"
                lines.append(f"    // @verifies {req_id}")
                lines.append(f"    // @spec_ref MAS/{design_name}/regmap.md §2")
                lines.append(f"    // @constraint {reg_name}.{field_name}{bit_range} 保留位，写入被忽略")
                lines.append(f"    property p_{reg_name.lower()}_{prop_suffix}_reserved;")
                lines.append(f"        @(posedge clk) disable iff (!rst_n)")
                lines.append(f"        (sel && enable && write && addr == 32'h{offset:08X})")
                lines.append(f"        |-> ({reg_name}_reg{bit_range} == $past({reg_name}_reg{bit_range}));")
                lines.append(f"    endproperty")
                lines.append(f"    assert property (p_{reg_name.lower()}_{prop_suffix}_reserved);")
                lines.append(f"")

    # 4. Address range assertion
    max_offset = compute_max_offset(registers)
    lines.append(f"    // ══ Address Range ════════════════════════════════════════════════════")
    lines.append(f"    //")
    lines.append(f"    // @verifies REQ-SYS-ADDR")
    lines.append(f"    // @spec_ref ARCH/memory_map.md §2")
    lines.append(f"    // @constraint 访问地址必须在有效范围内 (0x00 ~ 0x{max_offset:02X})")
    lines.append(f"    property p_addr_range;")
    lines.append(f"        @(posedge clk) disable iff (!rst_n)")
    lines.append(f"        (sel && enable)")
    lines.append(f"        |-> (addr <= 32'h{max_offset:08X});")
    lines.append(f"    endproperty")
    lines.append(f"    assert property (p_addr_range)")
    lines.append(f"        else $error(\"[SPEC §2] Address out of range: 0x%h\", addr);")
    lines.append(f"")

    lines.append(f"endmodule")
    lines.append("")

    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(
        description='Generate SystemVerilog Assertions for register map'
    )
    parser.add_argument('--regmap', required=True, help='Path to regmap.md file')
    parser.add_argument('--output', required=True, help='Output .sv file')

    args = parser.parse_args()

    # Read regmap file
    regmap_path = Path(args.regmap)
    if not regmap_path.exists():
        print(f"Error: regmap file not found: {args.regmap}", file=sys.stderr)
        return 1

    regmap_content = regmap_path.read_text()

    # Parse registers
    registers = parse_register_table(regmap_content)

    if not registers:
        print("Warning: No register definitions found in regmap.md", file=sys.stderr)
        return 0

    # Extract design name from regmap path's parent directory
    design_name = regmap_path.parent.name

    # Generate assertions
    sv_content = generate_assertions(design_name, str(regmap_path), registers, regmap_content)

    # Write output
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(sv_content)

    print(f"✓ Generated: {output_path}")
    print(f"  Registers: {len(registers)}")
    print(f"  Next: uv run scripts/compute_spec_hash.py {regmap_path} --inject {output_path}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
