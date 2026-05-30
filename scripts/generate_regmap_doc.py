#!/usr/bin/env python3
"""
Generate register map documentation from regmap.md register definitions.

Inputs:
  - spec/MAS/<module>/regmap.md (standalone register definition file)

Outputs:
  - Markdown document (doc/regmap/<design>.md)
  - CMSIS-SVD file (doc/regmap/<design>.svd)

Usage:
    uv run scripts/generate_regmap_doc.py --regmap <regmap_file> --output <output_dir>
    uv run scripts/generate_regmap_doc.py --regmap spec/MAS/M01_DataflowController/regmap.md --output doc/regmap/
"""

import argparse
import re
import sys
from pathlib import Path
from datetime import datetime
import xml.etree.ElementTree as ET
from xml.dom import minidom


def parse_register_table(regmap_content: str) -> list[dict]:
    """
    Parse register definition table from regmap.md.

    Expected format:
    | 寄存器名 | 地址偏移 | 位宽 | 访问类型 | 复位值 | REQ_ID | 功能描述 |
    """
    registers = []

    # Find §1 register list section
    reg_section = re.search(
        r'## 1\.\s*(?:寄存器列表|Register List)(.*?)(?=## \d+\.|$)',
        regmap_content,
        re.DOTALL
    )

    if not reg_section:
        return registers

    section_text = reg_section.group(1)

    # Parse table rows
    table_pattern = r'\|\s*(\w+)\s*\|\s*(0x[0-9A-Fa-f_]+)\s*\|\s*(\d+)\s*\|\s*(\w+)\s*\|\s*(0x[0-9A-Fa-f_]+)\s*\|\s*([\w-]+)\s*\|\s*(.*?)\s*\|'

    for match in re.finditer(table_pattern, section_text):
        registers.append({
            'name': match.group(1),
            'offset': int(match.group(2).replace('_', ''), 16),
            'width': int(match.group(3)),
            'access': match.group(4),
            'reset': int(match.group(5).replace('_', ''), 16),
            'req_id': match.group(6),
            'description': match.group(7).strip()
        })

    return registers


def parse_bit_fields(regmap_content: str, reg_name: str) -> list[dict]:
    """
    Parse bit field definitions for a specific register.

    Expected format:
    ### 2.1 CTRL (0x00) - 控制寄存器
    #### 位域定义
    | 位 | 名称 | 访问 | 复位值 | 功能 |
    """
    bit_fields = []

    # Find register subsection (§2.x)
    reg_pattern = rf'###\s*2\.\d+\s*{re.escape(reg_name)}\s*\(0x[0-9A-Fa-f]+\)(.*?)(?=###\s*2\.\d+|\Z)'
    reg_match = re.search(reg_pattern, regmap_content, re.DOTALL)

    if not reg_match:
        return bit_fields

    section_text = reg_match.group(1)

    # Parse bit field table
    # Support both single bit [n] and range [n:m]
    field_pattern = r'\|\s*\[(\d+)(?::(\d+))?\]\s*\|\s*(\w+)\s*\|\s*([\w-]+)\s*\|\s*(0x[0-9A-Fa-f_]+|\d+)\s*\|\s*(.*?)\s*\|'

    for match in re.finditer(field_pattern, section_text):
        high_bit = int(match.group(1))
        low_bit = int(match.group(2)) if match.group(2) else high_bit
        width = high_bit - low_bit + 1

        bit_fields.append({
            'name': match.group(3),
            'bit_offset': low_bit,
            'bit_width': width,
            'access': match.group(4),
            'reset': int(match.group(5).replace('_', ''), 0),
            'description': match.group(6).strip()
        })

    return bit_fields


def generate_markdown(design_name: str, registers: list[dict], mas_content: str) -> str:
    """Generate Markdown documentation."""

    # Extract spec version from MAS
    version_match = re.search(r'version:\s*([\d.]+)', mas_content)
    version = version_match.group(1) if version_match else "1.0"

    # Extract base address (if defined)
    base_addr_match = re.search(r'Base\s*Address[:\s]+(0x[0-9A-Fa-f]+)', mas_content, re.IGNORECASE)
    base_addr = base_addr_match.group(1) if base_addr_match else "0x0000_0000"

    md = []
    md.append(f"# {design_name} Register Map\n")
    md.append(f"**Base Address**: {base_addr}  ")
    md.append(f"**Spec Version**: {version}  ")
    md.append(f"**Generated**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")

    md.append("## Register Summary\n")
    md.append("| Offset | Name | Width | Access | Reset | REQ_ID | Description |")
    md.append("|--------|------|-------|--------|-------|--------|-------------|")

    for reg in registers:
        md.append(
            f"| 0x{reg['offset']:02X} | {reg['name']} | {reg['width']} | "
            f"{reg['access']} | 0x{reg['reset']:X} | {reg['req_id']} | {reg['description']} |"
        )

    md.append("\n## Register Details\n")

    for reg in registers:
        md.append(f"### {reg['name']} (0x{reg['offset']:02X}) - {reg['description']}\n")
        md.append(f"**Access**: {reg['access']}  ")
        md.append(f"**Reset Value**: 0x{reg['reset']:X}  ")
        md.append(f"**REQ_ID**: {reg['req_id']}\n")

        # Parse bit fields
        bit_fields = parse_bit_fields(mas_content, reg['name'])

        if bit_fields:
            md.append("#### Bit Fields\n")
            md.append("| Bit | Name | Access | Reset | Description |")
            md.append("|-----|------|--------|-------|-------------|")

            for field in bit_fields:
                if field['bit_width'] == 1:
                    bit_range = f"[{field['bit_offset']}]"
                else:
                    bit_range = f"[{field['bit_offset']+field['bit_width']-1}:{field['bit_offset']}]"

                md.append(
                    f"| {bit_range} | {field['name']} | {field['access']} | "
                    f"{field['reset']} | {field['description']} |"
                )

            md.append("")

    return '\n'.join(md)


