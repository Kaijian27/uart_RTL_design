# UART RTL Design (Verilog)

A from-scratch RTL implementation of a UART transmitter and receiver, built as a hands-on exercise while pivoting toward digital IC front-end / RTL design. Written in Verilog, verified with a self-checking loopback testbench.

## Overview

UART (Universal Asynchronous Receiver/Transmitter) is a simple serial protocol, but implementing it correctly touches on core digital design concepts: clock division, finite state machines, shift registers, and — most importantly — the asynchronous timing problem of recovering data with no shared clock between transmitter and receiver.

This project implements three modules and verifies them together:

| Module | Purpose |
|---|---|
| `baud_rate_gen.v` | Divides the system clock down to a single-cycle `tick` pulse at the target baud rate |
| `uart_tx.v` | FSM-based transmitter: sends 1 start bit, 8 data bits (LSB first), 1 stop bit |
| `uart_rx.v` | FSM-based receiver: detects the start bit edge, then self-times an independent counter to sample each bit at its midpoint |

## Frame Format

```
Idle -- Start(0) -- D0 D1 D2 D3 D4 D5 D6 D7 -- Stop(1) -- Idle
```

## Design Notes

- **TX and RX do not share a timing source.** TX is driven by an external baud tick (from `baud_rate_gen`); RX runs its own free-running counter starting the moment it detects `rx_line` fall low. This mirrors real UART behavior — it's an asynchronous protocol, so the receiver has to recover timing on its own rather than relying on a shared clock.
- **Mid-bit sampling.** RX waits half a bit period after the start-bit edge, then samples every full bit period after that — landing in the middle of each bit rather than at its edge, where the signal is most likely to still be settling.
- **Non-blocking assignments (`<=`)** are used throughout the sequential logic to avoid race conditions between assignments in the same clock edge — e.g. `bit_index == 7` is evaluated against the pre-increment value in the same cycle the increment is issued, which is what makes the "last bit" check land correctly.

## Verification

`tb/tb_uart.v` instantiates all three modules in loopback (`tx_line` wired directly to `rx_line`), drives a single test byte (`8'b1100_1100`) through `uart_tx`, and self-checks the result:

```
always @(posedge rx_done) begin
    if (rx_data == tx_data)
        $display("PASS: Sent = %b, Received = %b", tx_data, rx_data);
    else
        $display("FAIL: Sent = %b, Received = %b", tx_data, rx_data);
end
```

### Running the simulation

Any Verilog simulator works (tested with Icarus Verilog / Riviera-PRO via [EDA Playground](https://edaplayground.com)):

```bash
iverilog -o sim rtl/baud_rate_gen.v rtl/uart_tx.v rtl/uart_rx.v tb/tb_uart.v
vvp sim
```

Expected console output:

```
PASS: Sent = 11001100, Received = 11001100
```

## What I'd extend next

- Parameterize baud rate / clock frequency selection at the top level instead of matching `DIVISOR` manually between TX and RX
- Add a UVM-style randomized stimulus + scoreboard instead of a single fixed test byte
- Add basic error-frame handling (framing error if stop bit isn't high)

## Background

Built as part of a self-directed pivot from embedded systems work toward digital IC front-end / RTL design, targeting entry-level RTL design roles in Singapore.
