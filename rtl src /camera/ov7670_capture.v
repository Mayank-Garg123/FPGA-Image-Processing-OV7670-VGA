`timescale 1ns / 1ps

module ov7670_capture (
    input        pclk,        // Pixel clock from camera
    input        resetn,      // Active-low reset
    input        vsync,       // Frame sync
    input        href,        // Line valid
    input  [7:0] d,           // Camera data bus

    // FIFO write interface (camera clock domain)
    output reg        fifo_wr_en,
    output reg [15:0] fifo_wr_data,

    output reg        frame_start,
    output reg        frame_end
);

    reg [7:0] byte_latch;
    reg       byte_toggle;
    reg       vsync_d;        // delayed vsync for edge detection

    always @(posedge pclk or negedge resetn) begin
        if (!resetn) begin
            byte_latch   <= 8'd0;
            byte_toggle  <= 1'b0;
            fifo_wr_en   <= 1'b0;
            fifo_wr_data <= 16'd0;
            frame_start  <= 1'b0;
            frame_end    <= 1'b0;
            vsync_d      <= 1'b0;
        end else begin
            // default values
            fifo_wr_en  <= 1'b0;
            frame_start <= 1'b0;
            frame_end   <= 1'b0;

            // VSYNC edge detection
            vsync_d <= vsync;

            // Frame start: falling edge of vsync
            if (vsync_d == 1'b1 && vsync == 1'b0) begin
                frame_start <= 1'b1;
            end

            // Frame end: rising edge of vsync
            if (vsync_d == 1'b0 && vsync == 1'b1) begin
                frame_end <= 1'b1;
            end

            // Pixel capture during active line
            if (href) begin
                if (!byte_toggle) begin
                    // First byte (MSB)
                    byte_latch  <= d;
                    byte_toggle <= 1'b1;
                end else begin
                    // Second byte (LSB) → full RGB565 pixel
                    fifo_wr_data <= {byte_latch, d};
                    fifo_wr_en   <= 1'b1;
                    byte_toggle  <= 1'b0;
                end
            end else begin
                // Reset byte alignment when line ends
                byte_toggle <= 1'b0;
            end
        end
    end

endmodule
