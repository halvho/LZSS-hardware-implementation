//////////////////////////////////////////////////////////////////////////////////
// Testbench for LZSS encode module
////////////////////////////////////////////////////////////////////////////////// 
`timescale 1ns / 1ps

import Parameters::*;

module lzss_encoder_tb;

 logic clk;
 logic rst_;
 logic [SYMBOL_LENGTH-1:0] data_in;
 logic [3*SYMBOL_LENGTH-1:0] data_out;
 logic literal;
 logic data_ready;
 
 logic data_valid;
 logic new_data_ready;
 
 int TbErrorCnt;

  initial clk = 0;
  always #10 clk = ~clk;

logic [7:0]                  c;
byte                         data_in_q[$];
logic [3*SYMBOL_LENGTH-1:0]  data_out_q[$];
logic                        literal_flag_q[$];
int                          i;
int                          fd_in;
real                         uncoded_symbol_num;
 initial begin    
    
    //Read file a char at a time
    fd_in = $fopen("C:/Users/hal_v/OneDrive/NTNU/Master/Master_thesis/Master/calgarycorpus/bib","rb");
    c = $fgetc(fd_in);
    while (!$feof(fd_in)) begin
        data_in_q.push_back(c);
        //$display("Got char num[%0d] 0x%0h", i++, c);
        c = $fgetc(fd_in);
        uncoded_symbol_num++;
    end
    $display("End of file");
    $display("Uncompressed file size: %d kB",uncoded_symbol_num/1000);
    $fclose(fd_in);
 end
 
class Packet #(parameter SYMBOL_LENGTH = 8);
    rand bit [SYMBOL_LENGTH-1:0] data;
endclass

 Packet pkt = new ();
 

 initial begin
 
 rst_ <= '0;
 #100;
 rst_ <= '1;
 data_ready <= '1;
while(data_in_q.size() != 0)begin   
    //Insert new input data from queue
    if(new_data_ready)begin
       //data_in <= pkt.data;
       data_in <= data_in_q.pop_front();       
    end
   
    //Write output data to queue 
    if(data_valid)begin
        data_out_q.push_back(data_out);
        literal_flag_q.push_back(literal);
    end
    @(posedge clk);
    //$display("Queue size: %d", data_in_q.size());
end
$display("End of input stream");
data_ready <= '0;
$finish;
end 
// always @(posedge clk) begin
//     pkt.randomize();
     


// end 
 int fd_out;
 int fd_literal_flag;
 real encoded_symbol_num;
 final begin
     //Write to file
     fd_out = $fopen("C:/Users/hal_v/OneDrive/NTNU/Master/Master_thesis/Master/calgarycorpus/bib_encoded","w");
     fd_literal_flag = $fopen("C:/Users/hal_v/OneDrive/NTNU/Master/Master_thesis/Master/calgarycorpus/bib_encoded_literal_flag","w");
     while (data_out_q.size != 0) begin
         $fwrite(fd_out,"%b\n",data_out_q.pop_front());
         $fwrite(fd_literal_flag,"%b\n",literal_flag_q.pop_front());
         encoded_symbol_num++;
     end
     $fclose(fd_out);
     $fclose(fd_literal_flag);
     $display("End of test program");
     $display("Uncompressed file size: %d kB",uncoded_symbol_num/1000);
     $display("Compressed file size: %d kB",encoded_symbol_num/1000);
     $display("Compression ratio: %4.2f", uncoded_symbol_num*8/(encoded_symbol_num*8+encoded_symbol_num)); //Uncoded symbols in bits/encoded symbols in bits + literal flags
     $display("Compression percentage: %f4.2", (encoded_symbol_num*8+encoded_symbol_num)/uncoded_symbol_num);
     
 end
 
 //DUT
 lzss_encoder dut_lzss_encoder (
 .clk            (clk),             //Input
 .rst_           (rst_),            //Input
 .data_in        (data_in),         //Input
 .data_ready     (data_ready),      //Input
 .data_out       (data_out),        //Output
 .literal        (literal),         //Output
 .data_valid     (data_valid),      //Output
 .new_data_ready (new_data_ready)   //Output
 );
 
endmodule
