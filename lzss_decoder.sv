`timescale 1ns / 1ps 

import Parameters::*;

module lzss_decoder (
  input logic rst_,
  input logic clk,
  input logic literal,
  input logic data_ready,
  input logic [3*SYMBOL_LENGTH-1:0] data_in,
  output logic new_data_ready,
  output logic data_valid,
  output logic [SYMBOL_LENGTH-1:0] data_out
);
    
  logic [15:0] match_offset;
  logic [15:0] match_offset_temp;
  logic [7:0] match_length;
        
  //Enable signals
  logic decode_en;
  logic copy_out_en;
  logic copy_to_decode_en;
    
  logic [SYMBOL_LENGTH-1:0] decode_buffer[SEARCH_BUFFER_SIZE-1:0]; 
  logic [SYMBOL_LENGTH-1:0] output_buffer[SEARCH_BUFFER_SIZE-1:0];
    
  always_ff @(posedge clk) begin
    if(!rst_) begin
      for (int i = SEARCH_BUFFER_SIZE-1; i >= 0; i = i - 1) begin
        decode_buffer[i]<= 8'hxx;
        output_buffer[i]<= 8'hxx;
      end
      match_offset      <= '0;
      match_offset_temp <= '0;
      match_length      <= '0;
      decode_en         <= '0;
      copy_out_en       <= '0;
      copy_to_decode_en <= '0;
      new_data_ready    <= '0;
      data_valid        <= '0;
      data_out          <= '0;
    end else begin
      if(data_ready)begin
      new_data_ready <= '1;
        if(!copy_out_en && !copy_to_decode_en)begin
          if(literal && !decode_en)begin
            data_out[7:0] <= data_in[7:0];
            data_valid <= '1;
            for (int i = SEARCH_BUFFER_SIZE-1; i >= 1; i = i - 1) begin
              decode_buffer[i] <= decode_buffer[i-1];
            end
            decode_buffer[0] <= data_in[7:0];   
            new_data_ready <= '1;  
          end else if(!literal && !decode_en) begin
            match_offset <= data_in[15:0];
            match_length <= data_in[23:16];
            decode_en <= '1;
            copy_to_decode_en <= '1;
            new_data_ready <= '0;
          end
        end
          //Copy from decode buffer to output buffer    
        if(copy_to_decode_en && !copy_out_en) begin
          output_buffer <= decode_buffer;
          copy_to_decode_en <= '0;
          copy_out_en <= '1;
          new_data_ready <= '0;
        end
        //
        if(copy_out_en) begin
          if(match_offset < SEARCH_BUFFER_SIZE) begin
            if((SEARCH_BUFFER_SIZE-1-match_offset_temp <= match_offset) && (match_length > 0)) begin
              data_out <= output_buffer[SEARCH_BUFFER_SIZE-1];
              for (int i = SEARCH_BUFFER_SIZE-1; i >= 1; i = i - 1) begin
                decode_buffer[i] <= decode_buffer[i-1];
              end
              decode_buffer[0] <= output_buffer[SEARCH_BUFFER_SIZE-1];
              match_length <= match_length - 1;
              data_valid <= '1;
            end else begin
              match_offset_temp <= match_offset_temp + 1;
              data_valid <= '0;
            end
            new_data_ready <= '0;
          end else begin
            copy_out_en <= '0;
            decode_en <= '0;
            data_valid <= '0;
            new_data_ready <= '1;
          end
          for (int i = SEARCH_BUFFER_SIZE-1; i >= 1; i = i - 1) begin
            output_buffer[i] <= output_buffer[i-1];
          end
          if(match_length == '0)begin
            for (int i = SEARCH_BUFFER_SIZE-1; i >= 1; i = i - 1) begin
              output_buffer[i] <= '0;
            end
            match_offset_temp <= '0;
            data_valid <= '0;
            copy_out_en <= '0;
            decode_en <= '0;
            new_data_ready <= '1;
            //End of output -> send in new data
          end   
        end   
      end
    end
  end
endmodule