def generate_svd(design_name: str, registers: list[dict], mas_content: str) -> str:
    """Generate CMSIS-SVD XML file."""

    # Create SVD structure
    device = ET.Element('device', {
        'schemaVersion': '1.3',
        'xmlns:xs': 'http://www.w3.org/2001/XMLSchema-instance',
        'xs:noNamespaceSchemaLocation': 'CMSIS-SVD.xsd'
    })

    ET.SubElement(device, 'vendor').text = 'Babel'
    ET.SubElement(device, 'name').text = design_name
    ET.SubElement(device, 'version').text = '1.0'
    ET.SubElement(device, 'description').text = f'{design_name} Register Map'
    ET.SubElement(device, 'addressUnitBits').text = '8'
    ET.SubElement(device, 'width').text = '32'

    # CPU section
    cpu = ET.SubElement(device, 'cpu')
    ET.SubElement(cpu, 'name').text = 'CM0'
    ET.SubElement(cpu, 'revision').text = 'r0p0'
    ET.SubElement(cpu, 'endian').text = 'little'
    ET.SubElement(cpu, 'mpuPresent').text = 'false'
    ET.SubElement(cpu, 'fpuPresent').text = 'false'

    # Peripherals
    peripherals = ET.SubElement(device, 'peripherals')
    peripheral = ET.SubElement(peripherals, 'peripheral')
    ET.SubElement(peripheral, 'name').text = design_name
    ET.SubElement(peripheral, 'baseAddress').text = '0x00000000'

    # Registers
    regs_elem = ET.SubElement(peripheral, 'registers')

    for reg in registers:
        reg_elem = ET.SubElement(regs_elem, 'register')
        ET.SubElement(reg_elem, 'name').text = reg['name']
        ET.SubElement(reg_elem, 'description').text = reg['description']
        ET.SubElement(reg_elem, 'addressOffset').text = f"0x{reg['offset']:02X}"
        ET.SubElement(reg_elem, 'size').text = str(reg['width'])
        ET.SubElement(reg_elem, 'access').text = reg['access'].lower()
        ET.SubElement(reg_elem, 'resetValue').text = f"0x{reg['reset']:08X}"

        # Add bit fields
        bit_fields = parse_bit_fields(mas_content, reg['name'])

        if bit_fields:
            fields_elem = ET.SubElement(reg_elem, 'fields')

            for field in bit_fields:
                field_elem = ET.SubElement(fields_elem, 'field')
                ET.SubElement(field_elem, 'name').text = field['name']
                ET.SubElement(field_elem, 'description').text = field['description']
                ET.SubElement(field_elem, 'bitOffset').text = str(field['bit_offset'])
                ET.SubElement(field_elem, 'bitWidth').text = str(field['bit_width'])
                ET.SubElement(field_elem, 'access').text = field['access'].lower()

    # Pretty print
    xml_str = ET.tostring(device, encoding='unicode')
    dom = minidom.parseString(xml_str)
    return dom.toprettyxml(indent='  ')


def main():
    parser = argparse.ArgumentParser(
        description='Generate register map documentation from regmap.md'
    )
    parser.add_argument('--regmap', required=True, help='Path to regmap.md file')
    parser.add_argument('--output', required=True, help='Output directory')
    parser.add_argument('--format', choices=['md', 'svd', 'both'], default='both',
                       help='Output format (default: both)')

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

    # Extract design name from regmap path
    design_name = regmap_path.parent.name

    # Create output directory
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    # Generate outputs
    if args.format in ['md', 'both']:
        md_content = generate_markdown(design_name, registers, regmap_content)
        md_path = output_dir / f"{design_name}.md"
        md_path.write_text(md_content)
        print(f"✓ Generated: {md_path}")

    if args.format in ['svd', 'both']:
        svd_content = generate_svd(design_name, registers, regmap_content)
        svd_path = output_dir / f"{design_name}.svd"
        svd_path.write_text(svd_content)
        print(f"✓ Generated: {svd_path}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
