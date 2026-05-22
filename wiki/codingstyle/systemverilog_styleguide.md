# SystemVerilog Style Guide

> **来源**: https://www.systemverilog.io/verification/styleguide/
> **作者**: Subramani Ganesh

---

## Introduction

Code is read much more often than it is written. Striving for a consistent coding style across the team improves readability of code and is one of the best (and easiest) ways to save engineering-hours.

Among the several programming languages that exist today, I would argue that Python is the most beautiful. It is easy to comprehend code written by someone else and reading a complex piece of code doesn't feel intimidating. In fact the code you write looks no different from that written by a core developer. This can be largely attributed to PEP8, which is Python's style guide. It's fascinating how well the community has adopted this document.

Since PEP8 is well written and has proven to work, the high level structure and portions of text have been borrowed from there to avoid reinventing the wheel. Several ideas for this style guide have also been derived from the UVM library code base.

> **PEP8**: A style guide is about consistency. Consistency with this style guide is important. Consistency within a project is more important. Consistency within one module or function is the most important.
>
> However, know when to be inconsistent -- sometimes style guide recommendations just aren't applicable. When in doubt, use your best judgment.

---

## Code Layout

### Indentation

Use 4 spaces per indentation level. Here are a few special considerations.

**YES**:
```systemverilog
// 2nd line of args start after function name on the line before
foo = long_function_name(
        var_one, var_two, var_three,
        var_four);

// Align 2nd line of args with first. Four space indentation is optional
// for continuation lines. For example: `var_three` does not start on a
// 4-space indent
foo = long_function_name(var_one, var_two,
                        var_three, var_four);

// More indentation included in the 2nd line of function declaration
// to distinguish from body of function
void function long_function_name(var_one, var_two
        var_three, var_four);
    int x;
    ...
endfunction: long_function_name

// Add some extra indentation on the conditional continuation line
if (expr_one && expr_two &&
        expr_three) begin
    do_something();
end
```

**NO**:
```systemverilog
// 2nd line of args starts before function name
foo = long_function_name(var_one, var_two,
    var_three, var_four);

// Further indentation required on 2nd line of args as indentation
// is not distinguishable from body of function.
voidfunction long_function_name(var_one, var_two
    var_three, var_four);
    int x;
    ...
endfunction: long_function_name
```

### Tabs or Spaces

Spaces are the preferred indentation method.

> **PEP8**: Tabs should be used solely to remain consistent with code that is already indented with tabs.

**Vi/Vim setting to use 4 spaces instead of tabs**:
```vim
" place this in ~/.vimrc
set tabstop=4
set shiftwidth=4
set expandtab
```

**Emacs setting to use 4 spaces instead of tabs**:
```emacs-lisp
; place this in ~/.emacs
(setq-default indent-tabs-mode nil)
(setq-default tab-width 4)
(setq indent-line-function 'insert-tab)
```

### Maximum Line Length

Limit all lines, including comments, to a maximum of 100 characters.

The traditional recommendation is 80 characters, but considering UVM's long macro definitions such as `uvm_object_utils` and the fact that with a print statement such as:

```systemverilog
`uvm_info(get_name(), ...., UVM_MEDIUM)
```

you've lost about 30 characters right in the declaration, you will find yourself constantly fighting the 80 limit. So, it helps to ease the anxiety and set this at a 100 right off the bat.

Make sure to indent the continued line appropriately.

### begin & end

- `end` goes on a line of its own

**YES**:
```systemverilog
always_ff @(posedge clk) begin
    ...
end

if (big_endian == 1) begin
    m_bits[count+i] = value[size-1-i];
end
else begin
    m_bits[count+i] = value[i];
end

for (int i = 0; i < size; i++) begin
    if (big_endian == 1) begin
        m_bits[count+i] = value[size-1-i];
    end
    else begin
        m_bits[count+i] = value[i];
    end
end
```

- `begin` goes on the same line as the first statement of the block it belongs to

### if & else

- `else` starts on a new line

**YES**:
```systemverilog
if (big_endian == 1) begin
    m_bits[count+i] = value[size-1-i];
end
else begin
    m_bits[count+i] = value[i];
