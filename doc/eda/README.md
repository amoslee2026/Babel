# EDA Tools Inventory

This document lists all installed EDA tools in `/eda_tools/`, including their executable paths and documentation root directories.

## Summary

| Tool | Vendor | Version | Status |
|------|--------|---------|--------|
| Verilator | Wilson Snyder | 5.024 | Installed |
| JasperGold | Cadence | 2025.12, 2025.09p002 | Installed |
| Innovus | Cadence | 25.12-s079 | Installed (tarball) |
| Xcelium | Cadence | 25.01 | Tarball |
| Conformal LEC | Cadence | 25.20-s200 | Installed |
| Joules | Cadence | 25.13-s066 | Installed |
| JStudio | Cadence | 25.13-s066 | Installed |
| DDI | Cadence | 25.10.000 | Tarball (7 parts) |
| SSV | Cadence | 25.12-s082 | Tarball |
| Sigrity | Cadence | 25.10.0201, 25.1.2 | Installed |
| VSCode | Microsoft | 1.117.0 | RPM Package |

See [commercial-eda-tools.md](commercial-eda-tools.md) for full details.

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