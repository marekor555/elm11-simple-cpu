# Custom FPGA CPU

A small custom 8-bit CPU implemented in SystemVerilog and running on an FPGA(ELM11-Feather).

This was built as a learning project to experiment with CPU architecture, instruction encoding, memory, registers etc. Absolutely don't waste your time trying to make a real project with this.

## Features

* 8-bit registers
* 8-bit program counter
* 2048 slot 8-bit data memory
* 256 instruction memory
* Custom 20-bit instruction set
* Addition, subtraction and some boolean operations
* LOAD / STORE instructions
* Conditional and unconditional jumps
* Programmable millisecond WAIT instruction
* FPGA hardware output through LEDs

## Architecture

The CPU has two general-purpose 8-bit registers: A(0) and B(1)

Instructions are 20 bits wide, with the upper 5 bits used as the opcode.

### Instruction Set

| Opcode  | Instruction | Description                                 |
| ------- | ----------- | ------------------------------------------- |
| `00001` | STORE       | Store A or B to memory                      |
| `00010` | LOAD        | Load memory into A or B                     |
| `00011` | SET ADDR    | Set the memory address                      |
| `00100` | SWITCH      | Swap A and B                                |
| `00111` | SET REG     | Set A or B to an 8-bit immediate            |
| `01000` | ADD         | `A = A + B`                                 |
| `01001` | SUB         | `A = A - B`                                 |
| `10000` | OR          | `A = A \| B` `B=0`                          |
| `10001` | AND         | `A = A & B` `B=0`                           |
| `10010` | NOT         | `A = ~A`                                    |
| `10011` | IF A        | Jump to address in B if A is non-zero       |
| `11000` | JMP         | Unconditional jump                          |
| `11011` | WAIT        | Wait for a specified number of milliseconds |

Unused opcodes currently behave as NOPs, you *can* just leave nothing on a line, this can be used as an unwritten NOP.

## Example Program

The current test program increments a value once every 250 ms and stores it in memory location `0`:

```text
0: SET ADDR 0
1: A = 0
2: B = 1

3: A = A + B
4: STORE A
5: WAIT 250 ms
6: JMP 3
```

with the value written to `mem[0]`.

The lower 6 bits of `mem[0]` are connected to the FPGA LEDs.

There is another program commented out, but it's quite boring honestly.
## Timing

The CPU runs from a 27 MHz FPGA clock.

The `WAIT` instruction uses the clock directly and the values provided are in milliseconds.

This implementation is very unoptimized, but also the fastest to implement. Don't do this like that if you are trying to make a good CPU.

## Hardware

The project was developed directly on an FPGA board using a 27 MHz input clock and six LEDs for output.

The LEDs are active-low, so the memory output is inverted before being connected to the LED pins.

## Project Status

I am pretty sure the implemeted features work.

The CPU can execute programs with arithmetic, logic, memory, branching and timing instructions on the FPGA.

This project serves as a small experiment in designing a CPU from scratch in SystemVerilog.

## Why?

Why not? Also this is a fun way to learn SystemsVerilog, maybe a bit annoying at the end.