end
```

**NO**:
```systemverilog
    if (big_endian == 1) begin
        m_bits[count+i] = value[size-1-i];
    end else begin
        m_bits[count+i] = value[i];
    end
```

**Always use `begin/end` with conditional statements.** Doing the following is a recipe for bugs.

**NO**:
```systemverilog
// Avoid these
if (big_endian == 1)
    m_bits[count+i] = value[size-1-i];
else
    m_bits[count+i] = value[i];

// Especially avoid these:
// Even though this is valid code and works as expected at first,
// someone else may add a line of code after the else
// and assume that it'll trigger on the `else` condition
// and end up introducing a hard to find bug.
for (int i = 0; i < size; i++)
    if (big_endian == 1)
        m_bits[count+i] = value[size-1-i];
    else
        m_bits[count+i] = value[i];
```

### Blank Lines

- Surround class, functions and tasks with a blank line
- Blank lines may be omitted between a bunch of related one-liner code
- Use blank lines within functions and tasks, sparingly, to to indicate logical sections

---

## Whitespace in Expressions & Statements

### function & task

When calling or declaring functions and tasks:
- No whitespace between the function/task name and the opening parenthesis
- No whitespace between the opening parenthesis and first argument

**YES**:
```systemverilog
void function foo(x, y, z); 
foo(x, y, z);
```

**NO**:
```systemverilog
void function foo (x, y, z);
foo (x, y, z);
foo( x, y, z );
```

Don't use spaces around the `=` sign for default argument value.

**YES**:
```systemverilog
void function foo(name="foo", x=1, y=20)
```

**NO**:
```systemverilog
void function foo(name = "foo", x = 1, y = 20)
```

### Assignments & Operators

More than one space around an assignment (or other) operator to align it with another.

**YES**:
```systemverilog
x = 1
y = 2
long_variable = 3
```

**NO**:
```systemverilog
x             = 1
y             = 2
long_variable = 3
```

Always surround these binary operators with a single space on either side:
- assignment `(=)`
- augmented assignment `(+=, -=)`
- comparisons `(==, ===, <, >, !=, !==, <=, >=)`
- logicals `(&, &&, |, ||)`

### Loops & Conditions

Keeping in line with previous point on Assignments & Operators - There should be a whitespace around the terms in a for loop `int i = 0;` and `i < 10;`.

**YES**:
```systemverilog
if (x == 10)
for (int ii = 0; ii < 20; ii++)
while (1)
```

**NO**:
```systemverilog
if(x == 10)
if( x == 10 )
```

Compound statements (multiple statements on the same line) are generally discouraged.

**NO**:
```systemverilog
if (foo == 1) $display("bar");
```

- `if, for, while` - One whitespace between the conditional keyword and the opening parenthesis.

### Always Block

Whitespaces in `always` blocks should be as follows:

**YES**:
```systemverilog
always_ff @(posedge clk) begin
always_comb begin
```

---

## Comments

> **PEP8**: Comments that contradict the code are worse than no comments. Always make a priority of keeping the comments up-to-date when the code changes!

Comments should be complete sentences. If a comment is a phrase or sentence, its first word should be capitalized, unless it is an identifier that begins with a lower case letter (never alter the case of identifiers!).

If a comment is short, the period at the end can be omitted. Block comments generally consist of one or more paragraphs built out of complete sentences, and each sentence should end in a period.

### Copyright Banner

For the licensing/copyright banner use the following style comment block:

```systemverilog
/***********************************************************************
 * Copyright 2007-2011 Mentor Graphics Corporation
 * Copyright 2007-2010 Cadence Design Systems, Inc.
 * Copyright 2010 Synopsys, Inc.
 * Copyright 2013 NVIDIA Corporation
 * All Rights Reserved Worldwide
 *
 * Licensed under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in
 * compliance with the License.  You may obtain a copy of
 * the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in
 * writing, software distributed under the License is
 * distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied.  See
 * the License for the specific language governing
 * permissions and limitations under the License.
 **********************************************************************/
