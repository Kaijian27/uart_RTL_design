# UART RTL Design (Verilog)

A from-scratch RTL implementation of a UART transmitter and receiver, built as a hands-on exercise while pivoting toward digital IC front-end / RTL design. The RTL (`baud_rate_gen.v`, `uart_tx.v`, `uart_rx.v`) is plain Verilog; the testbench additionally uses `$fatal`, a SystemVerilog (IEEE 1800) system task, to give the test run a proper pass/fail exit code.

## Overview

UART (Universal Asynchronous Receiver/Transmitter) is a simple serial protocol, but implementing it correctly touches on core digital design concepts: clock division, finite state machines, shift registers, and — most importantly — the asynchronous timing problem of recovering data with no shared clock between transmitter and receiver.

This project implements three modules and verifies them together:

| Module | Purpose |
|---|---|
| `baud_rate_gen.v` | Divides the system clock down to a single-cycle `tick` pulse at the target baud rate |
| `uart_tx.v` | FSM-based transmitter: sends 1 start bit, 8 data bits (LSB first), 1 stop bit |
| `uart_rx.v` | FSM-based receiver: detects the start bit edge, self-times an independent counter, samples each bit at its midpoint, and validates start/stop bits before accepting a frame |

## Frame Format

```
Idle -- Start(0) -- D0 D1 D2 D3 D4 D5 D6 D7 -- Stop(1) -- Idle
```

## Design Notes

- **TX and RX do not share a timing source.** TX is driven by an external baud tick (from `baud_rate_gen`); RX runs its own free-running counter starting the moment it detects `rx_line` fall low. This mirrors real UART behavior — it's an asynchronous protocol, so the receiver has to recover timing on its own rather than relying on a shared clock.
- **Mid-bit sampling.** RX waits half a bit period after the start-bit edge, then samples every full bit period after that — landing in the middle of each bit rather than at its edge, where the signal is most likely to still be settling.
- **Start-bit glitch rejection.** RX re-checks `rx_line` at the midpoint of the start bit. If it's no longer low (i.e. the falling edge was noise, not a real start bit), RX aborts back to IDLE instead of proceeding to sample data.
- **Stop-bit validation.** RX checks `rx_line` at the midpoint of the stop bit. If it isn't high, the frame is silently discarded — `rx_data` and `rx_done` are not updated. There is currently no separate `frame_error` output to flag this to the outside world (see Limitations).
- **Non-blocking assignments (`<=`)** are used throughout the sequential logic to avoid race conditions between assignments in the same clock edge — e.g. `bit_index == 7` is evaluated against the pre-increment value in the same cycle the increment is issued, which is what makes the "last bit" check land correctly.

## Verification

`tb/tb_uart.v` instantiates all three modules in loopback (`tx_line` wired directly to `rx_line`) and runs a **self-checking, multi-byte test sequence**:

- Test vectors: `8'h00`, `8'hFF`, `8'hA5`, `8'h55` (all-zero, all-one, mixed-bit, and alternating-bit patterns, chosen to exercise both the shift-register logic and common edge cases)
- A `send_and_check` task drives `tx_start`, waits for `tx_busy` to deassert, then compares `rx_data` against the byte that was sent
- On mismatch, the testbench calls `$fatal` (halts simulation, non-zero exit code) instead of just printing — so the result is usable by scripts/CI, not just by eye
- A second, independent `initial` block acts as a global timeout watchdog: if the test sequence hasn't finished within a generous time budget, it fires `$fatal` on its own. Because it runs in parallel with the test sequence, it only fires if something is genuinely stuck (the normal test run finishes and calls `$finish` well before the watchdog's deadline)

### A bug this caught

Early versions of `send_and_check` toggled `tx_start` and immediately checked `wait(tx_busy == 0)`. Because `uart_tx` only updates `tx_busy` on the next `posedge clk`, the wait could see the *old* value of `tx_busy` and return immediately — silently skipping the actual transmission and comparing stale data. This passed for the first test byte by coincidence but failed on the second. Fixed by adding a small delay (`#5`) between issuing the `tx_start` pulse and checking `tx_busy`, giving the DUT a clock edge to react. This is a testbench race condition, not an RTL bug — a good example of how flawed verification code can produce false positives.

### Running the simulation

The RTL is plain Verilog, but the testbench uses `$fatal` (SystemVerilog), so compile with SystemVerilog support enabled (tested with Icarus Verilog and Riviera-PRO):

```bash
iverilog -g2012 -o sim.out rtl/baud_rate_gen.v rtl/uart_tx.v rtl/uart_rx.v tb/tb_uart.v
vvp sim.out
```

Expected console output:

```
PASS: Sent = 00000000, Received = 00000000
PASS: Sent = 11111111, Received = 11111111
PASS: Sent = 10100101, Received = 10100101
PASS: Sent = 01010101, Received = 01010101
All tests finished.
```

## Limitations / Future Work

These are known gaps, not yet addressed:

- **No `frame_error` output.** RX currently discards frames with an invalid stop bit silently. A real design should expose this as a status signal so upstream logic knows a frame was dropped.
- **Start/stop-bit checks are implemented but not yet tested against malformed input.** The current testbench only exercises clean, well-formed frames via loopback, so the glitch-rejection and stop-bit-validation logic hasn't actually been exercised by a test that sends bad data (a short noise pulse, or a corrupted stop bit). This would require a test that drives `rx_line` directly instead of going through `uart_tx`.
- **No input synchronizer on `rx_line`.** The loopback testbench has `uart_tx` and `uart_rx` sharing the same `clk`, so metastability never comes up. A real design receiving an external, truly asynchronous UART signal should pass `rx_line` through a 2-flop synchronizer before the RX state machine reads it. The current design has **not** been validated against a genuinely asynchronous input.
- **TX start-bit alignment depends on when `tx_start` is asserted relative to the baud tick counter.** Since `tick` free-runs independently of `tx_start`, the first bit sent after a `tx_start` pulse could in principle be shorter than a full bit period if triggered right before a tick. Not yet an issue in testing, but worth hardening.

## Background

Built as part of a self-directed pivot from embedded systems work toward digital IC front-end / RTL design, targeting entry-level RTL design roles in Singapore.
