//------------------------------------------------------------------------
// A simple test bench template for simulating a top level user design
// utilizing FrontPanel. This file is "Read-only" and cannot be modified
// by the user. Follow these instructions to get started:
// 1. Create a top level test bench file within the "Simulation" file group
// 2. Copy and paste the contents of this template file into the newly
//    created file
// 3. Substitute "USER_TOP_LEVEL_MODULE" with the instantiation of the top
//    level module you wish to simulate
// 4. Add in the desired FrontPanel API simulation function calls listed
//    at the bottom of this template
//
//------------------------------------------------------------------------
// Copyright (c) 2022 Opal Kelly Incorporated
//------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module adc_tester_tb;

    wire  [4:0]   okUH;
    wire  [2:0]   okHU;
    wire  [31:0]  okUHU;
    wire          okAA;
    logic sys_clkp, sys_clkn;
    logic [3:0] led;
    wire  [1:0] VREF;
    logic sdi, ncs, sck, sdo;
    integer flag = 0;
    logic compare;
    logic sample, nsample;
    logic [7:0] sel_ref;

    task wait_n(input int n);
        repeat (n) begin
            @(posedge sys_clkp);
        end
    endtask

    initial sys_clkp = 1'b0;
    always #1 sys_clkp = ~sys_clkp;
    assign sys_clkn = ~sys_clkp;

    always_ff @(posedge sck) begin
       std::randomize(compare); 
    end


    adc_tester u_adc_tester (
        // OK USB 3
        .okUH        (okUH),
        .okHU        (okHU),
        .okUHU       (okUHU),
        .okAA        (okAA),
        // CLKs
        .sys_clkp    (sys_clkp),
        .sys_clkn    (sys_clkn),
        // LED and DDR3
        .led         (led),
        .VREF        (VREF),
        // Resets
        // SPI to UUT
        .sdi         (sdi),
        .ncs         (ncs),
        .sck         (sck),
        .sdo         (sdo));

    dig_top u_dig_top (
        // SPI Interface
        .n_cs       (ncs),
        .sck        (sck),
        .sdi        (sdo), // Follower Device
        // I / O
        .sdo        (sdi), // Follower Device
        // SAR ADC 
        .compare    (compare),
        // I / O
        .sample     (sample),
        .nsample    (nsample),
        .sel_ref    (sel_ref));

    //------------------------------------------------------------------------
    // Begin okHostInterface simulation user configurable global data
    //------------------------------------------------------------------------
    parameter BlockDelayStates = 5; // REQUIRED: # of clocks between blocks of pipe data
    parameter ReadyCheckDelay  = 5; // REQUIRED: # of clocks before block transfer before
                                    //    host interface checks for ready (0-255)
    parameter PostReadyDelay   = 5; // REQUIRED: # of clocks after ready is asserted and
                                    //    check that the block transfer begins (0-255)
    parameter pipeInSize       = 8; // REQUIRED: byte (must be even) length of default
                                    //    PipeIn; Integer 0-2^32
    parameter pipeOutSize      = 8; // REQUIRED: byte (must be even) length of default
                                    //    PipeOut; Integer 0-2^32
    logic   [7:0] pipeIn  [0:(pipeInSize-1)];
    logic   [7:0] pipeOut [0:(pipeOutSize-1)];
    parameter registerSetSize = 32;   // Size of array for register set commands.

    parameter Tsys_clk = 5;           // 100Mhz
    //-------------------------------------------------------------------------

    //------------------------------------------------------------------------
    //  Available User Task and Function Calls:
    //    FrontPanelReset;                 // Always start routine with FrontPanelReset;
    //    SetWireInValue(ep, val, mask);
    //    UpdateWireIns;
    //    UpdateWireOuts;
    //    GetWireOutValue(ep);
    //    ActivateTriggerIn(ep, bit);      // bit is an integer 0-31
    //    UpdateTriggerOuts;
    //    IsTriggered(ep, mask);           // Returns a 1 or 0
    //    WriteToPipeIn(ep, length);       // passes pipeIn array data
    //    ReadFromPipeOut(ep, length);     // passes data to pipeOut array
    //    WriteToBlockPipeIn(ep, blockSize, length);   // pass pipeIn array data; blockSize and length are integers
    //    ReadFromBlockPipeOut(ep, blockSize, length); // pass data to pipeOut array; blockSize and length are integers
    //    WriteRegister(address, data);
    //    ReadRegister(address, data);
    //    WriteRegisterSet;                // writes all values in u32Data to the addresses in u32Address
    //    ReadRegisterSet;                 // reads all values in the addresses in u32Address to the array u32Data
    //
    //    *Pipes operate by passing arrays of data back and forth to the user's
    //    design.  If you need multiple arrays, you can create a new procedure
    //    above and connect it to a differnet array.  More information is
    //    available in Opal Kelly documentation and online support tutorial.
    //------------------------------------------------------------------------

    wire [31:0] NO_MASK = 32'hffff_ffff;
    integer i;

    parameter WT = 300;

    initial begin
        flag = 0;
        FrontPanelReset;                      // Start routine with FrontPanelReset;
        // WIRE MODE
        flag = 1;
        wait_n(10);
        SetWireInValue(8'h00,1,NO_MASK);      // Rst system clock
        UpdateWireIns();
        wait_n(10);
        SetWireInValue(8'h00,0,NO_MASK);      // Clear rst
        UpdateWireIns();
        wait_n(10);
        UpdateWireOuts();                     // Expect clock to lock
        SetWireInValue(8'h00,2,NO_MASK);      // Rst CDC FIFOs
        UpdateWireIns();
        wait_n(10);
        SetWireInValue(8'h00,0,NO_MASK);      // Clear rst
        UpdateWireIns();
        wait_n(10);
        SetWireInValue(8'h00,4,NO_MASK);      // Rst CDC FIFOs
        UpdateWireIns();
        wait_n(10);
        SetWireInValue(8'h00,0,NO_MASK);      // Clear rst
        UpdateWireIns();
        //
        flag = 2;
        SetWireInValue(8'h01,2,NO_MASK);
        SetWireInValue(8'h02,32'h1000BAAD,NO_MASK);
        SetWireInValue(8'h03,32'h8a10B501,NO_MASK);
        UpdateWireIns();                      // Write to scratch
        wait_n(10);
        SetWireInValue(8'h01,0,NO_MASK);
        UpdateWireIns();                     
        wait_n(10);
        flag = 3;
        SetWireInValue(8'h01,2,NO_MASK);       
        SetWireInValue(8'h02,32'h00000000,NO_MASK);       
        SetWireInValue(8'h03,32'h8a110000,NO_MASK);       
        UpdateWireIns();                      // Req data from scratch to be put in the read/out queue 
        wait_n(10);
        SetWireInValue(8'h01,0,NO_MASK);       
        UpdateWireIns();        
        wait_n(10);
        SetWireInValue(8'h01,4,NO_MASK);      // Update wire-out from readout queue
        UpdateWireIns();        
        wait_n(10);
        SetWireInValue(8'h01,0,NO_MASK);       
        UpdateWireIns();        
        wait_n(10);
        UpdateWireOuts();                     // Expect sratch data to be read back //
        flag = 4;
        SetWireInValue(8'h01,2,NO_MASK);
        SetWireInValue(8'h02,32'h1000600D,NO_MASK);
        SetWireInValue(8'h03,32'h8a126000,NO_MASK);
        UpdateWireIns();                      // Write to scratch brining SPI out of reset
        wait_n(10);
        SetWireInValue(8'h01,0,NO_MASK);
        UpdateWireIns();                     
        wait_n(10);
        flag = 5;
        SetWireInValue(8'h01,2,NO_MASK);
        SetWireInValue(8'h02,32'h50000000,NO_MASK);
        SetWireInValue(8'h03,32'h8a1300FF,NO_MASK);
        UpdateWireIns();                      // Reset ADC Target
        wait_n(WT);
        SetWireInValue(8'h01,0,NO_MASK);
        UpdateWireIns();                     
        wait_n(WT);
        SetWireInValue(8'h01,2,NO_MASK);
        SetWireInValue(8'h02,32'h50000000,NO_MASK);
        SetWireInValue(8'h03,32'h8a140000,NO_MASK);
        UpdateWireIns();                      // Clear Reset
        wait_n(WT);
        SetWireInValue(8'h01,0,NO_MASK);
        UpdateWireIns();                     
        wait_n(WT);
        flag = 6;
        SetWireInValue(8'h01,2,NO_MASK);
        SetWireInValue(8'h02,32'h50050000,NO_MASK);
        SetWireInValue(8'h03,32'h8a150001,NO_MASK);
        UpdateWireIns();                      // Reset SAR ADC
        wait_n(WT);
        SetWireInValue(8'h01,0,NO_MASK);
        UpdateWireIns();                     
        wait_n(WT);
        SetWireInValue(8'h01,2,NO_MASK);
        SetWireInValue(8'h02,32'h50050000,NO_MASK);
        SetWireInValue(8'h03,32'h8a160000,NO_MASK);
        UpdateWireIns();                      // Clear SAR ADC reset
        wait_n(WT);
        SetWireInValue(8'h01,0,NO_MASK);
        UpdateWireIns();                     
        wait_n(WT);
        flag = 7;
        SetWireInValue(8'h01,2,NO_MASK);
        SetWireInValue(8'h02,32'h50050000,NO_MASK);
        SetWireInValue(8'h03,32'h8a170002,NO_MASK);
        UpdateWireIns();                      // Conv SAR ADC
        wait_n(WT);
        SetWireInValue(8'h01,0,NO_MASK);
        UpdateWireIns();                     
        wait_n(WT);
        SetWireInValue(8'h01,2,NO_MASK);
        SetWireInValue(8'h02,32'h50050000,NO_MASK);
        SetWireInValue(8'h03,32'h8a180000,NO_MASK);
        UpdateWireIns();                      // Prep SAR ADC
        wait_n(WT);
        SetWireInValue(8'h01,0,NO_MASK);
        UpdateWireIns();                     
        wait_n(WT);
        flag = 8;
        SetWireInValue(8'h01,2,NO_MASK);
        SetWireInValue(8'h02,32'h50010000,NO_MASK);
        SetWireInValue(8'h03,32'h8a190006,NO_MASK);
        UpdateWireIns();                      // Load result
        wait_n(WT);
        SetWireInValue(8'h01,0,NO_MASK);
        UpdateWireIns();                     
        wait_n(WT);
        SetWireInValue(8'h01,2,NO_MASK);
        SetWireInValue(8'h02,32'h40010000,NO_MASK);
        SetWireInValue(8'h03,32'h8a1a0006,NO_MASK);
        UpdateWireIns();                      // Read over SPI
        wait_n(WT);
        SetWireInValue(8'h01,0,NO_MASK);
        UpdateWireIns();                     
        wait_n(WT);
        flag = 9;
        wait_n(WT);
        SetWireInValue(8'h01,4,NO_MASK);      // Update wire-out from readout queue
        UpdateWireIns();        
        wait_n(WT);
        SetWireInValue(8'h01,0,NO_MASK);       
        UpdateWireIns();        
        wait_n(WT);
        UpdateWireOuts();                     // ADC conv result //
        wait_n(WT);
        // PIPE MODE
        // wait_n(10);
        // flag = 3;
        // pipeIn[0] = 8'hAD;
        // pipeIn[1] = 8'hBA;
        // pipeIn[2] = 8'h00;
        // pipeIn[3] = 8'h10;
        // pipeIn[4] = 8'h03;
        // pipeIn[5] = 8'hB5;
        // pipeIn[6] = 8'h10;
        // pipeIn[7] = 8'h8A;
        // WriteToPipeIn(8'h80, 8, 8);
        // wait_n(10);
        // flag = 4;
        // pipeIn[0] = 8'hFF;
        // pipeIn[1] = 8'hFF;
        // pipeIn[2] = 8'h00;
        // pipeIn[3] = 8'h00;
        // pipeIn[4] = 8'hFF;
        // pipeIn[5] = 8'hFF;
        // pipeIn[6] = 8'h11;
        // pipeIn[7] = 8'h8A;
        // WriteToPipeIn(8'h80, 4, 8);
        // wait_n(20);
        // flag = 5;
        // ReadFromPipeOut(8'ha0, 8, 8);
        // flag = 6;
        // pipeIn[0] = 8'hAD;
        // pipeIn[1] = 8'hBA;
        // pipeIn[2] = 8'h00;
        // pipeIn[3] = 8'h10;
        // pipeIn[4] = 8'h02; // Get SPI on Host Set
        // pipeIn[5] = 8'hB5;
        // pipeIn[6] = 8'h10;
        // pipeIn[7] = 8'h8A;
        // WriteToPipeIn(8'h80, 8, 8);
        // wait_n(1);
        // pipeIn[0] = 8'h00;
        // pipeIn[1] = 8'h00;
        // pipeIn[2] = 8'h05; // Config cntrl reg
        // pipeIn[3] = 8'h50; 
        // pipeIn[4] = 8'h00;
        // pipeIn[5] = 8'h00;
        // pipeIn[6] = 8'h13;
        // pipeIn[7] = 8'h8A;
        // WriteToPipeIn(8'h80, 8, 8);
        // wait_n(1);
        // pipeIn[0] = 8'h00;
        // pipeIn[1] = 8'h00;
        // pipeIn[2] = 8'h00; // Reset
        // pipeIn[3] = 8'h50;
        // pipeIn[4] = 8'hAC;
        // pipeIn[5] = 8'h00;
        // pipeIn[6] = 8'h12;
        // pipeIn[7] = 8'h8A;
        // WriteToPipeIn(8'h80, 8, 8);
        // wait_n(1);
        // flag = 8;
        // pipeIn[0] = 8'h00;
        // pipeIn[1] = 8'h00;
        // pipeIn[2] = 8'h01; // Config pntr
        // pipeIn[3] = 8'h50; 
        // pipeIn[4] = 8'h06;
        // pipeIn[5] = 8'h00;
        // pipeIn[6] = 8'h13;
        // pipeIn[7] = 8'h8A;
        // WriteToPipeIn(8'h80, 8, 8);
        // wait_n(1);
        // pipeIn[0] = 8'h00;
        // pipeIn[1] = 8'h00;
        // pipeIn[2] = 8'h05; // Start conv
        // pipeIn[3] = 8'h50; 
        // pipeIn[4] = 8'h02;
        // pipeIn[5] = 8'h00;
        // pipeIn[6] = 8'h14;
        // pipeIn[7] = 8'h8A;
        // WriteToPipeIn(8'h80, 8, 8);
        // wait_n(1);
        // flag = 9;
        // pipeIn[0] = 8'h00;
        // pipeIn[1] = 8'h00;
        // pipeIn[2] = 8'h05; // Prep next conv
        // pipeIn[3] = 8'h50; 
        // pipeIn[4] = 8'h00;
        // pipeIn[5] = 8'h00;
        // pipeIn[6] = 8'h15;
        // pipeIn[7] = 8'h8A;
        // WriteToPipeIn(8'h80, 8, 8);
        // wait_n(1);
        // flag = 10;
        // pipeIn[0] = 8'h00;
        // pipeIn[1] = 8'h00;
        // pipeIn[2] = 8'h01; // Load result
        // pipeIn[3] = 8'h50; 
        // pipeIn[4] = 8'h06;
        // pipeIn[5] = 8'h00;
        // pipeIn[6] = 8'h16;
        // pipeIn[7] = 8'h8A;
        // WriteToPipeIn(8'h80, 8, 8);
        // wait_n(1);
        // flag = 11;
        // pipeIn[0] = 8'h00;
        // pipeIn[1] = 8'h00;
        // pipeIn[2] = 8'h05; // Read result / start next conv
        // pipeIn[3] = 8'h40; 
        // pipeIn[4] = 8'h02;
        // pipeIn[5] = 8'h00;
        // pipeIn[6] = 8'h17;
        // pipeIn[7] = 8'h8A;
        // WriteToPipeIn(8'h80, 8, 8);
        // wait_n(1);
        // pipeIn[0] = 8'h00;
        // pipeIn[1] = 8'h00;
        // pipeIn[2] = 8'h05; // Prep next next conv
        // pipeIn[3] = 8'h50; 
        // pipeIn[4] = 8'h00;
        // pipeIn[5] = 8'h00;
        // pipeIn[6] = 8'h18;
        // pipeIn[7] = 8'h8A;
        // WriteToPipeIn(8'h80, 8, 8);
        // wait_n(1);
        // flag = 12;
        // pipeIn[0] = 8'h00;
        // pipeIn[1] = 8'h00;
        // pipeIn[2] = 8'h01; // Load result
        // pipeIn[3] = 8'h50; 
        // pipeIn[4] = 8'h06;
        // pipeIn[5] = 8'h00;
        // pipeIn[6] = 8'h19;
        // pipeIn[7] = 8'h8A;     
        // WriteToPipeIn(8'h80, 8, 8);   
        // wait_n(1);
        // pipeIn[0] = 8'h00;
        // pipeIn[1] = 8'h00;
        // pipeIn[2] = 8'h05; // Read result / start next conv
        // pipeIn[3] = 8'h40; 
        // pipeIn[4] = 8'h02;
        // pipeIn[5] = 8'h00;
        // pipeIn[6] = 8'h20;
        // pipeIn[7] = 8'h8A;
        // WriteToPipeIn(8'h80, 8, 8);
        // flag = 13;
        // ReadFromPipeOut(8'ha0, 8, 8);
        // wait_n(20);
        // ReadFromPipeOut(8'ha0, 8, 8);
        // wait_n(200);
        $finish;
    end

    `include "./oksim/okHostCalls.vh"   // Do not remove!  The tasks, functions, and data stored
                                // in okHostCalls.vh must be included here.
endmodule

`default_nettype wire