```

### Docstring

Docstring (Document String) is the comment that go right at the top of a file and provides a high level description of what the code in that file does. Place the docstring right after the copyright banner. Do not mix the two of them. Use the following style for this segment:

```systemverilog
 * Ending of copyright banner
 **********************************************************************/
/*
 * Module `ABC`
 *
 * This is the 1st paragraph. Separate paragraphs with
 * an empty line with just the ` *` character.
 *
 * This is the 2nd paragraph. Do not fence the docstring
 * in a banner of `*****`. Only the copyright segment
 * above the docstring gets a fence.
 */
```

### Block Comments

> **PEP8**: Block comments generally apply to some (or all) code that follows them, and are indented to the same level as that code.

Each line of a block comment starts with a `//` and a single space (unless it is indented text inside the comment). Paragraphs inside a block comment are separated by a line containing a single `//`.

Alternatively, you can also use the `/* */` style for a multi-line block comment.

```systemverilog
// This is one of the block comment
// and this is the second line.
//
// This would be the 2nd paragraph of this block comment.

/* 
 * This comment describes what the
 * following lines of code do.
 */
 foo = bar + 1;
```

### Inline Comments

Avoid inline comments.

```systemverilog
// Don't do this
x = x + 1    // Increment packets sent
```

### General Comment on Comments

- In a rush to meet deadlines comments are usually neglected. I've done this too and I always regret this decision when I revisit code after a while. So spending a little time commenting code now, save a bunch of pain at a later time. The future YOU will thank the present you.
- Avoid comment fences such as `/**********************/`, or `//#######################`, `//////////////`. It clutters your code and doesn't help as much as you think it does. The same physical separation a comment fence promises can easily be provided by a well written block comment. Only the copyright banner should be fenced.

---

## Naming Conventions

Just so we are all on the same page, let's define some common naming conventions:

| Convention | Description |
|------------|-------------|
| `PascalCase` | First Letter of every word is capitalized |
| `camelCase` | First letter of every word, EXCEPT the first word, is capitalized |
| `lowercase_with_underscores` | All lowercase with underscores separating words |
| `UPPERCASE_WITH_UNDERSCORES` | All uppercase with underscores separating words |

### File Names

File names should use `lowercase_with_underscore`:

```systemverilog
crc_generator.sv
tb_defines.svh
module_specification.docx
input_message_buffer.sv
```

### Class & Module

Class and module names should use `lowercase_with_underscore`. If there's just one class or module in the file then its name should be the same as the filename.

```systemverilog
class packet_parser_agent;
endclass: packet_parser_agent

module packet_parser_engine;
endmodule: packet_parser_engine
```

Class instances should be treated as variables and should use the `lowercase_with_underscore` format. Module instances should use pure camelCase without any underscores.

```systemverilog
// Class
packet_parser_agent parser_agent;
parser_agent = new();

// Module
packet_parser_engine ppe0(.*);
packet_parser_engine packetParserEngine4a(.*);
packet_parser_engine packetParserEngine4b(.*);
```

### Interface

- Interface definitions use `lowercase_with_underscores` ending in `"_io"`
- Interface instances end in `_if`
- `clocking` blocks use `camelCase`
- `modport` should preferably be just one word in `lowercase`

```systemverilog
interface bus_io(input bit clk);
    logic vld;
    logic [7:0] addr, data;

    clocking ioDrv @(posedge clk);
        input addr;
        output vld;
        output data;
    endclocking: ioDrv

    modport dut(input addr, output vld, data);
    modport tb(clocking ioDrv);
endinterface: bus_io

module tb_top;
    bus_io bus_if(clk);
endmodule: tb_top
```

### Variables

Variable names should always use lowercase_with_underscore:

```systemverilog
ethernet_agent eth_agent;
int count_packets, count_errors;
logic [15:0] some_long_var;
```

If necessary, use a prefix to easily identify and group variables:

```systemverilog
logic [31:0] pe_counter_0;
logic [31:0] pe_counter_1;
logic [31:0] pe_counter_2;
```

### Struct, Union & Enum

`typedef` all structs, unions and enums. They should use camelCase with the following distinction:

