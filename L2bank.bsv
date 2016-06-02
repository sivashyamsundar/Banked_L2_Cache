/*
This is a blocking and non pipelined L2 Cache bank. It will be instantiated a given N number of times as a N bank L2 cahce system. The PLRU, function to find different segments of the address and to update data line have been directly implemented from the non-blocking L1 Cache design.
*/

package L2bank;
  import L2_types_d::*;
  import ClientServer ::*;
  import GetPut       ::*;
  import Connectable  ::*;
  import FIFO ::*;
  import FIFOF ::*;
  import SpecialFIFOs :: * ;
  import BRAM::*;
  import ConfigReg::*;
  import Vector::*;

  interface Ifc_l2_bank#(numeric type l2_addr_width, numeric type l2_ways, numeric type l2_word_size, numeric type l2_block_size, numeric type sets);
    method Action request_from_l1(From_l1_d#(l2_addr_width,l2_word_size) req);
    method ActionValue#(To_l1_d#(l2_addr_width,l2_word_size)) response_to_l1;
    method ActionValue#(To_Memory_d#(l2_addr_width,l2_word_size,l2_block_size)) request_to_memory;
    method Action response_from_memory(From_Memory_d#(l2_addr_width,l2_word_size,l2_block_size) resp);
    //method ActionValue#(Hit_miss_d) hit_miss;
    method ActionValue#(WriteBack_structure_d#(l2_addr_width,l2_word_size,l2_block_size)) write_back_data();
    method Action clear_all();
  endinterface

 module mkl2bank#(Bit#(8) n)(Ifc_l2_bank#(l2_addr_width,l2_ways,l2_word_size,l2_block_size,l2_sets))
	provisos(
		Log#(l2_word_size,log_word_size),
		Log#(l2_block_size,log_block_size),
		Log#(l2_sets,log_sets),
		Add#(intermediate2,log_sets,l2_addr_width),
		Add#(intermediate3,log_word_size,intermediate2),
		Add#(num_of_tag_bits,log_block_size,intermediate3),
		Add#(log_word_size,log_block_size,num_of_offset_bits),
  		Add#(a1,l2_word_size,8),			    //to limit the word_size that user inputs to max. of 8 bytes (or doubleword)
    	Add#(c__, 16, TMul#(8, TMul#(l2_word_size, l2_block_size))),
    	Add#(d__, 64, TMul#(8, TMul#(l2_word_size, l2_block_size))),
    	Add#(e__, 32, TMul#(8, TMul#(l2_word_size, l2_block_size))),
    	Add#(f__, 8, TMul#(8, TMul#(l2_word_size, l2_block_size))),
    	Add#(a__, TMul#(l2_word_size, 8), TMul#(8, TMul#(l2_word_size, l2_block_size))),
    	Add#(b__, 1, TSub#(l2_addr_width, TAdd#(TLog#(l2_block_size),TLog#(l2_word_size))))
);
    let v_log_sets=valueOf(log_sets);
    let v_ways=valueOf(l2_ways);
    let v_sets=valueOf(l2_sets);
    let v_num_of_tag_bits=valueOf(num_of_tag_bits);
    let v_num_of_offset_bits=valueOf(num_of_offset_bits);
    let v_word_size=valueOf(l2_word_size);
    let v_block_size=valueOf(l2_block_size);
    let v_addr_width=valueOf(l2_addr_width);
    let v_num_of_bytes=valueOf(TLog#(l2_word_size)); // number of bits to represent each byte in a word
    
    //Function to find the offset index to locate the required word in a block
    function Tuple2#(Bit#(TLog#(TMul#(8,TMul#(l2_word_size,l2_block_size)))),Bit#(TLog#(TMul#(8,TMul#(l2_word_size,l2_block_size))))) find_offset_index(Bit#(2) transfer_size, Bit#(l2_addr_width) cpu_addr);  
    	let v_word_size = valueOf(l2_word_size);
    	Bit#(TLog#(TMul#(8,TMul#(l2_word_size,l2_block_size)))) lower_offset=0;
    	Bit#(TLog#(TMul#(8,TMul#(l2_word_size,l2_block_size)))) upper_offset=0;
    	for(Integer i=0; i<v_block_size; i=i+1)
    	begin
      		if(fromInteger(i)==unpack(cpu_addr[v_num_of_offset_bits-1:v_num_of_bytes]))
      		begin 
        		lower_offset= fromInteger(v_word_size)*8*fromInteger(i);
      		end
    	end
    	lower_offset=lower_offset+(cpu_addr[v_num_of_bytes-1:0]*8); // exact byte offset to start the transaction from.
      	if(transfer_size=='b00) // one byte (8 bits)
          	upper_offset=lower_offset+7;
      	else if (transfer_size=='b01) // 2 bytes (16 bits)
          	upper_offset=lower_offset+15;
      	else if(transfer_size=='b10) // 4 bytes (32 bits)
          	upper_offset=lower_offset+31;
      	else if(transfer_size=='b11) // 8 bytes (64 bits)
          	upper_offset=lower_offset+63;
    	return tuple2(upper_offset,lower_offset);
  	endfunction
  	
  	//Function to update the entire block with the given word
  	function Bit#(TMul#(8,TMul#(l2_word_size,l2_block_size))) update_data_line (Bit#(TLog#(TMul#(8,TMul#(l2_word_size,l2_block_size)))) lower_offset, Bit#(TLog#(TMul#(8,TMul#(l2_word_size,l2_block_size)))) upper_offset, Bit#(2) transfer_size, Bit#(TMul#(8,TMul#(l2_word_size,l2_block_size))) data, Bit#(TMul#(8,l2_word_size)) write_data);
      Bit#(lower_offset) y = data[lower_offset-1:0];
      let x= data[fromInteger(8*v_word_size*v_block_size-1):upper_offset+1];
      Bit#(8) temp1= write_data[upper_offset-lower_offset:0];
      Bit#(16) temp2=write_data[upper_offset-lower_offset:0];
      Bit#(32) temp3=write_data[upper_offset-lower_offset:0];
      Bit#(64) temp4=write_data[upper_offset-lower_offset:0];
      Bit#(TMul#(8,TMul#(l2_word_size,l2_block_size))) new_data=0;
      if(transfer_size==0)
          new_data={x,temp1};
      else if(transfer_size==1)
          new_data={x,temp2};
      else if(transfer_size==2)
          new_data={x,temp3};
      else if(transfer_size==3)
          new_data={x,temp4};
      new_data=new_data << lower_offset;
      new_data=new_data|y;
      return new_data;
  endfunction

	//General FIFO declarations for all the 4 types of transactions 
	FIFO#(From_l1_d#(l2_addr_width,l2_word_size)) ff_request_from_l1 <- mkFIFO1();
	FIFO#(Hit_structure_d#(l2_addr_width,l2_word_size,l2_block_size,l2_ways)) ff_response_to_l1 <-mkPipelineFIFO(); //To silence some conflicts
	FIFO#(To_Memory_d#(l2_addr_width,l2_word_size,l2_block_size)) ff_request_to_memory <-mkFIFO1();
    FIFO#(From_Memory_d#(l2_addr_width,l2_word_size,l2_block_size)) ff_response_from_memory <-mkFIFO1();
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
	FIFO#(Hit_structure_d#(l2_addr_width,l2_word_size,l2_block_size,l2_ways)) ff_write_to_bram <-mkFIFO1(); //For internal transaction for Store
	FIFO#(WriteBack_structure_d#(l2_addr_width,l2_word_size,l2_block_size)) ff_write_back_queue <-mkFIFO1(); //FIFO for write back data
	FIFO#(Metadata_miss_d#(l2_addr_width,l2_word_size,l2_block_size,l2_ways)) ff_metadata_miss <-mkFIFO1(); //For metadata transfer after a miss
	
	Reg#(Bit#(3)) rg_burst_mode <-mkReg(v_block_size==4?'b011:v_block_size==8?'b101:v_block_size==16?'b111:0);
	Reg#(Bool) rg_initialize <-mkReg(True);
	Reg#(Bit#(TAdd#(1,TLog#(l2_sets)))) rg_index <-mkReg(0);

	//BRAM declaration + configuration
	BRAM_Configure cfg = defaultValue ;
    cfg.latency=1;
    cfg.outFIFODepth=2;
    cfg.allowWriteResponseBypass=True;
		BRAM2Port#(Bit#(TLog#(l2_sets)), Bit#(num_of_tag_bits)) tag [v_ways]; 
		BRAM2Port#(Bit#(TLog#(l2_sets)), Bit#(2)) valid_dirty [v_ways]; 
		BRAM2Port#(Bit#(TLog#(l2_sets)), Bit#(TMul#(8,TMul#(l2_word_size,l2_block_size)))) data [v_ways];
	/////////////////////////////////////////////////////////////////////////////////////////////////////
		
	Reg#(Bit#(TSub#(l2_ways,1))) pseudo_lru [v_sets];
	for(Integer i=0;i<v_sets;i=i+1)
		pseudo_lru[i]<-mkReg(0);

	for(Integer i=0;i<v_ways;i=i+1)begin
		tag[i] <- mkBRAM2Server(cfg);		
		data[i] <- mkBRAM2Server(cfg);
		valid_dirty[i]<-mkBRAM2Server(cfg);
	end

	rule initialize_cache(rg_initialize);
      rg_index <= rg_index+1;
      for(Integer i=0; i<v_ways; i=i+1)
        valid_dirty[i].portB.request.put(BRAMRequest{write:True,address:truncate(rg_index), datain:0,responseOnWrite:False});
      if(rg_index==fromInteger(v_sets-1))
        rg_initialize <= False;
      //$display("Flushing Cache %d",n,$time);
    endrule
    
    //Rule 1: To be executed as soon as a request is received in the ff_request_from_l1 FIFO.
    //In case of HIT: It transfers the data to ff_response_to_l1 FIFO
    //In case of MISS: It transfers the data to the request_to_memory FIFO
    rule execute_request(!rg_initialize);
    	Bit#(num_of_tag_bits) tag_values[v_ways];
		Bit#(2) valid_dirty_values [v_ways];
		Bit#(TMul#(8,TMul#(l2_word_size,l2_block_size))) data_values [v_ways];
    	Bit#(TSub#(l2_addr_width,num_of_offset_bits)) input_tag = ff_request_from_l1.first.address[v_addr_width-1:v_num_of_offset_bits];
      	Bit#(l2_addr_width) line_address = zeroExtend(input_tag)<<v_num_of_offset_bits;
      	Bit#(l2_addr_width) address = ff_request_from_l1.first.address;
		for(Integer i=0; i<v_ways; i=i+1)
		begin
			valid_dirty_values[i] <- valid_dirty[i].portA.response.get();
			tag_values[i] <- tag[i].portA.response.get();
			data_values[i] <- data[i].portA.response.get();
		end
		let cpu_addr = ff_request_from_l1.first.address;
      	let transfer_size = ff_request_from_l1.first.transfer_size;
      	match {.upper_offset,.lower_offset} = find_offset_index(transfer_size,cpu_addr);
      	//$display("Bank %d: Upper Offset: %d,Lower Offset: %d",n,upper_offset,lower_offset,$time);
      	
        //////////////////////////////////////PLRU/////////////////////////////////////////////////////
		Integer replace_block=-1;
      	Bit#(TLog#(l2_sets)) set=cpu_addr[v_addr_width-v_num_of_tag_bits-1:v_num_of_offset_bits];
      	Bit#(TSub#(l2_ways,1)) lru_bits = pseudo_lru[set];
      	Integer block_to_replace=0;
      	for(Integer i=v_ways-1;i>=0;i=i-1)
          	if(valid_dirty_values[i][1]==0)
          	begin
            	replace_block=i;
            	block_to_replace=i; 
          	end
      	if(replace_block==-1)
      	begin                  
        	Integer left=0;
        	Integer right=0;
        	Integer i=0;
        	while(i<(v_ways-1))
        	begin
          		left=i+1;
          		right=i+2;
          		if(lru_bits[v_ways-2-i]==0)
            		i=i+left;
          		else
            		i=i+right;
        	end
			block_to_replace=fromInteger(i-v_ways+1);
        	//$display("Bank %d: PLRU block to replace chosen : %d",n,block_to_replace,$time);
      	end

      	
		Integer matched_tag=-1;
		for(Integer i=0; i<v_ways; i=i+1)begin
			if(valid_dirty_values[i][1]==1'b1 && tag_values[i]==ff_request_from_l1.first.address[v_addr_width-1:v_addr_width-v_num_of_tag_bits])
					matched_tag=i;	// here this variable indicates which tags show a match.
		end
        //////////////////////////////////////on HIT////////////////////////////////////////////////
		if(matched_tag!=-1)                      				
      	begin
        	$display("Bank %d: Hit for address : %h",n,ff_request_from_l1.first.address);        	            
        	ff_response_to_l1.enq(Hit_structure_d{data_line:data_values[matched_tag],
                                              transfer_size:transfer_size,
                                              write_data:ff_request_from_l1.first.write_data,
                                              upper_offset:upper_offset,
                                              lower_offset:lower_offset,
                                              replace_block:fromInteger(matched_tag),
                                              address:ff_request_from_l1.first.address,
                                              ld_st:ff_request_from_l1.first.ld_st,
                                              hit:True});           	 	                                              
            /////////////////////////////Finding new LRU bits///////////////////////////////////////
      		Bit#(TSub#(l2_ways,1)) lru_bits_new = pseudo_lru[set];
        	Integer m=v_ways-1+matched_tag;
        	Integer n=0;
        	while(m>0)begin
		        if(m%2==1)begin
		            n=(m-1)/2;
		            if(n<v_ways)
		                lru_bits_new[v_ways-2-n]=1;
		        end
		        else begin
		            n=(m-2)/2;
		            if(n<v_ways)
		                lru_bits_new[v_ways-2-n]=0;
		        end
		        m=n;
        	end
		    pseudo_lru[set]<=lru_bits_new; // update the LRU bits after the access is made
		    //$display("Bank %d: Changed PLRU for set : %d with bits :%b",n,set,lru_bits_new,$time);
		    ////////////////////////////////////////////////////////////////////////////////////////
		end

		/////////////////////////////////////on MISS////////////////////////////////////////////////////////////////
		else 
		begin
			/*if(ff_request_from_l1.first.ld_st == Load)
           	 	rg_hit_miss <= LM;
           	 else
           	 	rg_hit_miss <= WM;*/
        	$display("Bank %d: Miss for address : %h ",n,ff_request_from_l1.first.address,fshow(ff_request_from_l1.first.ld_st),$time);
        	if(replace_block==-1)begin
          		ff_write_back_queue.enq(WriteBack_structure_d{address:ff_request_from_l1.first.address,
                                                      data_line:data_values[block_to_replace],
                                                      transfer_size:transfer_size,
                                                      burst_mode:rg_burst_mode});
          		$display("Bank %d: Enquing into the WRITE BACK QUEUE",n,$time);
        	end
        	$display("Bank %d: Enquing into the Request_to_memory QUEUE",n,$time);
        	ff_request_to_memory.enq(To_Memory_d{address: ff_request_from_l1.first.address,
				                                  transfer_size:fromInteger(valueOf(TLog#(l2_word_size))),
				                                  burst_mode:fromInteger(valueOf(TLog#(l2_block_size))),
				                                  ld_st:ff_request_from_l1.first.ld_st});
                                          
          	ff_metadata_miss.enq(Metadata_miss_d{address: ff_request_from_l1.first.address,
          											transfer_size:ff_request_from_l1.first.transfer_size,
                                              		write_data:ff_request_from_l1.first.write_data,
                                              		upper_offset:upper_offset,
                                              		lower_offset:lower_offset,
                                              		replace_block:fromInteger(block_to_replace),
                                              		ld_st:ff_request_from_l1.first.ld_st});
    	end		
	endrule
	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	//Rule 2: To carry out execution after response from memory- only on MISS
	rule response_after_miss(!rg_initialize);
   		let resp = ff_response_from_memory.first();
   		let mdata = ff_metadata_miss.first();
      	Bit#(TSub#(l2_addr_width,num_of_offset_bits)) input_tag = resp.address[v_addr_width-1:v_num_of_offset_bits];
      	$display("Bank %d: Recieved response from the memory. Address: %h Tag",n,resp.address,input_tag,$time);
      	
      	//Update BRAM
      	tag[mdata.replace_block].portB.request.put(BRAMRequest{write:True,address:mdata.address[v_addr_width-v_num_of_tag_bits-1:v_num_of_offset_bits],datain:mdata.address[v_addr_width-1:v_addr_width-v_num_of_tag_bits],responseOnWrite:False});
      	data[mdata.replace_block].portB.request.put(BRAMRequest{write:True,address:mdata.address[v_addr_width-v_num_of_tag_bits-1:v_num_of_offset_bits], datain:resp.data_line,responseOnWrite:False});
      	valid_dirty[mdata.replace_block].portB.request.put(BRAMRequest{write:True,address:mdata.address[v_addr_width-v_num_of_tag_bits-1:v_num_of_offset_bits], datain:2'b10,responseOnWrite:False});
      	//
    
      	ff_response_to_l1.enq(Hit_structure_d{data_line:resp.data_line,
		                                          transfer_size:mdata.transfer_size,
		                                          address:mdata.address,
		                                          write_data:mdata.write_data,
		                                          upper_offset:mdata.upper_offset,
		                                          lower_offset:mdata.lower_offset,
		                                          replace_block:mdata.replace_block,
		                                          ld_st:mdata.ld_st,
		                                          hit:False});
	  	ff_response_from_memory.deq();
	  	ff_metadata_miss.deq();
    endrule
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	//Rule 3: TO write data into BRAM- only for STORE op
	rule write_into_bram_on_store_hit(ff_response_to_l1.first.ld_st==Store && !rg_initialize);
   		let x = ff_response_to_l1.first();
      	ff_response_to_l1.deq();
      	ff_request_from_l1.deq();    //Deq Request FIFO here to prevent pipelining and out of order execution
      	//rg_hit_miss <= Invalid;
      	Bit#(2) valid_dirty_bits=2'b11;  //Valid and dirty
      	Bit#(TMul#(8,TMul#(l2_word_size,l2_block_size))) y= update_data_line(x.lower_offset,x.upper_offset,x.transfer_size,x.data_line,x.write_data);
      	//Update BRAM
      	data[x.replace_block].portB.request.put(BRAMRequest{write:True,address:x.address[v_addr_width-v_num_of_tag_bits-1:v_num_of_offset_bits], datain:y,responseOnWrite:False});
      	valid_dirty[x.replace_block].portB.request.put(BRAMRequest{write:True,address:x.address[v_addr_width-v_num_of_tag_bits-1:v_num_of_offset_bits], datain:valid_dirty_bits,responseOnWrite:False});
      	//
    endrule
    
////////////////////////////////////////////////.......End of Rules....///////////////////////////////////////////////////////////
	
///////////////////////////////////////////////......Method declarations.......///////////////////////////////////////////////////

	//Method to receive request and enq into ff_request_from_l1 FIFO
	method Action request_from_l1 (From_l1_d#(l2_addr_width,l2_word_size) req)if(!rg_initialize);
		for(Integer i=0; i<v_ways; i=i+1)
		begin
			tag[i].portA.request.put(BRAMRequest{write:False,address:req.address[v_addr_width-v_num_of_tag_bits-1:v_num_of_offset_bits], datain:?,responseOnWrite:False});
          	data[i].portA.request.put(BRAMRequest{write:False,address:req.address[v_addr_width-v_num_of_tag_bits-1:v_num_of_offset_bits], datain:?,responseOnWrite:False});
          	valid_dirty[i].portA.request.put(BRAMRequest{write:False,address:req.address[v_addr_width-v_num_of_tag_bits-1:v_num_of_offset_bits], datain:?,responseOnWrite:False});
      	end
		ff_request_from_l1.enq(req);
		Bit#(num_of_tag_bits) tag1=req.address[v_addr_width-1:v_num_of_tag_bits];
      	Bit#(TLog#(l2_sets)) set1=req.address[v_addr_width-v_num_of_tag_bits-1:v_num_of_offset_bits];
      	Bit#(num_of_offset_bits) off1=req.address[v_num_of_offset_bits-1:0];
      	$display("Bank %d: BRAM: recieved request for Address :%h tag %d: Set : %d Offset :%d Access type :",n,req.address,tag1,set1,off1,fshow(req.ld_st),$time);
    endmethod
    
    //Method to respond back with data- only LOAD operation
    method ActionValue#(To_l1_d#(l2_addr_width,l2_word_size)) response_to_l1 if(ff_response_to_l1.first.ld_st == Load && !rg_initialize);
      ff_response_to_l1.deq();
      ff_request_from_l1.deq();
      let x = ff_response_to_l1.first();
      //rg_hit_miss <= Invalid;
      bit mis_aligned_error=0;
      if((x.transfer_size==1 && x.address[0]==1) || (x.transfer_size==2 && x.address[1:0]!=0))
        mis_aligned_error=1;
      return To_l1_d{data_word:x.data_line[x.upper_offset:x.lower_offset],
                              		bus_error:0,
                                   	mis_aligned_error:mis_aligned_error,
                                   	address:x.address,
                                   	hit:x.hit};
    endmethod
    
    //Method to request data from memory
    method ActionValue#(To_Memory_d#(l2_addr_width,l2_word_size,l2_block_size)) request_to_memory if(!rg_initialize);
      //ff_request_to_memory.deq();
      return ff_request_to_memory.first();
    endmethod

    //Method to receive response from memory and enq into ff_response_from_memory FIFO
    method Action response_from_memory(From_Memory_d#(l2_addr_width,l2_word_size,l2_block_size) resp)if(!rg_initialize);
      ff_request_to_memory.deq();
      ff_response_from_memory.enq(resp);
    endmethod
    
    /*method ActionValue#(Hit_miss_d) hit_miss if(rg_hit_miss != Invalid && !rg_initialize);
      return rg_hit_miss;
    endmethod */
    
    //Method for writeback
    method ActionValue#(WriteBack_structure_d#(l2_addr_width,l2_word_size,l2_block_size)) write_back_data()if(!rg_initialize);
      ff_write_back_queue.deq();
      return ff_write_back_queue.first();
    endmethod
    
    method Action clear_all()if(!rg_initialize);
      ff_response_to_l1.clear();
      ff_request_from_l1.clear();
      ff_request_to_memory.clear();
      ff_response_from_memory.clear();
      for(Integer i=0;i<v_ways;i=i+1)begin // send address to the Block_rams
          tag[i].portAClear;
          data[i].portAClear;
          valid_dirty[i].portAClear;
          tag[i].portBClear;
          data[i].portBClear;
          valid_dirty[i].portBClear;
      end
    endmethod
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  endmodule
endpackage
		
		

