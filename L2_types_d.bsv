

//TODO: Delete the separate rule for Store Hit?

package L2bank;
  import L2_types_d::*;
  import ClientServer ::*;
  import GetPut       ::*;
  import Connectable  ::*;
  import FIFO ::*;
  import FIFOF ::*;
  import SpecialFIFOs::*;
  import BRAM::*;
  import ConfigReg::*;
  import LoadBuffer_d::*;
  import CFFIFO::*;
  import Vector::*;

  interface Ifc_l2_bank#(numeric type l2_addr_width,numeric type l2_ways, numeric type l2_word_size, numeric type l2_block_size);
    method Action request_from_cpu(From_l1_d#(l2_addr_width,l2_word_size) req);
    method ActionValue#(To_l1_d#(l2_addr_width,l2_word_size)) response_to_cpu;
    method ActionValue#(To_Memory_d#(l2_addr_width,l2_word_size,l2_block_size)) request_to_memory;
    method Action response_from_memory(From_Memory_d#(l2_addr_width,l2_word_size,l2_block_size) resp);
    method ActionValue#(WriteBack_structure_d#(l2_addr_width,l2_word_size,l2_block_size)) write_back_data();
    method Action clear_all();
  endinterface

 module mkl2_bank#(parameter String name)(Ifc_l2_bank#(l2_addr_width,l2_ways,l2_word_size,l2_block_size,l2_sets))
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
    
    function Tuple2#(Bit#(TLog#(TMul#(8,TMul#(l2_word_size,l2_block_size)))),Bit#(TLog#(TMul#(8,TMul#(l2_word_size,l2_block_size))))) find_offset_index(Bit#(2) transfer_size, Bit#(_addr_width) cpu_addr);
    	let v_word_size = valueOf(l2_word_size);
    	Bit#(TLog#(TMul#(8,TMul#(l2_word_size,_block_size)))) lower_offset=0;
    	Bit#(TLog#(TMul#(8,TMul#(l2_word_size,_block_size)))) upper_offset=0;
    	for(Integer i=0; i<v_block_size; i=i+1)
    	begin
      		if(fromInteger(i)==unpack(cpu_addr[v_num_of_offset_bits-1:v_num_of_bytes]))    // the lower order bits used to access each byte.
      		begin 
        		lower_offset= fromInteger(v_word_size)*8*fromInteger(i); // calculating the lower bit index value. For. eg if word is 32bit. possible values are 0,32,64,96...
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
  	
  	function Bit#(TMul#(8,TMul#(l2_word_size,l2_block_size))) update_data_line (Bit#(TLog#(TMul#(8,TMul#(l2_word_size,l2_block_size)))) lower_offset, Bit#(TLog#(TMul#(8,TMul#(l2_word_size,l2_block_size)))) upper_offset, Bit#(2) transfer_size, Bit#(TMul#(8,TMul#(l2_word_size,l2_block_size))) data, Bit#(TMul#(8,l2_word_size)) write_data);
      Bit#(lower_offset) y = data[lower_offset-1:0];
      let x= data[fromInteger(8*v_word_size*v_block_size-1):upper_offset+1];
      Bit#(8) temp1= write_data[upper_offset-lower_offset:0];
      Bit#(16) temp2=write_data[upper_offset-lower_offset:0];
      Bit#(32) temp3=write_data[upper_offset-lower_offset:0];
      Bit#(64) temp4=write_data[upper_offset-lower_offset:0];
      Bit#(TMul#(8,TMul#(_word_size,_block_size))) new_data=0;
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

	FIFO#(From_l1_d#(l2_addr_width,l2_word_size) ff_request_from_l1 <- mkFIFO1();
	FIFO#(Hit_structure_d#(l2_addr_width,l2_word_size,l2_block_size,l2_ways)) ff_response_to_l1 <-mkFIFO1();
	FIFO#(WriteBack_structure_d#(l2_addr_width,l2_word_size,l2_block_size)) ff_write_back_queue <-mkFIFO1();
	FIFO#(Metadata_miss_d#(l2_addr_width,l2_word_size,l2_block_size,l2_ways)) ff_metadata_miss <-mkFIFO1();
	FIFO#(To_Memory_d#(l2_addr_width,l2_word_size,l2_block_size)) ff_request_to_memory <-mkFIFO1();
    FIFO#(From_Memory_d#(l2_addr_width,l2_word_size,l2_block_size)) ff_response_from_memory <-mkFIFO1();
	Reg#(Bit#(3)) rg_burst_mode <-mkReg(v_block_size==4?'b011:v_block_size==8?'b101:v_block_size==16?'b111:0);
	Reg#(Bool) rg_initialize <-mkReg(True);
	Reg#(Bit#(TAdd#(1,TLog#(l2_sets)))) rg_index <-mkReg(0);

	BRAM_Configure cfg = defaultValue ;
    cfg.latency=1;
    cfg.outFIFODepth=2;
    cfg.allowWriteResponseBypass=True;
		BRAM2Port#(Bit#(TLog#(_sets)), Bit#(num_of_tag_bits)) tag [v_ways]; // declaring as many tag arrays as there are number of `Ways. Depth of each array is the number of sets.
		BRAM2Port#(Bit#(TLog#(_sets)), Bit#(2)) valid_dirty [v_ways];     // declaring as many alid bit arrays as there are number of `Ways. Depth of each array is the number of sets.
		BRAM2Port#(Bit#(TLog#(_sets)), Bit#(TMul#(8,TMul#(l2_word_size,l2_block_size)))) data [v_ways]; // decalring similar data arrays. each of width equal to block size.
		
		Reg#(Bit#(TSub#(_ways,1))) pseudo_lru [v_sets];
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
      $display("Flushing Cache",$time);
    endrule
    
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
      	$display("Upper Offset :%d,Lower Offset:%d",upper_offset,lower_offset,$time);
      	
//////////////////////////////////////////////PLRU/////////////////////////////////////////////////////
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
        	$display("%s:PLRU block to replace chosen : %d",name,block_to_replace,$time);
      	end

      	
		Integer matched_tag=-1;
		for(Integer i=0; i<v_ways; i=i+1)begin
			if(valid_dirty_values[i][1]==1'b1 && tag_values[i]==ff_request_from_l1.first.address[v_addr_width-1:v_addr_width-v_num_of_tag_bits])
					matched_tag=i;	// here this variable indicates which tags show a match.
		end
		ff_request_from_l1.deq();   //deq req here, load info into another FIFO for MISS handling
//////////////////////////////////////////////on HIT////////////////////////////////////////////////
		if(matched_tag!=-1)                      				
      	begin
        	$display("Hit for address : %h",ff_request_from_l1.first.address);            
        	ff_response_to_l1.enq(Hit_structure_d{data_line:data_values[matched_tag],
                                              transfer_size:transfer_size,
                                              write_data:ff_request_from_l1.first.write_data,
                                              upper_offset:upper_offset,
                                              lower_offset:lower_offset,
                                              replace_block:fromInteger(matched_tag),
                                              address:ff_request_from_l1.first.address,
                                              ld_st:ff_request_from_l1.first.ld_st});
                                              
            /////////////////////////////Finding new LRU bits//////////////////////////////////////////
      		Bit#(TSub#(_ways,1)) lru_bits_new = pseudo_lru[set];
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
		    $display("Changed PLRU for set : %d with bits :%b",set,lru_bits_new,$time);
		    //recently_updated_line<=tagged Invalid;
		    /////////////////////////////////////~Finding new LRU bits~////////////////////////////////////
		end

/////////////////////////////////////////////on MISS////////////////////////////////////////////////////////////////
		else 
		begin
        	$display("Miss for address : %h ",ff_request_from_l1.first.address,fshow(ff_request_from_l1.first.ld_st),$time);
        	if(replace_block==-1)begin      //TODO: This could be horribly wrong God save your DDP
          		ff_write_back_queue.enq(WriteBack_structure_d{address:ff_request_from_l1.first.address, //TODO: Really? request.address?
                                                      data_line:data_values[block_to_replace],
                                                      transfer_size:transfer_size,
                                                      burst_mode:rg_burst_mode});
          		$display("Enquing into the WRITE BACK QUEUE",$time);
        	end
        	
        	ff_request_to_memory.enq(To_Memory_d{address: ff_request_from_l1.first.address,
				                                  transfer_size:fromInteger(valueOf(TLog#(l2_word_size))),
				                                  burst_mode:fromInteger(valueOf(TLog#(l2_block_size))),
				                                  ld_st:Load});
                                          
          	ff_metadata_miss.enq(Metadata_miss_d{address: ff_request_from_l1.first.address,
          											transfer_size:ff_request_from_l1.first.transfer_size,
                                              		write_data:ff_request_from_l1.first.write_data,
                                              		upper_offset:upper_offset,
                                              		lower_offset:lower_offset,
                                              		replace_block:fromInteger(block_to_replace),
                                              		ld_st:ff_request_from_l1.first.ld_st});
    	end		
	endrule
	
	rule response_after_miss(!stall_processor && !rg_initialize);
   		let resp = ff_response_from_memory.first();
   		let mdata = ff_metadata_miss.first();
      	Bit#(TSub#(l2_addr_width,num_of_offset_bits)) input_tag = resp.address[v_addr_width-1:v_num_of_offset_bits];
      	$display("Recieved response from the memory. Address: :%h Tag : %h",resp.address,resp.address,$time);
      	tag[resp.replace_block].portB.request.put(BRAMRequest{write:True,address:ff_request_from_l1.first.address[v_addr_width-v_num_of_tag_bits-1:v_num_of_offset_bits],datain:ff_request_from_l1.first.address[v_addr_width-1:v_addr_width-v_num_of_tag_bits],responseOnWrite:False});
      	data[resp.replace_block].portB.request.put(BRAMRequest{write:True,address:ff_request_from_l1.first.address[v_addr_width-v_num_of_tag_bits-1:v_num_of_offset_bits], datain:resp.data_line,responseOnWrite:False});
      	valid_dirty[resp.replace_block].portB.request.put(BRAMRequest{write:True,address:ff_request_from_l1.first.address[v_addr_width-v_num_of_tag_bits-1:v_num_of_offset_bits], datain:2'b10,responseOnWrite:False});
      
      	ff_response_to_l1.enq(Hit_structure_d{data_line:resp.data_line,
                                              transfer_size:mdata.transfer_size,
                                              address:mdata.address,
                                              write_data:mdata.write_data,
                                              upper_offset:mdata.upper_offset,
                                              lower_offset:mdata.lower_offset,
                                              replace_block:mdata.replace_block,
                                              ld_st:mdata.ld_st});
	  	ff_response_from_memory.deq();
	  	ff_metadata_miss.deq();
    endrule
	
	rule write_into_bram_on_store_hit(ff_response_to_l1.first.ld_st==Store && !rg_initialize);
   		let x = ff_response_to_l1.first();
      	ff_response_to_l1.deq();
      	Bit#(2) valid_dirty_bits=2'b11;
      	Bit#(TMul#(8,TMul#(l2_word_size,l2_block_size))) y= update_data_line(x.lower_offset,x.upper_offset,x.transfer_size,x.data_line,x.write_data);
      	data[x.replace_block].portB.request.put(BRAMRequest{write:True,address:x.address[v_addr_width-v_num_of_tag_bits-1:v_num_of_offset_bits], datain:y,responseOnWrite:False});
      	valid_dirty[x.replace_block].portB.request.put(BRAMRequest{write:True,address:x.address[v_addr_width-v_num_of_tag_bits-1:v_num_of_offset_bits], datain:valid_dirty_bits,responseOnWrite:False});
    endrule

	method Action request_from_l1 (From_l1_d#(l2_addr_width,l2_word_size) req)if(!rg_initialize);
		for(Integer i=0; i<v_ways; i=i+1)
		begin
			tag[i].portA.request.put(BRAMRequest{write:False,address:req.address[v_addr_width-v_num_of_tag_bits-1:v_num_of_offset_bits], datain:?,responseOnWrite:False});
          	data[i].portA.request.put(BRAMRequest{write:False,address:req.address[v_addr_width-v_num_of_tag_bits-1:v_num_of_offset_bits], datain:?,responseOnWrite:False});
          	valid_dirty[i].portA.request.put(BRAMRequest{write:False,address:req.address[v_addr_width-v_num_of_tag_bits-1:v_num_of_offset_bits], datain:?,responseOnWrite:False});
      	end

		ff_request_from_l1.enq(req)
		Bit#(num_of_tag_bits) tag1=req.address[v_addr_width-1:v_num_of_tag_bits];
      	Bit#(TLog#(_sets)) set1=req.address[v_addr_width-v_num_of_tag_bits-1:v_num_of_offset_bits];
      	Bit#(num_of_offset_bits) off1=req.address[v_num_of_offset_bits-1:0];
      	$display("BRAM: recieved request for token : %d Address :%h tag %d: Set : %d Offset :%d Access type :",req.token,req.address,tag1,set1,off1,fshow(req.ld_st),$time);
    endmethod
    
    method ActionValue#(To_l1_d#(l2_addr_width,l2_word_size) response_to_l1 if(ff_response_to_l1.first.ld_st!=Store && !rg_initialize);
      ff_response_to_l1.deq();
      let x = ff_response_to_l1.first();
      //bit mis_aligned_error=0;
      //if((x.transfer_size==1 && x.address[0]==1) || (x.transfer_size==2 && x.address[1:0]!=0))
        //mis_aligned_error=1;
      return Cpu_resp_with_token_d{response:To_l1_d{data_word:x.data_line[x.upper_offset:x.lower_offset],
                              		bus_error:0,
                                   	mis_aligned_error:0,//mis_aligned_error,
                                   	address:x.address},
                                	ld_st:x.ld_st};
    endmethod
    
    method ActionValue#(To_Memory_d#(l2_addr_width,l2_word_size,l2_block_size)) request_to_memory if(!rg_initialize);
      ff_request_to_memory.deq();
      return ff_request_to_memory.first();
    endmethod

    method Action response_from_memory(From_Memory_d#(l2_addr_width,l2_word_size,l2_block_size) resp)if(!rg_initialize);
      ff_response_from_memory.enq(resp);
    endmethod
    
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

  endmodule
endpackage
		
		

