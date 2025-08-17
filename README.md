# 🖥️ APB Slave with SystemVerilog Testbench

## 📌 Overview
This project implements a simple **APB (Advanced Peripheral Bus) Slave** in Verilog, along with a **SystemVerilog class-based testbench**.  
The testbench uses transaction-level modeling (TLM) concepts such as **Generator, Driver, Monitor, and Scoreboard** to verify the DUT.  

The APB slave supports:
- **Read/Write transactions**
- **16 memory locations (8-bit wide)**
- **Slave error detection (`pslverr`)** for invalid conditions

---


## ⚡ Design Details

### 🔹 APB Slave (`apb_s.sv`)
- Implements a **state machine** with states:
  - `idle`
  - `write`
  - `read`
- Stores data in `mem[16]` (8-bit memory).
- Checks for:
  - **Address error (`addr_err`)** → invalid address (> 15)
  - **Address value error (`addv_err`)**
  - **Data error (`data_err`)**
- Generates **slave error (`pslverr`)** on invalid access.

---

### 🔹 Interface (`abp_if.sv`)
Defines standard APB signals:
- Clock & Reset: `clk`, `presetn`
- Address/Data: `paddr`, `pwdata`, `prdata`
- Control: `psel`, `penable`, `pwrite`
- Status: `pready`, `pslverr`

---

## 🧪 Testbench (`tb.sv`)

### Components
- **Transaction**
  - Randomized: `paddr`, `pwdata`, `psel`, `penable`, `pwrite`
  - Includes constraints and display method
- **Generator**
  - Creates random transactions and sends via mailbox
- **Driver**
  - Drives DUT signals through `virtual abp_if`
  - Handles **reset, write, read**
- **Monitor**
  - Observes DUT signals and sends transactions to scoreboard
- **Scoreboard**
  - Maintains expected memory model
  - Compares DUT outputs
  - Reports mismatches and errors
- **Environment**
  - Instantiates all components
  - Connects via mailboxes & events
  - Manages pre-test, test, post-test

---
