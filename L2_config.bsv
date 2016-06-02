/*
Top module for the L2 cache. Configures the number of banks and their corresponding transactions. No of banks can be changed in teh Testbench predirective
*/


package L2_config;

  import L2bank::*;
  import L2_types_d::*;
  import FIFO::*;
  import FIFOF::*;
  import SpecialFIFOs::*;
  import Vector::*;
  //import Main_mem::*;
  
  interface Ifc_l2_config#(numeric type l2_addr_width, numeric type l2_ways, numeric type l2_word_size, numeric type l2_block_size, numeric type l2_sets, numeric type num_of_banks);
	method Action request_from_l1 (From_l1_d#(l2_addr_width,l2_word_size) req);
	method ActionValue#(To_l1_d#(l2_addr_width,l2_word_size)) response_to_l1;
	method ActionValue#(To_Memory_d#(l2_addr_width,l2_word_size,l2_block_size)) request_to_memory;
	method Action response_from_memory(From_Memory_d#(l2_addr_width,l2_word_size,l2_block_size) resp);
  endinterface
  
   
  module mkl2config(Ifc_l2_config#(l2_addr_width, l2_ways, l2_word_size, l2_block_size, l2_sets, num_of_banks))
  	provisos(
		Log#(l2_word_size,log_word_size),
		Log#(l2_block_size,log_block_size),
		Add#(log_word_size,log_block_size,num_of_offset_bits),
		Add#(3,num_of_offset_bits,word_addr_width),
		Add#(remaining_bits,word_addr_width,l2_addr_width),
  		Add#(a1,l2_word_size,8),
    	Add#(c__, 16, TMul#(8, TMul#(l2_word_size, l2_block_size))),
    	Add#(d__, 64, TMul#(8, TMul#(l2_word_size, l2_block_size))),
    	Add#(e__, 32, TMul#(8, TMul#(l2_word_size, l2_block_size))),
    	Add#(f__, 8, TMul#(8, TMul#(l2_word_size, l2_block_size))),
    	Add#(g__, 8, remaining_bits),
    	Add#(h__, log_block_size, i__),
    	Add#(i__, log_word_size, j__),
    	Add#(j__, TLog#(l2_sets), l2_addr_width),
    	Add#(k__, TMul#(8, TMul#(l2_word_size, l2_block_size)), 256),
    	Add#(a__, TMul#(l2_word_size, 8), TMul#(8, TMul#(l2_word_size, l2_block_size))),
    	Add#(b__, 1, TSub#(l2_addr_width, TAdd#(TLog#(l2_block_size),TLog#(l2_word_size))))
	);
	
	Vector#(num_of_banks, Ifc_l2_bank#(l2_addr_width,l2_ways,l2_word_size,l2_block_size,l2_sets)) l2bank; 
   	for (Bit#(8) i=0; i<fromInteger(valueOf(num_of_banks)); i=i+1) 
    		l2bank[i] <- mkl2bank(i);
	
	let v_block_addr_width = valueOf(num_of_offset_bits)+3;
	let v_addr_width = valueOf(l2_addr_width);
	
	Vector#(num_of_banks, FIFO#(From_l1_d#(l2_addr_width,l2_word_size))) ff_request_from_l1; 
   	for (Bit#(8) i=0; i<fromInteger(valueOf(num_of_banks)); i=i+1) 
    		ff_request_from_l1[i] <- mkFIFO1();
	
	FIFO#(To_l1_d#(l2_addr_width,l2_word_size)) ff_response_to_l1 <- mkFIFO1();
	FIFO#(To_Memory_d#(l2_addr_width,l2_word_size,l2_block_size)) ff_request_to_memory <- mkFIFO1();
	FIFO#(From_Memory_d#(l2_addr_width,l2_word_size,l2_block_size)) ff_response_from_memory <- mkFIFO1();
	Reg#(Bool) rg_mem_call <- mkReg(False);
	FIFO#(Bit#(8)) ff_mem_token <- mkFIFO1();
	
	//To calculate the bank index in which the given address is stored
	//Done in a way so as to facilitate interleaving
	//Interleaving -> Consecutive blocks of main memory are stored in consecutive banks
	function Bit#(8) find_bank_index(Bit#(l2_addr_width) addr);
		Bool flag = True;
		Bit#(remaining_bits) i = fromInteger(valueOf(num_of_banks));
		while(flag == True)
		begin
			if(addr[v_addr_width-1:v_block_addr_width]%i == 0)
				flag = False;
			i = i-1;
		end
		Bit#(8) j = truncate(i);
		return j;
	endfunction
	//
	
	//Rules for 4 different transactions
	
	for(Bit#(8) i=0; i<fromInteger(valueOf(num_of_banks)); i=i+1) begin
		rule request_to_l2;
			let x = ff_request_from_l1[i].first();
			ff_request_from_l1[i].deq();
			l2bank[i].request_from_l1(x);
		endrule
	end
	
	for(Bit#(8) i=0; i<fromInteger(valueOf(num_of_banks)); i=i+1) begin
		rule response_from_l2;
			let x <- l2bank[i].response_to_l1;
			ff_response_to_l1.enq(x);
		endrule
	end

	for(Bit#(8) i=0; i<fromInteger(valueOf(num_of_banks)); i=i+1) begin
		rule request_memory;
			let x <- l2bank[i].request_to_memory;
			ff_request_to_memory.enq(x);
			ff_mem_token.enq(i);
		endrule
	end
	
	for(Bit#(8) i=0; i<fromInteger(valueOf(num_of_banks)); i=i+1) begin
		rule response_memory(ff_mem_token.first()==i);
			let x = ff_response_from_memory.first();
			ff_response_from_memory.deq();
			ff_mem_token.deq();
			$display("Forwarding response_from_memory to bank %d",i);
			l2bank[i].response_from_memory(x);
		endrule
	end

	method Action request_from_l1 (From_l1_d#(l2_addr_width,l2_word_size) req);
		let k = find_bank_index(req.address);
		$display("Index for address %h is %d",req.address,k);
		ff_request_from_l1[k].enq(req);
	endmethod
	
	method ActionValue#(To_l1_d#(l2_addr_width,l2_word_size)) response_to_l1;
		let x = ff_response_to_l1.first();
		ff_response_to_l1.deq();
		return x;
	endmethod
	
	method ActionValue#(To_Memory_d#(l2_addr_width,l2_word_size,l2_block_size)) request_to_memory;
		//$display("Forwarding request_to_memory");
		rg_mem_call <= True;
		ff_request_to_memory.deq();
		return ff_request_to_memory.first();
	endmethod
	
	method Action response_from_memory(From_Memory_d#(l2_addr_width,l2_word_size,l2_block_size) resp);
	      	ff_response_from_memory.enq(resp);
	endmethod
    
  endmodule
endpackage
		
		
		
		
		
		
  
  
