# KLayout Pitfalls — ASAP7 7nm

## 1. DRC Rule Deck Version
ASAP7 DRC deck must match PDK version. Check `tech.asap7.drc` version matches libs.

## 2. GDSII Layer Map
KLayout uses different layer numbering than Magic. Always verify layer map matches ASAP7 LEF.

## 3. Deep Mode Performance
Deep mode (`-b`) is essential for large designs but uses more memory. Set `-t 4` threads minimum.

## 4. Cell Name Conflicts
KLayout auto-flattens cells with same name. Use `--add-cell-name` to preserve hierarchy.

## 5. Macro Script Encoding
KLayout macros (.lym) must be UTF-8. Non-ASCII in comments causes silent parse failure.

## 6. DRC Timeout
Complex designs can exceed default timeout. Set explicit timeout: `--timeout 3600`.
