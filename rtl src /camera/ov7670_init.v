`timescale 1ns / 1ps

// ------------------------------------------------------------
// Module: ov7670_init
// Description:
//   Initializes OV7670 camera using SCCB (I2C-like) interface
//   Writes a predefined register table for RGB565 VGA mode
// ------------------------------------------------------------

module ov7670_init (
    input  wire        clk,        // System clock (e.g. 25/50 MHz)
    input  wire        rstn,       // Active-low reset

    output reg         done,       // Goes high when init sequence finishes

    // SCCB / I2C interface
    output reg         sccb_start, // Pulse to start one SCCB write
    input  wire        sccb_busy,  // High while SCCB transfer in progress
    output reg  [7:0]  sccb_addr,  // Camera register address
    output reg  [7:0]  sccb_data   // Data to write
);

    // --------------------------------------------------------
    // Register Initialization ROM
    // --------------------------------------------------------
    localparam integer N = 28;      // Number of register-value pairs

    reg [15:0] rom [0:N-1];         // {reg_addr, reg_data}

    initial begin
        // --- Core reset & format ---
        rom[0]  = {8'h12, 8'h80}; // COM7: reset
        rom[1]  = {8'h12, 8'h04}; // COM7: RGB
        rom[2]  = {8'h11, 8'h01}; // CLKRC: clock prescaler

        // --- Scaling / timing ---
        rom[3]  = {8'h0C, 8'h04}; // COM3
        rom[4]  = {8'h3E, 8'h19}; // COM14
        rom[5]  = {8'h8C, 8'h00}; // RGB444 disable
        rom[6]  = {8'h40, 8'hD0}; // COM15: RGB565
        rom[7]  = {8'h3A, 8'h04}; // TSLB
        rom[8]  = {8'h15, 8'h00}; // COM10

        // --- Horizontal / vertical window ---
        rom[9]  = {8'h17, 8'h11}; // HSTART
        rom[10] = {8'h18, 8'h75}; // HSTOP
        rom[11] = {8'h32, 8'h36}; // HREF
        rom[12] = {8'h19, 8'h02}; // VSTART
        rom[13] = {8'h1A, 8'h7A}; // VSTOP
        rom[14] = {8'h03, 8'h0A}; // VREF

        // --- Misc tuning ---
        rom[15] = {8'h0E, 8'h61};
        rom[16] = {8'h0F, 8'h4B};
        rom[17] = {8'h16, 8'h02};

        // --- Image quality ---
        rom[18] = {8'hA2, 8'h02};
        rom[19] = {8'h29, 8'h00};
        rom[20] = {8'h2B, 8'h00};
        rom[21] = {8'h6B, 8'h0A};
        rom[22] = {8'h3B, 8'h0A};
        rom[23] = {8'h4F, 8'h80};
        rom[24] = {8'h50, 8'h80};

        // --- Final clock & mode ---
        rom[25] = {8'h11, 8'h00};
        rom[26] = {8'h12, 8'h04};

        // Optional terminator / NOP
        rom[27] = {8'h00, 8'h00};
    end

    // --------------------------------------------------------
    // FSM Definitions
    // --------------------------------------------------------
    localparam S_IDLE = 1'b0;
    localparam S_SEND = 1'b1;

    reg        state;
    reg [7:0]  idx;

    // --------------------------------------------------------
    // SCCB Write State Machine
    // --------------------------------------------------------
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            idx        <= 8'd0;
            state      <= S_IDLE;
            done       <= 1'b0;
            sccb_start <= 1'b0;
            sccb_addr  <= 8'd0;
            sccb_data  <= 8'd0;
        end else begin
            // Default: pulse behavior
            sccb_start <= 1'b0;

            if (!done) begin
                case (state)

                    // ----------------------------
                    // Load next register
                    // ----------------------------
                    S_IDLE: begin
                        if (idx < N) begin
                            sccb_addr  <= rom[idx][15:8];
                            sccb_data  <= rom[idx][7:0];
                            sccb_start <= 1'b1;
                            state      <= S_SEND;
                        end else begin
                            done <= 1'b1;
                        end
                    end

                    // ----------------------------
                    // Wait for SCCB completion
                    // ----------------------------
                    S_SEND: begin
                        if (!sccb_busy) begin
                            idx   <= idx + 1'b1;
                            state <= S_IDLE;
                        end
                    end

                endcase
            end
        end
    end

endmodule
