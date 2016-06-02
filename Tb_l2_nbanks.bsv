/*

*/

package Tb_l2_nbanks;

  import L2_config::*;
  import L2_types_d::*;
  import FIFO::*;
  import FIFOF::*;
  import SpecialFIFOs::*;
  import Vector::*;
  `define way 4
  `define word_size 4
  `define block_size 8
  `define sets 512
  `define addr_width 32
  `define no_of_banks 2
  
  (*synthesize*)
//(*conflict_free="send_request_from_cpu,abandon"*)
  module mkTb_l2cache(Empty);
	//Ifc_l2_bank#(`addr_width,`way,`word_size,`block_size,`sets) l2bank<-mkl2bank("L2BANK_1");
    //Reg#(Bit#(8)) nbanks <-mkReg(`no_of_banks);
	Ifc_l2_config#(`addr_width,`way,`word_size,`block_size,`sets,`no_of_banks) l2config<- mkl2config;//(`no_of_banks); //TODO
	Reg#(Bit#(32)) rg_address <-mkReg(0);
	Reg#(Bit#(TMul#(8,TMul#(`word_size,`block_size)))) rg_test_data <-mkReg(truncate(256'hddddddddffffffffeeeeeeeebbbbbbbbaaaaaaaacccccccc1111111122222222));
	FIFO#(From_Memory_d#(`addr_width,`word_size,`block_size)) ff_memory_response <-mkFIFO;
	FIFO#(To_l1_d#(`addr_width,`word_size)) ff_l2_response <-mkFIFO;
	Reg#(Access_type_d) rg_access_type <-mkReg(Load);
	Reg#(Bit#(TMul#(8,`word_size))) rg_data <-mkReg('h77777777);

	Reg#(Bit#(32)) rg_cnt <-mkReg(0);
	Reg#(Bool) addr_reset <- mkReg(False);
	Wire#(Bool) clear <-mkDWire(False);

	(* descending_urgency = "send_response_from_memory, read_request_to_memory, read_response_to_l1, send_request_from_l1" *)
	
	rule send_request_from_l1(!clear);
		let x<-$stime;
		l2config.request_from_l1(From_l1_d{address:rg_address,cache_enable:1'b1,transfer_size:'b10, ld_st:rg_access_type, write_data:rg_data});

		//    if(rg_address=='h8)
		//      rg_address<='h0;
		//    else
		if(addr_reset==False) begin
		  	rg_address<=rg_address+'b100000100;
		  	addr_reset <= True;
		end
		else begin
			rg_address<=rg_address-'b100000100+4;
			addr_reset <= False;
		end
		
		if(rg_address=='h4 && x/10<516)
		  rg_access_type<=Store;
		else
		  rg_access_type<=Load;
	endrule
	//
	//  rule send_flush;
	//    let x<-$stime;
	//    x=x/10;
	//    if(x==15)
	//      clear<=True;
	//  endrule
	//
	//  rule abandon(clear);
	//      $display("CLEARING ALL REQUESTS");
	//      l2config.abandon_cycle();
	//      ff_memory_response.clear();
	//      rg_address<=0;
	//      rg_cnt<=0;
	//  endrule
	//
	
	rule read_response_to_l1;
		let x <- l2config.response_to_l1;
		//l2config.response_deqResult();
		$display("Response to cpu for address: %h is %h :",x.address,x.data_word,$time);
	endrule

	rule trial;
		let x<-$stime;
		if(x/10>512)
		  $display("\n\n");
	endrule

	rule read_request_to_memory(!clear && rg_cnt==0);
		let x<- l2config.request_to_memory;
		$display("MEM: Recieved request for address: %h",x.address,$time);
		if(x.address == 0)
			ff_memory_response.enq(From_Memory_d{bus_error:0,data_line:rg_test_data,address:x.address});
		else if(x.address == 'h00000104) begin
			//rg_test_data <= rg_test_data+1;
			ff_memory_response.enq(From_Memory_d{bus_error:0,data_line:rg_test_data+1,address:x.address});
		end
		else begin
			rg_test_data <= rg_test_data+1;
			ff_memory_response.enq(From_Memory_d{bus_error:0,data_line:rg_test_data,address:x.address});
		end
		rg_cnt<=1;
		//rg_test_data<=rg_test_data+1;
	endrule

	rule send_response_from_memory(!clear && rg_cnt!=0);
		if(rg_cnt==7)begin
		  l2config.response_from_memory(ff_memory_response.first());
		  ff_memory_response.deq();
		  rg_cnt<=0;
		end
		else
		  rg_cnt<=rg_cnt+1;
	endrule

	rule terminate;
		let x<-$stime;
		x=x/10;
		if(x==650)
		  $finish(2);
	endrule

  endmodule
endpackage
