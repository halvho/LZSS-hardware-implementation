`timescale 1ns / 1ps
///////////////////////////////////////
////Combinatorial priority encoder ////
///////////////////////////////////////

module Priority_encoder_comb #(parameter DEPTH = 4, 
                               parameter WIDTH = 4) (
  input logic rst_,
  input logic [DEPTH-1:0][WIDTH-1:0] in,
  input logic symbol_match,
  output logic [DEPTH-1:0] row,
  output logic [WIDTH-1:0] col
);
  logic flag;
  always_comb begin
   if(!rst_)begin
     row = '0;
     col = '0;
     flag = '0;
   end else begin
     row = '0;
     col = '0;
     flag = '0;
     if(symbol_match) begin
       for(int i = DEPTH - 1; i >= 0; i--)begin
         for (int j = WIDTH - 1; j >= 0; j--)begin
           if (in[i][j] == 1'b1) begin
             row = DEPTH-1-i;
             col = WIDTH-j; //Final offset is 1-indexed
             flag = 1;
             break;
           end else begin
             row = '0;
             col = '0;
           end
         end
         if(flag==1) begin //SystemVerilog does not support nested loop breaks.
            break;
          end else begin
            continue;
          end
        end
      end
    end
  end
endmodule