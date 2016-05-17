package L2_types_d;
 import riscv_types::*;

 typedef enum {Load,Store} Access_type_d deriving(Bits,Eq,FShow);

 typedef struct{
    Bit#(l2_addr_width) address; // 32 bit address.
    Bit#(2) transfer_size; // 0-8 bits. 1-16 bits. 2-32 bits 3-64 bits.
    Bit#(1) cache_enable; // 0 cache disabled 1 cache enabled.
    Access_type_d ld_st; // 0- read 1-write
    Bit#(TMul#(8,l2_word_size)) write_data; // 32 bit data to be written 
  }From_l1_d#(numeric type l2_addr_width,numeric type l2_word_size) deriving(Bits,Eq);
  
 typedef struct{
    Access_type_d ld_st;
    Bit#(TMul#(8,TMul#(l2_word_size,l2_block_size))) data_line;
    Bit#(TMul#(8,l2_word_size)) write_data;
    Bit#(TLog#(TMul#(8,TMul#(l2_word_size,l2_block_size)))) upper_offset;
    Bit#(TLog#(TMul#(8,TMul#(l2_word_size,l2_block_size)))) lower_offset;
    Bit#(2) transfer_size;
    Bit#(TLog#(l2_ways)) replace_block;
    Bit#(l2_addr_width) address;
  }Hit_structure_d#(numeric type l2_addr_width,numeric type l2_word_size,numeric type l2_block_size,numeric type l2_ways) deriving(Bits,Eq);
 
 typedef struct{
    Bit#(TMul#(l2_word_size,8)) data_word;
    Bit#(1) bus_error;
    Bit#(1) mis_aligned_error;
    Bit#(l2_addr_width) address;
  }To_l1_d#(numeric type l2_addr_width, numeric type l2_word_size) deriving(Bits,Eq);

 typedef struct{
    Bit#(l2_addr_width) address;
    Bit#(2) transfer_size;
    Bit#(3) burst_mode;
    Access_type_d ld_st;
    Bit#(TLog#(l2_ways)) replace_block;
    Bit#(TMul#(8,l2_word_size)) write_data;
  } To_Memory_d#(numeric type l2_addr_width,numeric type l2_word_size,numeric type l2_block_size, numeric type l2_ways) deriving(Bits,Eq);

  typedef struct{
    Bit#(TMul#(8,TMul#(l2_word_size,l2_block_size))) data_line;
    Bit#(1) bus_error;
    Bit#(l2_addr_width) address;
    Bit#(TLog#(l2_ways)) replace_block;
  }From_Memory_d#(numeric type l2_addr_width, numeric type l2_word_size, numeric type l2_block_size, numeric type l2_ways) deriving(Bits,Eq);

 typedef struct{
    Bit#(l2_addr_width) address;
    Bit#(TMul#(8,TMul#(l2_word_size,l2_block_size))) data_line;
    Bit#(2) transfer_size;
    Bit#(3) burst_mode;
  }WriteBack_structure_d#(numeric type l2_addr_width,numeric type l2_word_size, numeric type l2_block_size) deriving(Bits,Eq);

endpackage

