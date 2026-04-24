// ============================================================
//  Simple GPIO Output IP  (Write-Only, Memory-Mapped)
//  
//  Bus Interface : Custom SOC bus (same as LED / UART peripherals)
//  Address       : IO page, 1-hot word address bit 3
//                  → effective address  0x00400008  (bit 22 = IO,
//                                                    word addr bit 3)
//  Register map  :
//    Offset 0x00 (the only register)
//      [31:0]  gpio_reg  –  written by CPU, drives gpio_out[31:0]
//                           read-back returns last written value
//
//  Signals that connect to SOC top-level
//    clk         – system clock  (from Clockworks)
//    resetn      – active-low reset
//    mem_wordaddr– mem_addr[31:2]  (29-bit word address from CPU)
//    isIO        – mem_addr[22]    (IO-page select from SOC)
//    mem_wstrb   – |mem_wmask      (any byte write active)
//    mem_wdata   – 32-bit write data from CPU
//    gpio_rdata  – 32-bit read data back to IO_rdata mux
//    gpio_out    – 32-bit output port (connect to LEDs / pins)
// ============================================================

`default_nettype none

module gpio_ip (
    input  wire        clk,
    input  wire        resetn,

    // --- Bus interface (same signals already in SOC) ----------
    input  wire [29:0] mem_wordaddr, // mem_addr[31:2]
    input  wire        isIO,         // mem_addr[22]
    input  wire        mem_wstrb,    // |mem_wmask
    input  wire [31:0] mem_wdata,    // write data from CPU

    // --- Read-back to IO_rdata mux ---------------------------
    output wire [31:0] gpio_rdata,

    // --- Actual GPIO output port ------------------------------
    output wire [31:0] gpio_out
);

    // ----------------------------------------------------------
    // 1-hot address bit for this peripheral
    //   bit 0 → LEDS
    //   bit 1 → UART_DAT
    //   bit 2 → UART_CNTL
    //   bit 3 → GPIO   ← this IP
    // ----------------------------------------------------------
    localparam IO_GPIO_bit = 3;

    // Decode: this peripheral is selected when IO page is active
    // AND word-address bit 3 is set
    wire gpio_sel_w = isIO & mem_wstrb  & mem_wordaddr[IO_GPIO_bit];
    wire gpio_sel_r = isIO & (~mem_wstrb) & mem_wordaddr[IO_GPIO_bit];

    // ----------------------------------------------------------
    // The single 32-bit register
    // ----------------------------------------------------------
    reg [31:0] gpio_reg;

    always @(posedge clk) begin
        if (!resetn) begin
            gpio_reg <= 32'b0;          // clear on reset
        end else if (gpio_sel_w) begin
            gpio_reg <= mem_wdata;      // CPU write updates the register
        end
    end

    // ----------------------------------------------------------
    // Read-back  (combinational – mirrors SOC IO_rdata pattern)
    // Returns last written value when CPU reads this address,
    // returns 0 otherwise (so it can be OR-ed safely in the mux)
    // ----------------------------------------------------------
    assign gpio_rdata = mem_wordaddr[IO_GPIO_bit] ? gpio_reg : 32'b0;

    // ----------------------------------------------------------
    // Output port – continuously reflects the register value
    // ----------------------------------------------------------
    assign gpio_out = gpio_reg;

endmodule