- Structs end with `_s`
- Unions end with `_u`
- Enums end with `_e`. Additionally, enumerations should use `UPPERCASE_WITH_UNDERSCORES`.

```systemverilog
typedef struct packed {
    logic [47:0] macda;
    logic [47:0] macsa;
    logic [15:0] etype;
} ethPacket_s;

typedef union packed {
    logic [15:0] tx_count;
    logic [15:0] rx_count;
} dataPacketCount_u;

typedef logic [1:0] enum {
    IPV4_TCP,
    IPV4_UDP,
    IPV6_TCP,
    IPV6_UDP,
} packetType_e;
```

### Type Variable Name

Type variable names should be in `UPPERCASE` and preferably just one word.

```systemverilog
// Following examples were extracted from the UVM code base.
// The file path where they can be found is also mentioned.

// tlm1/uvm_exports.svh
class uvm_get_peek_export #(type T=int)
class uvm_blocking_master_export #(type REQ=int, type RSP=REQ)

// base/uvm_traversal.svh
virtual class uvm_visitor_adapter #(type STRUCTURE=uvm_component,
    VISITOR=uvm_visitor#(STRUCTURE)) extends uvm_object;
```

---

## Macros

- `UPPERCASE` macro names and `lowercase` args for functions and tasks
- `lowercase` macro names and `UPPERCASE` args for everything else (like, classes, code-snippets, etc)
- Separate words with underscore

```systemverilog
// UPPERCASE macro name and lower case args for tasks & functions  
`define PRINT_BYTES(arr, startbyte, numbytes) \
    function print_bytes(logic[7:0] arr[], int startbyte, int numbytes); \
        for (int ii=startbyte; ii<startbyte+numbytes; ii++) begin \
            if ((ii != 0) && (ii % 16 == 0)) \
                $display("\n"); \
            $display("0x%x ", arr[ii]); \
        end \
    endfunction: print_bytes

// Lowercase macro name and UPPERCASE args for Classes
`define uvm_analysis_imp_decl(SFX) \
    class uvm_analysis_imp``SFX #(type T=int, type IMP=int) \
      extends uvm_port_base #(uvm_tlm_if_base #(T,T)); \
      `UVM_IMP_COMMON(`UVM_TLM_ANALYSIS_MASK,`"uvm_analysis_imp``SFX`",IMP) \
      function void write( input T t); \
        m_imp.write``SFX( t); \
      endfunction \
    endclass

// Lowercase macro name and UPPERCASE args for snippets
`define uvm_create_on(SEQ_OR_ITEM, SEQR) \
  begin \
  uvm_object_wrapper w_; \
  w_ = SEQ_OR_ITEM.get_type(); \
  $cast(SEQ_OR_ITEM, create_item(w_, SEQR, `"SEQ_OR_ITEM`"));\
  end
```

---

## Closing Identifiers

Always use closing identifiers where applicable:

```systemverilog
endclass: driver_agent
endmodule: potato_block
endinterface: memory_io
endtask: cowboy_bebop
```

---

## Programming Recommendations

Since SystemVerilog spans design and verification, it has a vast number of constructs. So, for those not explicitly mentioned in this style guide, such as assertions, coverage, repeat, assign, etc., the recommendations made so far can be suitably extended.

---

## Conclusion

Writing beautiful code isn't easy. Between work deadlines and countless other things - it is difficult to care about, revisit, refactor and simplify code that is produced in a hurry.

> "Let us change our traditional attitude to the construction of programs: Instead of imagining that our main task is to instruct a computer what to do, let us concentrate rather on explaining to human beings what we want a computer to do."
> — Donald Knuth

> "So, beautiful code is lucid, easy to read and understand; its organization, its shape, its architecture reveals intent as much as its declarative syntax does. Each small part is coherent, singular in its purpose, and although all these small sections fit together like the pieces of a complex mosaic, they come apart easily when one element needs to be changed or replaced"
> — Vikram Chandra, author of Geek Sublime

---

## References

1. UVM source code
2. PEP8 - Style guide for Python code
3. PEP7 - Style guide for C code
4. Geek Sublime - Vikram Chandra
5. Beautiful Code - Andy Oram, Greg Wilson
6. The great white space debate