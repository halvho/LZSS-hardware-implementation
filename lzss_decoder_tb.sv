`timescale 1ns / 1ps 
//////////////////////////////////////////////////////////////////////////////////
// Testbench for LZSS decode module
//////////////////////////////////////////////////////////////////////////////////
import Parameters::*;

module lzss_decoder_tb;
    
    logic clk;
    logic rst_;
    logic [3*SYMBOL_LENGTH-1:0] data_in;
    logic [SYMBOL_LENGTH-1:0] data_out;
    logic literal;
    logic data_ready;
    
    logic data_valid;
    logic new_data_ready;
      
    
 initial clk = 0;
 always #10 clk = ~clk;

logic [3*SYMBOL_LENGTH-1:0] data_in_q[$];
logic [3*SYMBOL_LENGTH-1:0] data_in_temp;
byte      data_out_q[$];
logic     literal_flag_q[$];
logic  literal_sym;

int      fd_in;
int      fd_literal_flag;
real     uncoded_symbol_num;
real     literal_symbol;
integer i;
  initial begin    
     
     //Read encoded file
     fd_in = $fopen("C:/Users/hal_v/OneDrive/NTNU/Master/Master_thesis/Master/calgarycorpus/bib_encoded","r");
     $fscanf(fd_in,"%b",data_in_temp);
     while (!$feof(fd_in)) begin
         data_in_q.push_back(data_in_temp);
         //$display("Got char num[%0d] 0x%0h", i++, data_in_temp);
         $fscanf(fd_in,"%b",data_in_temp);
         uncoded_symbol_num++;
     end
     $fclose(fd_in);
     //Read literal flags
     fd_literal_flag = $fopen("C:/Users/hal_v/OneDrive/NTNU/Master/Master_thesis/Master/calgarycorpus/bib_encoded_literal_flag","r");
     $fscanf(fd_literal_flag,"%b",literal_sym);
     while (!$feof(fd_literal_flag)) begin
        literal_flag_q.push_back(literal_sym);
        $fscanf(fd_literal_flag,"%b",literal_sym);
        literal_symbol++;
     end
     $display("End of file");
     $display("Compressed file size: %d kB",uncoded_symbol_num/1000);
     $display("Data_in queue size: %d",data_in_q.size());
     $display("Literal queue size: %d",literal_flag_q.size());
     $fclose(fd_literal_flag);
  end
    
initial begin
     
 rst_ <= '0;
 #100;
 rst_ <= '1;
 data_ready <= '1;
  while(data_in_q.size() != 0)begin   
      //Insert new input data from queue
      if(new_data_ready)begin
         data_in <= data_in_q.pop_front();
         literal <= literal_flag_q.pop_front();
      end
   
      //Write output data to queue 
      if(data_valid)begin
          data_out_q.push_back(data_out);
      end
      @(posedge clk);
      //$display("Queue size: %d", data_in_q.size());
  end
  $display("End of input stream");
  data_ready <= '0;
  $finish;
end
    
    
 int fd_out;
 real encoded_symbol_num;
 final begin
     //Write to file
     fd_out = $fopen("C:/Users/hal_v/OneDrive/NTNU/Master/Master_thesis/Master/calgarycorpus/bib_decoded","w");
     while (data_out_q.size != 0) begin
         $fwrite(fd_out,"%s",data_out_q.pop_front());
         encoded_symbol_num++;
     end
     $fclose(fd_out);
     
 end   
    
    
    //DUT
    lzss_decoder dut_lzss_decoder (
    .clk            (clk),             //Input
    .rst_           (rst_),            //Input
    .data_in        (data_in),         //Input
    .data_ready     (data_ready),      //Input
    .data_out       (data_out),        //Output
    .literal        (literal),         //Input
    .data_valid     (data_valid),      //Output
    .new_data_ready (new_data_ready)   //Output
    );
    
    
    
endmodule
