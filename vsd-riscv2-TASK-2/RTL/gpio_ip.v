`default_nettype none

module gpio_ip (
    input  wire clk,
    input  wire resetn,

    //Bus interface
    input  wire [29:0] mem_wordaddr, // mem_addr[31:2]
    input  wire isIO, // mem_addr[22]
    input  wire mem_wstrb, // |mem_wmask
    input  wire [31:0] mem_wdata,  // write data from CPU

    //Read-back to IO_rdata mux
    output wire [31:0] gpio_rdata,

    //Actual GPIO output port 
    output wire [31:0] gpio_out
);

    localparam IO_GPIO_bit = 3;

    wire gpio_sel_w = isIO & mem_wstrb  & mem_wordaddr[IO_GPIO_bit];
    wire gpio_sel_r = isIO & (~mem_wstrb) & mem_wordaddr[IO_GPIO_bit];


    //single 32-bit register
    reg [31:0] gpio_reg;

    always @(posedge clk) begin
        if (!resetn) begin
            gpio_reg <= 32'b0;          // clear on reset
        end else if (gpio_sel_w) begin
            gpio_reg <= mem_wdata;      // CPU write updates the register
        end
    end

    assign gpio_rdata = mem_wordaddr[IO_GPIO_bit] ? gpio_reg : 32'b0;
    assign gpio_out = gpio_reg;

endmodule
