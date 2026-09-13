# SystemVerilog Pitfalls for Module Dependency Analysis

## 1. `import` vs `include`
`import` pulls package symbols; `` `include`` pastes file content. Dependency scanner must track both.

## 2. Parameterized Module Instantiation
```sv
mod #( .WIDTH(8) ) inst (...);  // dependency on `mod`
```
The `#()` parameter list doesn't change the module dependency.

## 3. Interface Ports
```sv
module top(input axi_if.master m);  // dependency on `axi_if`
```
Interface types create module dependencies that regex scanners often miss.

## 4. Generate Blocks
```sv
generate for (genvar i=0; i<N; i++) begin : gen
  submodule u(.a(w[i]));  // dependency on `submodule`
end endgenerate
```
Module instantiations inside generate blocks are still dependencies.

## 5. `bind` Statements
```sv
bind target_module checker_if u(.clk(clk));
```
`bind` creates implicit dependencies not visible in module port lists.

## 6. Program Blocks
```sv
program test;  // not a module, but may instantiate modules
```
Program blocks can instantiate modules — don't skip them in dependency analysis.
