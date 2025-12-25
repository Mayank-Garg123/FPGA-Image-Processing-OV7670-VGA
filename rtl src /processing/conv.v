`timescale 1ns / 1ps

module conv (
    input              i_clk,
    input      [71:0]   i_pixel_data,
    input              i_pixel_data_valid,
    input      [3:0]    opcode,
    output reg [7:0]    o_convolved_data,
    output reg          o_convolved_data_valid
);

    integer i;

    reg [7:0]   kernel1 [8:0];
    reg [7:0]   kernel2 [8:0];
    reg [15:0]  multData1 [8:0];
    reg [15:0]  multData2 [8:0];
    reg [15:0]  sumData1, sumData2;
    reg [31:0]  grad_val;

    reg signed [7:0]   kernel_sharp [8:0];
    reg signed [15:0]  sumSharp;

    always @(posedge i_clk) begin
        if (i_pixel_data_valid) begin
            case (opcode)

                //----------------------------------
                // 4'b1000 – Average Blur
                //----------------------------------
                4'b1000: begin
                    sumData1 = 0;
                    for (i = 0; i < 9; i = i + 1) begin
                        multData1[i] = i_pixel_data[i*8 +: 8];
                        sumData1     = sumData1 + multData1[i];
                    end
                    o_convolved_data        <= sumData1 / 9;
                    o_convolved_data_valid  <= 1'b1;
                end

                //----------------------------------
                // 4'b1001 – Edge Detection (Sobel)
                //----------------------------------
                4'b1001: begin
                    kernel1[0] =  1;  kernel1[1] =  0;  kernel1[2] = -1;
                    kernel1[3] =  2;  kernel1[4] =  0;  kernel1[5] = -2;
                    kernel1[6] =  1;  kernel1[7] =  0;  kernel1[8] = -1;

                    kernel2[0] =  1;  kernel2[1] =  2;  kernel2[2] =  1;
                    kernel2[3] =  0;  kernel2[4] =  0;  kernel2[5] =  0;
                    kernel2[6] = -1;  kernel2[7] = -2;  kernel2[8] = -1;

                    sumData1 = 0;
                    sumData2 = 0;

                    for (i = 0; i < 9; i = i + 1) begin
                        multData1[i] = $signed(kernel1[i]) *
                                       $signed(i_pixel_data[i*8 +: 8]);
                        multData2[i] = $signed(kernel2[i]) *
                                       $signed(i_pixel_data[i*8 +: 8]);
                        sumData1     = sumData1 + multData1[i];
                        sumData2     = sumData2 + multData2[i];
                    end

                    grad_val = (sumData1 * sumData1) +
                               (sumData2 * sumData2);

                    if (grad_val > 4000)
                        o_convolved_data <= 8'hFF;
                    else
                        o_convolved_data <= 8'h00;

                    o_convolved_data_valid <= 1'b1;
                end

                //----------------------------------
                // 4'b0011 – Color Inversion
                //----------------------------------
                4'b0011: begin
                    o_convolved_data        <= 8'd255 - i_pixel_data[7:0];
                    o_convolved_data_valid  <= 1'b1;
                end

                //----------------------------------
                // 4'b1101 – Sharpen Filter
                //----------------------------------
                4'b1101: begin
                    // Kernel:
                    //  [  0  -1   0
                    //    -1   5  -1
                    //     0  -1   0 ]

                    sumSharp = 0;

                    kernel_sharp[0] =  0;  kernel_sharp[1] = -1;  kernel_sharp[2] =  0;
                    kernel_sharp[3] = -1;  kernel_sharp[4] =  5;  kernel_sharp[5] = -1;
                    kernel_sharp[6] =  0;  kernel_sharp[7] = -1;  kernel_sharp[8] =  0;

                    for (i = 0; i < 9; i = i + 1)
                        sumSharp = sumSharp +
                                   $signed(kernel_sharp[i]) *
                                   $signed(i_pixel_data[i*8 +: 8]);

                    // Clamp output (0–255)
                    if (sumSharp < 0)
                        o_convolved_data <= 8'd0;
                    else if (sumSharp > 255)
                        o_convolved_data <= 8'd255;
                    else
                        o_convolved_data <= sumSharp[7:0];

                    o_convolved_data_valid <= 1'b1;
                end

                //----------------------------------
                // Default
                //----------------------------------
                default: begin
                    o_convolved_data        <= 8'd0;
                    o_convolved_data_valid  <= 1'b0;
                end

            endcase
        end
    end

endmodule
