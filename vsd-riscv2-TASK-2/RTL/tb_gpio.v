`timescale 1ns/1ps
`default_nettype none
`include "gpio_ip.v"

module tb_gpio;

    reg clk    = 0;
    reg resetn = 0;

    always #5 clk = ~clk;  

    reg  [29:0] mem_wordaddr;
    reg  isIO;
    reg  mem_wstrb;
    reg  [31:0] mem_wdata;

    wire [31:0] gpio_rdata;
    wire [31:0] gpio_out;

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

    initial begin
        $dumpfile("gpio_wave.vcd");
        $dumpvars(0, tb_gpio); 
    end

    integer pass_count = 0;
    integer fail_count = 0;

    task gpio_write;
        input [31:0] data;
        begin
            @(negedge clk);          
            mem_wordaddr = 30'b1000; 
            isIO = 1'b1;
            mem_wstrb = 1'b1;
            mem_wdata = data;
            @(posedge clk);          
            #1;                      
            mem_wstrb    = 1'b0;    
            isIO         = 1'b0;
        end
    endtask

    task check_gpio;
        input [31:0] expected;
        input [63:0] test_num;  
        begin
            mem_wordaddr = 30'b1000; 
            isIO = 1'b1;
            mem_wstrb = 1'b0;     
            #1;                      

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

    initial begin

        mem_wordaddr = 0;
        isIO         = 0;
        mem_wstrb    = 0;
        mem_wdata    = 0;

        resetn = 0;
        repeat(4) @(posedge clk);
        resetn = 1;
        repeat(2) @(posedge clk);

        $display("============================================");
        $display("   GPIO IP Testbench — Starting Tests");
        $display("============================================");

        $write("Reset check  | gpio_out after reset = 0x%08X | ", gpio_out);
        if (gpio_out === 32'h0) begin
            $display("PASS (cleared to 0)");
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL (expected 0x00000000)");
            fail_count = fail_count + 1;
        end

        gpio_write(32'h00000000);
        check_gpio(32'h00000000, 1);

        gpio_write(32'hFFFFFFFF);
        check_gpio(32'hFFFFFFFF, 2);

        gpio_write(32'h00000001);
        check_gpio(32'h00000001, 3);

        gpio_write(32'h80000000);
        check_gpio(32'h80000000, 4);

        gpio_write(32'hAAAAAAAA);
        check_gpio(32'hAAAAAAAA, 5);

        gpio_write(32'h55555555);
        check_gpio(32'h55555555, 6);

        gpio_write(32'hDEADBEEF);
        check_gpio(32'hDEADBEEF, 7);

        gpio_write(32'hCAFEBABE);
        gpio_write(32'h12345678); 
        check_gpio(32'h12345678, 8);

        @(negedge clk);
        mem_wordaddr = 30'b1000;
        isIO         = 1'b0;    
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

        repeat(2) @(posedge clk);
        $display("============================================");
        $display("   Results: %0d PASSED,  %0d FAILED", pass_count, fail_count);
        $display("   Waveform saved to: gpio_wave.vcd");
        $display("============================================");

        $finish;
    end

    initial begin
        #10000;
        $display("TIMEOUT — simulation exceeded 10us");
        $finish;
    end

endmodule
