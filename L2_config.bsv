


package L2_config;
  
  interface Ifc_l2_config#(numeric type l2_addr_width, numeric type l2_block_size, numeric type l2_word_size)
	method Action get_addr(Bit#(l2_addr_width), Bit#(8));
	method ActionValue#(Bit#(8)) send_bank_id();
  endinterface
   
  module mkl2config(Ifc_l2_config#(l2_addr_width, l2_block_size, l2_word_size))
  	provisos(
		Log#(l2_word_size,log_word_size),
		Log#(l2_block_size,log_block_size),
		Add#(intermediate2,log_sets,l2_addr_width),
		Add#(intermediate3,log_word_size,intermediate2),
		Add#(num_of_tag_bits,log_block_size,intermediate3),
		Add#(log_word_size,log_block_size,num_of_offset_bits),
  		Add#(a1,l2_word_size,8),
    	Add#(c__, 16, TMul#(8, TMul#(l2_word_size, l2_block_size))),
    	Add#(d__, 64, TMul#(8, TMul#(l2_word_size, l2_block_size))),
    	Add#(e__, 32, TMul#(8, TMul#(l2_word_size, l2_block_size))),
    	Add#(f__, 8, TMul#(8, TMul#(l2_word_size, l2_block_size))),
    	Add#(a__, TMul#(l2_word_size, 8), TMul#(8, TMul#(l2_word_size, l2_block_size))),
    	Add#(b__, 1, TSub#(l2_addr_width, TAdd#(TLog#(l2_block_size),TLog#(l2_word_size))))
	);
	
	let v_num_of_offset_bits = valueOf(num_of_offset_bits);
	let v_addr_width = valueOf(l2_addr_width);
	
	Reg#(Bit#(8)) i <- mkReg(0);
	Reg#(Bit#(2)) flag <- mkReg(0);
	Reg#(Bit#(l2_addr_width) addr <- mkReg(0);

	rule findid(flag==1 && i>0);
		if(addr[v_addr_width-1:v_num_of_offset_bits]%zeroExtend(i) == 0)
			flag <= 2;
		i <= i-1;
	endrule
	
	method Action get_addr(Bit#(l2_addr_width) address, Bit#(8) num_of_banks) if(flag==0);
		i = num_of_banks;
		addr = address;
		flag = 1;
	endmethod
	
	method ActionValue#(Bit#(8)) send_bank_id() if(flag==2);
		return i;
	endmethod
	
  endmodule
endpackage
		
		
		
		
		
		
  
  
