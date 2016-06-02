README for L2_banked_n_cache

Files:
Tb_l2_nbanks.bsv   -> Testbench file for the cache system

L2_config.bsv      -> Contains the top module of the cache system. Takes care of instantiating the cache banks and 				      regulates transactions

l2bank.bsv         -> Contains the basic cache module. This cache is blocking and non pipelined

l2_types_d.bsv     -> Contains the transaction data types definitions

This a parameterized N set associative L2 cache system with the following features:

-> It is implemented as a system of n cache banks- each bank is a simple blocking cache.

-> The number of banks- n is parameterized and insitialized in the Testbench.

-> The top module mkl2config instantiates the required number of banks and takes care routing the requests to the respective banks

-> The blocks are assigned to each bank in such a manner that they are interleaved in the main memory. This facilities faster access of consecutive banks

-> The cache system as a whole is pipelined and is capable of out of order execution

Rest of the working is explained as comments in each module.
