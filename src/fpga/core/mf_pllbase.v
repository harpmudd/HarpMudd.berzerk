// mf_pllbase.v - PLL wrapper for Berzerk Pocket core
// 74.25 MHz in -> 40 MHz (clk_sys) + 10 MHz (clk_10) + 5 MHz (clk_vid)
//                 + 5 MHz 90 deg (clk_vid_90)
`timescale 1 ps / 1 ps
module mf_pllbase (
    input  wire  refclk,
    input  wire  rst,
    output wire  outclk_0,  // 40.000 MHz - berzerk.clk_sys
    output wire  outclk_1,  // 10.000 MHz - berzerk.clock_10
    output wire  outclk_2,  //  5.000 MHz - pixel clock
    output wire  outclk_3,  //  5.000 MHz 90 deg - APF DDR pixel clock
    output wire  locked
);

mf_pllbase_0002 mf_pllbase_inst (
    .refclk   (refclk),
    .rst      (rst),
    .outclk_0 (outclk_0),
    .outclk_1 (outclk_1),
    .outclk_2 (outclk_2),
    .outclk_3 (outclk_3),
    .locked   (locked)
);

endmodule
