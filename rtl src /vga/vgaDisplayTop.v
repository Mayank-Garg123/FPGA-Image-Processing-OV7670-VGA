module vgaDisplayTop (
    input        axi_clk,        // 25MHz VGA pixel clock
    input        axi_reset_n,

    // From systemTop / FIFO / imageProcessTop
    input        i_data_valid,
    input  [7:0] i_data,
    input  [3:0] opcode,

    // VGA output signals
    output       vga_hsync,
    output       vga_vsync,
    output [7:0] vga_r,
    output [7:0] vga_g,
    output [7:0] vga_b,
    output       vga_valid,

    // Debug
    output       o_intr
);

    // =================================================
    // Image Processing Module
    // =================================================
    wire [7:0] proc_pixel;
    wire       proc_valid;
    wire       intr;

    imageProcessTop IMG (
        .axi_clk        (axi_clk),
        .axi_reset_n    (axi_reset_n),
        .i_data_valid   (i_data_valid),
        .i_data         (i_data),
        .opcode         (opcode),
        .o_data_valid   (proc_valid),
        .o_data         (proc_pixel),
        .i_data_ready   (1'b1),
        .o_intr         (intr)
    );

    assign o_intr = intr;

    // =================================================
    // VGA Timing Generator 640×480 @25MHz
    // =================================================
    reg [9:0] hcount = 0;
    reg [9:0] vcount = 0;

    localparam H_TOTAL   = 800;
    localparam H_SYNC    = 96;
    localparam H_BACK    = 48;
    localparam H_ACTIVE  = 640;

    localparam V_TOTAL   = 525;
    localparam V_SYNC    = 2;
    localparam V_BACK    = 33;
    localparam V_ACTIVE  = 480;

    always @(posedge axi_clk or negedge axi_reset_n) begin
        if (!axi_reset_n) begin
            hcount <= 0;
            vcount <= 0;
        end else begin
            if (hcount == H_TOTAL - 1) begin
                hcount <= 0;
                if (vcount == V_TOTAL - 1)
                    vcount <= 0;
                else
                    vcount <= vcount + 1;
            end else begin
                hcount <= hcount + 1;
            end
        end
    end

    assign vga_hsync = ~((hcount >= 0) && (hcount < H_SYNC));
    assign vga_vsync = ~((vcount >= 0) && (vcount < V_SYNC));

    wire active_area =
        (hcount >= (H_SYNC + H_BACK)) &&
        (hcount <  (H_SYNC + H_BACK + H_ACTIVE)) &&
        (vcount >= (V_SYNC + V_BACK)) &&
        (vcount <  (V_SYNC + V_BACK + V_ACTIVE));

    assign vga_valid = active_area;

    // =================================================
    // Centering 512×480 inside 640×480
    // =================================================
    localparam X_OFFSET = (640 - 512) / 2;   // 64
    localparam Y_OFFSET = (480 - 480) / 2;   // 0

    wire display_window =
        (hcount >= (H_SYNC + H_BACK + X_OFFSET)) &&
        (hcount <  (H_SYNC + H_BACK + X_OFFSET + 512)) &&
        (vcount >= (V_SYNC + V_BACK + Y_OFFSET)) &&
        (vcount <  (V_SYNC + V_BACK + Y_OFFSET + 480));

    // =================================================
    // Output RGB
    // =================================================
    assign vga_r = (display_window && proc_valid) ? proc_pixel : 8'd0;
    assign vga_g = (display_window && proc_valid) ? proc_pixel : 8'd0;
    assign vga_b = (display_window && proc_valid) ? proc_pixel : 8'd0;

endmodule
