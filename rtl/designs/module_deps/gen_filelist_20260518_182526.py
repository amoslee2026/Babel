#!/usr/bin/env python3
"""
Module Dependency Analyzer for Babel RTL
Scans all .sv files, builds module->file map and instantiation graph,
outputs file_list.f with proper ordering.
"""
import os
import re
import subprocess
import json
from pathlib import Path
from collections import defaultdict

def parse_sv_file(filepath):
    """Parse SV file to extract module declarations and instantiations."""
    modules_in_file = []
    instantiations = []
    
    content = Path(filepath).read_text()
    
    # Module declarations (exclude interface/class/package)
    module_pattern = r'^module\s+(\w+)\s*[#\(]'
    for match in re.finditer(module_pattern, content, re.MULTILINE):
        name = match.group(1)
        if name and 'interface' not in name.lower():
            modules_in_file.append(name)
    
    # Find instantiations (ModuleInstance pattern)
    # Pattern: identifier ModuleName ( or identifier ModuleName #
    inst_pattern = r'\b(M\d+_\w+)\s*[#\(]'
    for match in re.finditer(inst_pattern, content):
        inst_name = match.group(1)
        instantiations.append(inst_name)
    
    return modules_in_file, instantiations

def main():
    rtl_dir = 'rtl/'
    stamp = '20260518_182526'
    output_file = 'rtl/designs/module_deps/file_list.f'
    
    # Collect all .sv files in src directories
    sv_files = sorted(Path(rtl_dir).rglob('src/*.sv'))
    
    # Build module->file map
    module_to_file = {}
    file_to_modules = defaultdict(list)
    
    for filepath in sv_files:
        modules, insts = parse_sv_file(str(filepath))
        for mod in modules:
            module_to_file[mod] = str(filepath)
            file_to_modules[str(filepath)].append(mod)
    
    # Build dependency graph (parent -> set(child files))
    # KEY: only add cross-file dependencies, same-file modules are independent
    dep_graph_files = defaultdict(set)  # file -> set(child files)
    
    for filepath in sv_files:
        modules, insts = parse_sv_file(str(filepath))
        this_file_modules = set(modules)
        for inst in insts:
            if inst in module_to_file:
                inst_file = module_to_file[inst]
                # Only add if it's a different file
                if inst_file != str(filepath):
                    dep_graph_files[str(filepath)].add(inst_file)
    
    # Kahn's algorithm for file-level topological sort
    all_files = set(str(f) for f in sv_files)
    in_degree = defaultdict(int)
    
    for file in all_files:
        for child_file in dep_graph_files.get(file, []):
            in_degree[child_file] += 1
    
    # Start with files that have no dependencies
    queue = [f for f in sorted(all_files) if in_degree[f] == 0]
    sorted_files = []
    
    while queue:
        # Sort queue to ensure deterministic order (module number)
        queue.sort()
        file = queue.pop(0)
        sorted_files.append(file)
        for child_file in dep_graph_files.get(file, []):
            in_degree[child_file] -= 1
            if in_degree[child_file] == 0:
                queue.append(child_file)
    
    # Check for cycles
    if len(sorted_files) != len(all_files):
        print("ERROR: Cyclic dependency detected")
        remaining = all_files - set(sorted_files)
        print(f"Unsorted files: {remaining}")
        return
    
    # Collect all modules
    all_modules = []
    for f in sorted_files:
        all_modules.extend(file_to_modules.get(f, []))
    
    # Write output
    with open(output_file, 'w') as f:
        f.write("# RTL Module Dependency Order\n")
        f.write(f"# Generated: {stamp}\n")
        f.write(f"# Module count: {len(all_modules)}\n")
        f.write(f"# File count: {len(sorted_files)}\n\n")
        for filepath in sorted_files:
            f.write(f"{filepath}\n")
    
    print(f"Generated {output_file}")
    print(f"Modules: {len(all_modules)}")
    print(f"Files: {len(sorted_files)}")
    
    # Write JSON artifact
    artifact = {
        'stamp': stamp,
        'design_name': 'module_deps',
        'rtl_dir': rtl_dir,
        'artifact_path': output_file,
        'script_path': 'rtl/designs/module_deps/gen_filelist_20260518_182526.py',
        'module_count': len(all_modules),
        'file_count': len(sorted_files),
        'modules': all_modules,
        'ordered_files': sorted_files,
        'dep_graph_files': {k: list(v) for k, v in dep_graph_files.items()},
        'file_to_modules': {k: v for k, v in file_to_modules.items()},
        'valid': True,
        'error': None
    }
    with open('rtl/designs/module_deps/deps_artifact.json', 'w') as f:
        json.dump(artifact, f, indent=2)
    print(f"Artifact: rtl/designs/module_deps/deps_artifact.json")

if __name__ == '__main__':
    main()
