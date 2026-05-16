# EDA Tools Inventory

This document lists all installed EDA tools in `/eda_tools/`, including their executable paths and documentation root directories.

## Summary

| Tool | Vendor | Version | Status |
|------|--------|---------|--------|
| Verilator | Wilson Snyder | 5.024 | Installed |
| JasperGold | Cadence | 2025.12, 2025.09p002 | Installed |
| Innovus | Cadence | 25.12-s079 | Installed (tarball) |
| VSCode | Microsoft | 1.117.0 | RPM Package |
| Sigrity | Cadence | 25.10.0201 | Tarball (not extracted) |

---

## Directory Structure

```
/eda_tools/
  cadence/
    jasper2025.12/          # JasperGold formal verification
  other_tools/
    vscode/                 # VS Code RPM package
  pkg/
    innovus/                # Innovus place-and-route (tarball + extracted)
    [other Cadence packages]
  verilator/
    5.024/                  # Verilator simulation tool
    default -> 5.024/       # Symlink to current version
```