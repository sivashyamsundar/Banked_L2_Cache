README for L2_banked_n_cache

//
//

Files:
Tb_l2_nbanks.bsv   -> Testbench file for the cache system
L2_config.bsv      -> Contains the top module of the cache system. 
					  Takes care of instantiating the cache banks and regulates transactions
l2bank.bsv         -> Contains the basic cache module. This cache is blocking and non pipelined
l2_types_d.bsv     -> Contains the transaction data types definitions

//
//

This a parameterized N set associative L2 cache system with the following features:

-> It is implemented as a system of n cache banks- each bank is a simple blocking cache.
-> The number of banks- n is parameterized and insitialized in the Testbench.
-> The top module mkl2config instantiates the required number of banks and takes care routing the requests to the respective banks
-> The blocks are assigned to each bank in such a manner that they are interleaved in the main memory. This facilities faster access of consecutive banks
-> The cache system as a whole is pipelined and is capable of out of order execution

Rest of the working is explained as comments in each module.

The following output snippet of a 2 bank system (note out of order execution):

*****************

Index for address 00000000 is   1

Bank   1: BRAM: recieved request for Address :00000000 tag      0: Set :   0 Offset : 0 Access type :Load 5130
Index for address 00000104 is   0

Bank   1: Miss for address : 00000000 Load                5140
Bank   1: Enquing into the Request_to_memory QUEUE                5140

Bank   0: BRAM: recieved request for Address :00000104 tag      0: Set :   8 Offset : 4 Access type :Load 5150

Index for address 00000004 is   1

MEM: Recieved request for address: 00000000                5160
Bank   0: Miss for address : 00000104 Load                5160
Bank   0: Enquing into the Request_to_memory QUEUE                5160

Forwarding response_from_memory to bank   1

Bank   1: Recieved response from the memory. Address: 00000000 Tag        0   5250

MEM: Recieved request for address: 00000104                5260
Response to cpu for address: 00000000 is 22222222 :                5270

Bank   1: BRAM: recieved request for Address :00000004 tag      0: Set :   0 Offset : 4 Access type :Load 5270

Index for address 00000108 is   0

Bank   1: Hit for address : 00000004

Response to cpu for address: 00000004 is 11111111 :                5300        //OUT OF ORDER RESPONSE: addr 004 serviced before 104

Forwarding response_from_memory to bank   0

Bank   0: Recieved response from the memory. Address: 00000104 Tag        8     5350

Response to cpu for address: 00000104 is 11111111 :                5370

Bank   0: BRAM: recieved request for Address :00000108 tag      0: Set :   8 Offset : 8 Access type :Load  5370

Index for address 00000008 is   1

Bank   0: Hit for address : 00000108

Bank   1: BRAM: recieved request for Address :00000008 tag      0: Set :   0 Offset : 8 Access type :Load   5390

Index for address 0000010c is   0
Response to cpu for address: 00000108 is cccccccc :    5400

(truncated)
**************************





















