module rgb565_to_gray(
 input wire [15:0] rgb565, 
 output wire [7:0] gray 
); 
   wire [4:0] r5 = rgb565[15:11]; 
   wire [5:0] g6 = rgb565[10:5]; 
   wire [4:0] b5 = rgb565[4:0]; 
   // Convert to 8-bit 
   wire [7:0] r = {r5, 3'b000}; 
   wire [7:0] g = {g6, 2'b00}; 
   wire [7:0] b = {b5, 3'b000}; 
   // Gray = 0.3R + 0.59G + 0.11B 
   assign gray = (r >> 2) + (g >> 1) + (b >> 3); 
 endmodule 
