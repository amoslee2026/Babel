# Verible Rule Pitfalls

## Common False Positive Rules

### line-length
Verible flags lines exceeding 100 characters. Long port lists and parameter
declarations commonly trigger this. Consider breaking across lines or waiving.

### no-trailing-spaces
Trailing whitespace in auto-generated files. Fix with formatter, not waiver.

### module-filename
Requires module name to match filename. False positive when multiple modules
share a file (e.g., wrapper + helper).

### always-comb
Flags `always @*` suggesting `always_comb`. Legacy Verilog-2001 style triggers this.
Safe to use `always_comb` in new code.

### explicit-parameter-storage-type
Flags parameters without explicit type. Usually safe to add `int` or `logic`.

### signal-name-style
Flags signal names not matching convention. Mixed-case names from IP integration
may trigger this. Consider waiving for third-party IP.

### no-tabs
Flags tab characters. Editor-dependent; configure editor to use spaces.

## Recommended ASAP7 Ruleset Waivers
```
# Waiver for generated code
always-comb
module-filename

# Waiver for third-party IP
signal-name-style
```
