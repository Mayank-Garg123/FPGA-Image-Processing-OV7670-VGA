`timescale 1ns / 1ps

// imageProcessTop.v
// Top-level processing: imageControl -> conv -> outputBuffer (AXI FIFO)

module imageProcessTop (
    input  wire        axi_clk,
    input  wire        axi_reset_n,

    // Pixel stream from testbench / camera
    input  wire        i_data_valid,
    input  wire [7:0]  i_data,

    // Operation control (opcode)
    input  wire [3:0]  opcode,

    // Processed pixel output (to VGA or AXI)
    output wire        o_data_valid,
    output wire [7:0]  o_data,
    input  wire        i_data_ready,

    // Frame done interrupt
    output wire        o_intr
);

    // --------------------------------------------------------
    // Internal wires
    // --------------------------------------------------------
    wire [71:0] pixel_window;         // 3×3 = 72 bits (9 * 8)
    wire        pixel_window_valid;
    wire [3:0]  opcode_to_conv;
    wire [7:0]  conv_pixel;
    wire        conv_valid;

    // --------------------------------------------------------
    // Instantiate imageControl
    // (creates 3x3 sliding window and passes opcode)
    // --------------------------------------------------------
    imageControl IC (
        .i_clk               (axi_clk),
        .i_rst               (!axi_reset_n),
        .i_pixel_data        (i_data),
        .i_pixel_data_valid  (i_data_valid),
        .o_pixel_data        (pixel_window),
        .o_pixel_data_valid  (pixel_window_valid),
        .o_intr              (o_intr),
        .i_opcode            (opcode),
        .o_opcode            (opcode_to_conv)
    );

    // --------------------------------------------------------
    // Instantiate convolution/filter engine
    // --------------------------------------------------------
    conv CONV_UNIT (
        .i_clk                   (axi_clk),
        .i_pixel_data            (pixel_window),
        .i_pixel_data_valid      (pixel_window_valid),
        .opcode                  (opcode_to_conv),
        .o_convolved_data        (conv_pixel),
        .o_convolved_data_valid  (conv_valid)
    );

    // --------------------------------------------------------
    // AXI FIFO (outputBuffer IP)
    // --------------------------------------------------------
    outputBuffer OB (
        .wr_rst_busy     (),                 // output wire
        .rd_rst_busy     (),                 // output wire
        .s_aclk          (axi_clk),
        .s_aresetn       (axi_reset_n),
        .s_axis_tvalid   (conv_valid),
        .s_axis_tready   (),                 // not used
        .s_axis_tdata    (conv_pixel),
        .m_axis_tvalid   (o_data_valid),
        .m_axis_tready   (i_data_ready),
        .m_axis_tdata    (o_data),
        .axis_prog_full  ()                  // optional
    );

endmodule
