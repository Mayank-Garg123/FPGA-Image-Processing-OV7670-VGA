module systemTop (
    input  wire        clk100,     // 100 MHz system clock
    input  wire        resetn,       // Active low reset

    // OV7670 Camera pins
    input  wire        ov_pclk,
    input  wire        ov_vsync,
    input  wire        ov_href,
    input  wire [7:0]  ov_data,
    inout  wire        ov_sio_c,
    inout  wire        ov_sio_d,

    // VGA outputs
    output wire        vga_hsync,
    output wire        vga_vsync,
    output wire [7:0]  vga_r,
    output wire [7:0]  vga_g,
    output wire [7:0]  vga_b
);

    // --------------------------------------------------------------
    // 1. CLOCK WIZARD – Generate system, camera, and VGA clocks
    // --------------------------------------------------------------
    wire        clk_sys;
    wire        clk_cam;
    wire        clk_vga;
    wire        clk_locked;

    wire [7:0]  sccb_addr;
    wire [7:0]  sccb_data;

    // -----------------------------------------
    // Clocking Wizard
    // -----------------------------------------
    clk_wiz_0 clk_gen (
        .clk_vga   (clk_vga),
        .clk_cam   (clk_cam),
        .clk_sys   (clk_sys),
        .reset     (~resetn),
        .locked    (locked),
        .clk_in1   (clk100)
    );

    // --------------------------------------------------------------
    // 2. SCCB (I2C-like) controller
    // --------------------------------------------------------------
    wire        sccb_busy;
    wire        sccb_done;
    wire        sccb_start;
    wire [7:0]  sccb_reg;
    wire [7:0]  sccb_val;

    ov7670_sccb sccb_inst (
        .clk       (clk_sys),
        .resetn    (resetn),
        .start     (sccb_start),
        .addr      (sccb_addr),
        .data      (sccb_data),
        .sccb_scl  (ov_sio_c),
        .sccb_sda  (ov_sio_d),
        .busy      (sccb_busy),
        .done      (sccb_done)
    );

    // --------------------------------------------------------------
    // 3. Camera INIT (Sends register writes)
    // --------------------------------------------------------------
    // Controller that sequences register writes
    ov7670_init camera_init (
        .clk         (clk_sys),
        .rstn        (resetn),
        .done        (cam_init_done),
        .sccb_start  (sccb_start),
        .sccb_busy   (sccb_busy),
        .sccb_addr   (sccb_addr),
        .sccb_data   (sccb_data)
    );

    // --------------------------------------------------------------
    // 4. OV7670 Pixel Capture
    // --------------------------------------------------------------
    wire        cam_wr_en;
    wire [15:0] cam_wr_data;

    ov7670_capture camera_cap (
        .pclk         (ov_pclk),
        .resetn       (resetn),
        .vsync        (ov_vsync),
        .href         (ov_href),
        .d            (ov_data),
        .fifo_wr_en   (cam_wr_en),
        .fifo_wr_data (cam_wr_data),
        .frame_start  (),
        .frame_end    ()
    );

    // --------------------------------------------------------------
    // 5. FIFO (Camera → Processing Clock Crossing)
    // --------------------------------------------------------------
    wire        fifo_valid;
    wire [15:0] fifo_pixel_16;

    cam_to_proc_fifo fifo_inst (
        .wr_rst_busy     (),
        .rd_rst_busy     (),

        // WRITE domain (Camera PCLK)
        .s_aclk          (ov_pclk),
        .s_aresetn       (resetn),
        .s_axis_tvalid   (cam_wr_en),
        .s_axis_tready   (),
        .s_axis_tdata    (cam_wr_data),

        // READ domain (VGA clock)
        .m_aclk          (clk_vga),
        .m_axis_tvalid   (fifo_valid),
        .m_axis_tready   (1'b1),
        .m_axis_tdata    (fifo_pixel_16),

        .s_axis_tuser    (1'b0),
        .m_axis_tuser    ()
    );

    // --------------------------------------------------------------
    // 6. Convert RGB565 → Grayscale
    // --------------------------------------------------------------
    wire [7:0] gray_pixel;

    rgb565_to_gray gray_unit (
        .rgb565  (fifo_pixel_16),
        .gray    (gray_pixel)
    );

    // --------------------------------------------------------------
    // 7. VGA DISPLAY + Image Processing
    // --------------------------------------------------------------
    vgaDisplayTop vgaTop (
        .axi_clk        (clk_vga),
        .axi_reset_n    (resetn),
        .i_data_valid   (fifo_valid),
        .i_data         (gray_pixel),
        .opcode         (4'b1001),    // Edge detection
        .vga_hsync      (vga_hsync),
        .vga_vsync      (vga_vsync),
        .vga_r          (vga_r),
        .vga_g          (vga_g),
        .vga_b          (vga_b),
        .vga_valid      ()
    );

endmodule
