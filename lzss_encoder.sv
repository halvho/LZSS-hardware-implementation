`timescale 1ns / 1ps
 
import Parameters::*;

module lzss_encoder #(
  parameter SEARCH_BUFFER_DEPTH = 7,
  parameter SEARCH_BUFFER_WIDTH = 8,
  parameter SYMBOL_LENGTH = 8,
  parameter LOOKAHEAD_BUFFER_LENGTH = 8)(
  input logic rst_,
  input logic clk,
  input logic [7:0] data_in,
  input logic data_ready, 
  output logic [23:0] data_out,
  output logic literal,
  output logic new_data_ready,
  output logic data_valid
  );
  
  //Local declarations
  logic [SYMBOL_LENGTH-1:0] search_buffer[SEARCH_BUFFER_DEPTH-1:0][SEARCH_BUFFER_WIDTH-1:0];
  logic [SYMBOL_LENGTH-1:0] lookahead_buffer [LOOKAHEAD_BUFFER_LENGTH-1:0]; 
  logic [SEARCH_BUFFER_DEPTH-1:0][SEARCH_BUFFER_WIDTH-1:0] match_matrix = {SEARCH_BUFFER_DEPTH{{SEARCH_BUFFER_WIDTH{1'b1}}}};    
  logic [15:0] match_offset;
  logic [7:0] match_length;
  logic [7:0] match_length_temp;
    
  logic [7:0] match_length_o;
  logic [15:0] match_offset_o;
    
  int test;
  logic compare_symbol_en;
    
  logic symbol_match;
  logic word_match;
    
    
  logic compare_done = '0;
  logic shift_done = '0;
  logic literal_shift;
  int loop_count;
  int shift_count = LOOKAHEAD_BUFFER_LENGTH;
  logic compare_valid = '0;
    
  int offset_col;
  int offset_row;
  logic test1;
  logic test2;
  logic test3;

  //Enable signals
  logic       compare_en;
  logic       shift_en;
    
    //Instantiations 
//    Priority_encoder #(.WIDTH(SEARCH_BUFFER_WIDTH),
//                       .DEPTH(SEARCH_BUFFER_DEPTH)) prio_enc(
//      .clk            ( clk                ),
//      .rst_           ( rst_               ),
//      .symbol_match   ( symbol_match       ),
//      .in             ( prev_match_matrix  ), // input [SEARCH_BUFFER_DEPTH-1:0][SEARCH_BUFFER_WIDTH-1:0]
//      .row_o          ( offset_row         ), // output  int
//      .col_o          ( offset_col         )  // output int
//    );
    Priority_encoder_comb #(.WIDTH(SEARCH_BUFFER_WIDTH),
                            .DEPTH(SEARCH_BUFFER_DEPTH)) prio_enc_comb(
      .rst_         ( rst_               ),
      .symbol_match ( symbol_match       ),
      .in           ( match_matrix       ), // input [SEARCH_BUFFER_DEPTH-1:0][SEARCH_BUFFER_WIDTH-1:0]
      .row          ( offset_row         ), // output  int
      .col          ( offset_col         )  // output int
    );
    //Definitions


    enum logic [3:0]    {IDLE         = 4'b0001,
                         COMPARE      = 4'b0010,
                         SHIFT        = 4'b0100,
                         XXX          = 'x        } state, next;  
                            
  always_ff @(posedge clk) begin : Search_buffer
    if(!rst_) begin
      for (int i = SEARCH_BUFFER_DEPTH-1; i >= 0; i = i - 1) begin
        for (int j = SEARCH_BUFFER_WIDTH-1; j >= 0; j = j - 1) begin
          search_buffer[i][j] <= 8'hxx;
        end
      end
    end else begin
      if(shift_en) begin
        //Search buffer shift
        for (int i = SEARCH_BUFFER_DEPTH-1; i >= 0 ; i = i - 1) begin   
          for (int j = SEARCH_BUFFER_WIDTH-1; j >= 1; j = j - 1) begin //1 here and assign rightmost col for each row outside loop                
            search_buffer[i][j] <= search_buffer[i][j-1]; //Shift to the left                    
          end
          if(i == 0)begin
            search_buffer[i][0] <= lookahead_buffer[LOOKAHEAD_BUFFER_LENGTH-1]; //Assign output from lookahead_buffer to search_buffer
          end else begin
            search_buffer[i][0] <= search_buffer[i-1][SEARCH_BUFFER_WIDTH-1]; //Boundary - assign LSB from MSB on previous row
          end
        end
      end
    end
  end
    
  always_ff @(posedge clk) begin : Lookahead_buffer
    if(!rst_) begin
      for (int i = LOOKAHEAD_BUFFER_LENGTH-1; i >= 0; i = i - 1) begin
        lookahead_buffer[i]<= 8'hxx;
      end
    end else begin
      if(shift_en || shift_count == 0) begin //Lookahead buffer shift   
        for (int m = LOOKAHEAD_BUFFER_LENGTH-1; m >= 1; m = m - 1 ) begin //Shift to the right -2 pga overflow
          lookahead_buffer[m] <= lookahead_buffer[m-1]; 
        end
        lookahead_buffer[0] <= data_in[7:0];
        for (int i = LOOKAHEAD_BUFFER_LENGTH-1; i >= 0; i = i - 1) begin
          if(!data_ready || lookahead_buffer[i] === 'x)begin
            compare_valid <= '0;
          end else begin
            compare_valid <= '1;
          end
        end
      end
    end
  end
    
    
  always_ff @(posedge clk) begin : Symbol_Match
    if(!rst_)begin
      match_matrix <= {SEARCH_BUFFER_DEPTH{{SEARCH_BUFFER_WIDTH{1'b1}}}};
      match_length <= '0;
    end else begin
      test <= '0;
      if(compare_en && !compare_done) begin     
           //Corner case - first symbol of search buffer
        if(match_length == 8'b0) begin
          if(search_buffer[SEARCH_BUFFER_DEPTH-1][SEARCH_BUFFER_WIDTH-1] == lookahead_buffer[LOOKAHEAD_BUFFER_LENGTH-1]) begin
            match_matrix[SEARCH_BUFFER_DEPTH-1][SEARCH_BUFFER_WIDTH-1] <= '1;
          end else begin
            match_matrix[SEARCH_BUFFER_DEPTH-1][SEARCH_BUFFER_WIDTH-1] <= '0; 
          end
        end else begin
            match_matrix[SEARCH_BUFFER_DEPTH-1][SEARCH_BUFFER_WIDTH-1] <= '0;
        end
        for(int i = SEARCH_BUFFER_DEPTH-1; i >= 0; i = i - 1) begin : rows //create parallel comparators
          for(int j = SEARCH_BUFFER_WIDTH-2; j >= 0; j = j - 1) begin : cols              
            //Corner case - Last row
            if((match_matrix[0][j+1] == 1'b1)) begin //Masking registers 
              if(search_buffer[0][j] == lookahead_buffer[LOOKAHEAD_BUFFER_LENGTH-1-match_length]) begin  //To avoid underflow
                match_matrix[0][j] <= '1;
              end else if(search_buffer[0][j] != lookahead_buffer[LOOKAHEAD_BUFFER_LENGTH-1-match_length]) begin 
                match_matrix[0][j] <= '0;
              end   
            end else begin
              match_matrix[i][j] <= '0;
            end
            if((match_matrix[i][j+1] == 1'b1)) begin  
              if(search_buffer[i][j] == lookahead_buffer[LOOKAHEAD_BUFFER_LENGTH-1-match_length]) begin
                match_matrix[i][j] <= '1;
              end else if(search_buffer[i][j] != lookahead_buffer[LOOKAHEAD_BUFFER_LENGTH-1-match_length]) begin 
                match_matrix[i][j] <= '0;
              end   
            end else begin
              match_matrix[i][j] <= '0;
            end
          end : cols
          //Boundary condition - if last symbol on prev row is match, first symbol on next row is checked
          if(i != 0)begin
            if((match_matrix[i][0] == 1'b1)) begin 
              if(search_buffer[i-1][SEARCH_BUFFER_WIDTH-1] == lookahead_buffer[LOOKAHEAD_BUFFER_LENGTH-1-match_length] && i != 0) begin
                match_matrix[i-1][SEARCH_BUFFER_WIDTH-1] <= '1;
              end else begin
                match_matrix[i-1][SEARCH_BUFFER_WIDTH-1] <= '0;
              end
            end else begin
              match_matrix[i-1][SEARCH_BUFFER_WIDTH-1] <= '0;
            end
          end
        end : rows
        compare_symbol_en <= '1;
        match_length <= match_length + 1; 
        if(match_length <= LOOKAHEAD_BUFFER_LENGTH && match_matrix != {SEARCH_BUFFER_DEPTH{{SEARCH_BUFFER_WIDTH{1'b0}}}}) begin//Add match_length <= SEARCH_BUFFER_LENGTH
          match_length_temp <= match_length;
          if(offset_col-(match_length+1) >= 0) begin 
            match_offset <= offset_row*SEARCH_BUFFER_WIDTH + offset_col-match_length+1;
          end else begin //Match starts on previous row
            match_offset <= (offset_row-1)*SEARCH_BUFFER_WIDTH + (SEARCH_BUFFER_WIDTH-offset_col-match_length+1);
          end 
        end     
      end else begin
        match_matrix <= {SEARCH_BUFFER_DEPTH{{SEARCH_BUFFER_WIDTH{1'b1}}}};
        compare_symbol_en <= '0;
        match_length <= '0;
      end
    end
  end

always_ff @(posedge clk) begin
    if(!rst_)begin
        symbol_match <= '0;
        word_match <= '0;
        match_length_o <= '0;
        shift_count <= LOOKAHEAD_BUFFER_LENGTH+1;
    end else begin
        symbol_match <= '1;//Needs to be active by default to so that first compare is not auto discarded 
        word_match <= '0;
        if(compare_en && compare_symbol_en) begin
            if((match_matrix != {SEARCH_BUFFER_DEPTH{{SEARCH_BUFFER_WIDTH{8'h00}}}})&& match_length < LOOKAHEAD_BUFFER_LENGTH) begin//prev_match_row 
              symbol_match <= '1;
            end else begin
               if(symbol_match == '1) begin
                   shift_count <= match_length_temp+1; //Update with last matching symbol
                   if((8'd3 < match_length_temp) && (match_length_temp < SEARCH_BUFFER_WIDTH)) begin
                       word_match <= '1;
                       if(match_length == LOOKAHEAD_BUFFER_LENGTH) begin
                           match_length_o <= match_length_temp+1; //Match_length gives previous match here
                       end else begin
                           match_length_o <= match_length_temp;
                       end
                       match_offset_o <= match_offset;
                   end else begin
                       word_match <= '0;   
                   end
               end
               symbol_match <= '0;
            end
        end else begin
        end

    end
end            
   
    always_ff @(posedge clk)
    if (!rst_) state <= IDLE;
    else       state <= next; 
    
    always_comb begin //State transitions
        next = XXX;
        case (state)
         IDLE : begin 
            if (compare_valid && data_ready)                    next = COMPARE;
            else if (!compare_valid && data_ready)              next = SHIFT;
            else                                                next = IDLE;
         end
         COMPARE : begin
            if (compare_done && data_ready)                     next = SHIFT;
            else if(!data_ready)                                next = IDLE;
            else                                                next = COMPARE;
         end
         SHIFT : begin
            if (compare_valid && shift_done)                    next = COMPARE;
            else if (!data_ready)                               next = IDLE;
            else                                                next = SHIFT;
         end
         default : begin                                        next = XXX; // Fault Recovery 
         end
        endcase
    end
    
    
    always_ff @(posedge clk)//Actions done inside state
        if (!rst_) begin
        shift_en <= '0;
        end
        else begin
        //data_out_reg <= 'x;
        case (next)
         IDLE: begin //Set enable signals to 0. If reset go to IDLE state
            shift_en <= '0;
            compare_en <= '0;
            data_valid <= '0;
            shift_done <= '0;
            //compare_done <= '0;
         end //Set output
         COMPARE: begin
            shift_en <= '0;
            shift_done <= '0;
            compare_en <= '1;
            compare_done <= '0;
            test1 <= '0;
            test2 <= '0;
            test3 <= '0;
            if(!symbol_match && compare_symbol_en /*match_length != '0*/)begin
 
                if(word_match) begin                   
                    data_out[23:0] <= {match_length_o,match_offset_o};
                    literal <= '0;                    
                    test1 <= '1;
                end else begin
                    data_out[23:0] <= {15'b000000000000000,lookahead_buffer[LOOKAHEAD_BUFFER_LENGTH-1]};//Needs to general for symbol_length
                    literal <= '1;  
                    test2 <= '1;       
                end
                compare_done <= '1;
                data_valid <= '1; 
            end else begin //This might be redundant
                compare_done <= '0;
                data_valid <= '0;
                test3 <= '1;
            end
         end
         SHIFT: begin            
            compare_en <= '0;
            compare_done <= '0;
            shift_en <= '1;
            shift_done <= '0;
            data_valid <= '0;
            new_data_ready <= '1;
            if((shift_count > 3) && (loop_count < shift_count)) begin
                loop_count <= loop_count + 1; 
            end else if((shift_count <= 3) && literal_shift) begin
                literal_shift <= '0;
            end else begin
                shift_en <= '0;
                shift_done <= '1;
                loop_count <= '0;
                literal_shift <= '1;
                new_data_ready <= '0;
            end
         end
         default: begin //Fault Recovery
            data_out <= 'x;
            literal <= 'x;
         end
        endcase
     end
endmodule
