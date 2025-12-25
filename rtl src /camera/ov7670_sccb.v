`timescale 1ns / 1ps

module ov7670_sccb (
    input  wire        clk,
    input  wire        resetn,

    input  wire        start,      // Start one SCCB write
    input  wire [7:0]  addr,       // Register address
    input  wire [7:0]  data,       // Register data

    output reg         sccb_scl,
    inout              sccb_sda,

    output reg         busy,
    output reg         done
);

    // --------------------------------------------------------
    // Open-drain SDA control
    // --------------------------------------------------------
    reg sda_o;
    reg sda_oe;                     // 1 = drive, 0 = release
    assign sccb_sda = sda_oe ? sda_o : 1'bz;

    // --------------------------------------------------------
    // Clock divider for ~100 kHz SCCB
    // --------------------------------------------------------
    localparam integer CLK_DIV = 250;   // adjust for system clk
    reg [15:0] clk_cnt;
    reg        tick;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            clk_cnt <= 0;
            tick    <= 0;
        end else begin
            if (clk_cnt == CLK_DIV-1) begin
                clk_cnt <= 0;
                tick    <= 1'b1;
            end else begin
                clk_cnt <= clk_cnt + 1;
                tick    <= 1'b0;
            end
        end
    end

    // --------------------------------------------------------
    // SCCB constants
    // --------------------------------------------------------
    localparam [7:0] DEV_ADDR = 8'h42;  // OV7670 write address

    // --------------------------------------------------------
    // FSM encoding
    // --------------------------------------------------------
    localparam [3:0]
        S_IDLE   = 4'd0,
        S_START  = 4'd1,
        S_DEV    = 4'd2,
        S_REG    = 4'd3,
        S_DATA   = 4'd4,
        S_STOP   = 4'd5,
        S_DONE   = 4'd6;

    reg [3:0] state;
    reg [7:0] shifter;
    reg [2:0] bitcnt;

    // --------------------------------------------------------
    // SCCB FSM
    // --------------------------------------------------------
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state    <= S_IDLE;
            sccb_scl <= 1'b1;
            sda_o    <= 1'b1;
            sda_oe   <= 1'b1;
            busy     <= 1'b0;
            done     <= 1'b0;
            bitcnt   <= 3'd7;
        end else begin
            done <= 1'b0;

            if (tick) begin
                case (state)

                    // ----------------------------
                    S_IDLE: begin
                        busy <= 1'b0;
                        sccb_scl <= 1'b1;
                        sda_o <= 1'b1;
                        sda_oe <= 1'b1;
                        if (start) begin
                            busy   <= 1'b1;
                            state  <= S_START;
                        end
                    end

                    // ----------------------------
                    // START condition
                    S_START: begin
                        sda_o <= 1'b0;
                        sda_oe <= 1'b1;
                        shifter <= DEV_ADDR;
                        bitcnt  <= 3'd7;
                        state   <= S_DEV;
                    end

                    // ----------------------------
                    // Send device address
                    S_DEV: begin
                        sccb_scl <= ~sccb_scl;
                        if (!sccb_scl) begin
                            sda_o <= shifter[bitcnt];
                        end else begin
                            if (bitcnt == 0) begin
                                shifter <= addr;
                                bitcnt  <= 3'd7;
                                state   <= S_REG;
                            end else
                                bitcnt <= bitcnt - 1'b1;
                        end
                    end

                    // ----------------------------
                    // Send register address
                    S_REG: begin
                        sccb_scl <= ~sccb_scl;
                        if (!sccb_scl) begin
                            sda_o <= shifter[bitcnt];
                        end else begin
                            if (bitcnt == 0) begin
                                shifter <= data;
                                bitcnt  <= 3'd7;
                                state   <= S_DATA;
                            end else
                                bitcnt <= bitcnt - 1'b1;
                        end
                    end

                    // ----------------------------
                    // Send register data
                    S_DATA: begin
                        sccb_scl <= ~sccb_scl;
                        if (!sccb_scl) begin
                            sda_o <= shifter[bitcnt];
                        end else begin
                            if (bitcnt == 0)
                                state <= S_STOP;
                            else
                                bitcnt <= bitcnt - 1'b1;
                        end
                    end

                    // ----------------------------
                    // STOP condition
                    S_STOP: begin
                        sccb_scl <= 1'b1;
                        sda_o    <= 1'b1;
                        state    <= S_DONE;
                    end

                    // ----------------------------
                    S_DONE: begin
                        busy <= 1'b0;
                        done <= 1'b1;
                        state <= S_IDLE;
                    end

                endcase
            end
        end
    end

endmodule
