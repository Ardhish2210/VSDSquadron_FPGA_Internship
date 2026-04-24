// ============================================================
//  tb_gpio.v  —  Testbench for GPIO IP (Step 4 Simulation)
//
//  Tests:
//    1. Direct gpio_ip module tests (unit test)
//    2. Waveform dumped to gpio_wave.vcd  (open in GTKWave)
//
//  Run with:
//    iverilog -o tb_gpio gpio_ip.v tb_gpio.v && vvp tb_gpio
// ============================================================

`timescale 1ns/1ps
`default_nettype none
`include "gpio_ip.v"

module tb_gpio;

    // --------------------------------------------------------
    // Clock & reset
    // --------------------------------------------------------
    reg clk    = 0;
    reg resetn = 0;

    always #5 clk = ~clk;  // 100 MHz clock (10ns period)

    // --------------------------------------------------------
    // DUT (Device Under Test) signals  — match gpio_ip ports
    // --------------------------------------------------------
    reg  [29:0] mem_wordaddr;
    reg         isIO;
    reg         mem_wstrb;
    reg  [31:0] mem_wdata;

    wire [31:0] gpio_rdata;
    wire [31:0] gpio_out;

    // --------------------------------------------------------
    // Instantiate gpio_ip
    // --------------------------------------------------------
    gpio_ip DUT (
        .clk         (clk),
        .resetn      (resetn),
        .mem_wordaddr(mem_wordaddr),
        .isIO        (isIO),
        .mem_wstrb   (mem_wstrb),
        .mem_wdata   (mem_wdata),
        .gpio_rdata  (gpio_rdata),
        .gpio_out    (gpio_out)
    );

    // --------------------------------------------------------
    // VCD waveform dump  →  gpio_wave.vcd
    // Open with: gtkwave gpio_wave.vcd
    // --------------------------------------------------------
    initial begin
        $dumpfile("gpio_wave.vcd");
        $dumpvars(0, tb_gpio);  // dump ALL signals in this tb
    end

    // --------------------------------------------------------
    // Test tracking
    // --------------------------------------------------------
    integer pass_count = 0;
    integer fail_count = 0;

    // --------------------------------------------------------
    // Task: write a value to GPIO register
    //   IO_GPIO_bit = 3  →  mem_wordaddr bit 3 must be set
    //   GPIO address = 0x00400010 → word addr = 0x00100004
    //   bit 3 of word addr = 1  ✓
    // --------------------------------------------------------
    task gpio_write;
        input [31:0] data;
        begin
            @(negedge clk);          // change on falling edge
            mem_wordaddr = 30'b1000; // bit 3 set = GPIO select
            isIO         = 1'b1;
            mem_wstrb    = 1'b1;
            mem_wdata    = data;
            @(posedge clk);          // latch happens here
            #1;                      // small settle time
            mem_wstrb    = 1'b0;     // deassert write strobe
            isIO         = 1'b0;
        end
    endtask

    // --------------------------------------------------------
    // Task: check gpio_out and gpio_rdata, print PASS/FAIL
    // --------------------------------------------------------
    task check_gpio;
        input [31:0] expected;
        input [63:0] test_num;  // test number for display
        begin
            // gpio_out is combinational — check immediately
            // gpio_rdata also combinational when wordaddr[3]=1
            mem_wordaddr = 30'b1000; // keep bit 3 high for read
            isIO         = 1'b1;
            mem_wstrb    = 1'b0;     // read, not write
            #1;                      // let combinational settle

            $write("Test %0d | wrote 0x%08X | gpio_out=0x%08X | gpio_rdata=0x%08X | ",
                   test_num, expected, gpio_out, gpio_rdata);

            if (gpio_out === expected && gpio_rdata === expected) begin
                $display("PASS");
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL  *** expected 0x%08X ***", expected);
                fail_count = fail_count + 1;
            end

            isIO = 1'b0;
        end
    endtask

    // --------------------------------------------------------
    // Main test sequence
    // --------------------------------------------------------
    initial begin
        // initialise inputs
        mem_wordaddr = 0;
        isIO         = 0;
        mem_wstrb    = 0;
        mem_wdata    = 0;

        // ---- Reset sequence --------------------------------
        resetn = 0;
        repeat(4) @(posedge clk);
        resetn = 1;
        repeat(2) @(posedge clk);

        $display("============================================");
        $display("   GPIO IP Testbench — Starting Tests");
        $display("============================================");

        // ---- Check reset state ------------------------------
        $write("Reset check  | gpio_out after reset = 0x%08X | ", gpio_out);
        if (gpio_out === 32'h0) begin
            $display("PASS (cleared to 0)");
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL (expected 0x00000000)");
            fail_count = fail_count + 1;
        end

        // ---- Test 1: All zeros ------------------------------
        gpio_write(32'h00000000);
        check_gpio(32'h00000000, 1);

        // ---- Test 2: All ones -------------------------------
        gpio_write(32'hFFFFFFFF);
        check_gpio(32'hFFFFFFFF, 2);

        // ---- Test 3: LSB only (walking 1 low) ---------------
        gpio_write(32'h00000001);
        check_gpio(32'h00000001, 3);

        // ---- Test 4: MSB only (walking 1 high) --------------
        gpio_write(32'h80000000);
        check_gpio(32'h80000000, 4);

        // ---- Test 5: Alternating 0xAA -----------------------
        gpio_write(32'hAAAAAAAA);
        check_gpio(32'hAAAAAAAA, 5);

        // ---- Test 6: Alternating 0x55 -----------------------
        gpio_write(32'h55555555);
        check_gpio(32'h55555555, 6);

        // ---- Test 7: Meaningful value -----------------------
        gpio_write(32'hDEADBEEF);
        check_gpio(32'hDEADBEEF, 7);

        // ---- Test 8: Overwrite — value should update --------
        gpio_write(32'hCAFEBABE);
        gpio_write(32'h12345678); // overwrite with new value
        check_gpio(32'h12345678, 8);

        // ---- Test 9: Verify no write when isIO=0 ------------
        // gpio holds 0x12345678 from test 8
        // attempt a write with isIO=0 — register must NOT change
        @(negedge clk);
        mem_wordaddr = 30'b1000;
        isIO         = 1'b0;    // IO NOT selected
        mem_wstrb    = 1'b1;
        mem_wdata    = 32'hBAD0BAD0;
        @(posedge clk);
        #1;
        mem_wstrb = 1'b0;

        $write("Test 9  | isIO=0 write ignored check  | gpio_out=0x%08X | ", gpio_out);
        if (gpio_out === 32'h12345678) begin
            $display("PASS (register unchanged)");
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL (register was incorrectly overwritten!)");
            fail_count = fail_count + 1;
        end

        // ---- Summary ----------------------------------------
        repeat(2) @(posedge clk);
        $display("============================================");
        $display("   Results: %0d PASSED,  %0d FAILED", pass_count, fail_count);
        $display("   Waveform saved to: gpio_wave.vcd");
        $display("============================================");

        $finish;
    end

    // --------------------------------------------------------
    // Timeout watchdog — prevents infinite loops
    // --------------------------------------------------------
    initial begin
        #10000;
        $display("TIMEOUT — simulation exceeded 10us");
        $finish;
    end

endmodule