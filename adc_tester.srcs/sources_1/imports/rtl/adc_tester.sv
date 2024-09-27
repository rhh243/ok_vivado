
/*
    Data :
    PC <=> USB 3.0 / XEM7360 <=> fp_hub <=> cdc_fifo <=> fpga logic <=> ASIC under test
                100.8 MHz USB 3.0        => cdc_fifo => clk_gen PLL
                200 MHz system => clk_gen PLL =^
    Clock: ^^^^^^^^

*/

module adc_tester (
    // OK USB 3
    input  logic [4:0]  okUH,
    output logic [2:0]  okHU,
    inout  logic [31:0] okUHU,
    inout  logic        okAA,
    // CLKs
    input  logic sys_clkp,
    input  logic sys_clkn,
    // LED and DDR3
    output logic [3:0] led,
    inout  logic [1:0] VREF,
    // Resets
    // SPI to UUT
    input  logic sdi,
    output logic ncs,
    output logic sck,
    output logic sdo
);

    // Debug
    logic [31:0] debug_o_0, debug_o_1;

    // Clocks
    logic logic_clk, okClk;   
    // Command Assembler 
    logic        cmd_fwd, clk_cmd, cmd_full, wr_rst_busy, rd_rst_busy, re_wr, re_rd; // clk_req
    logic [ 5:0] cmd;
    logic [11:0] addr, cmd_id;
    logic [31:0] data, backup_wire_i, backup_wire_o, xfer_mode, wi_w0, wi_w1, wo_cnt, wo_w0, wo_w1; 
    // XFER MODE : b0 = nWire / BTPipe Transfer mode selection, b1 = WR req, b2 = RD req
    // Backup_wire_i : b0 = Reset System Clock PLL, b1 = reset CDC FIFOs, b2 = reset oK interf logic
    // Backup_wire_o : b0 = System clock PLL locked
    logic [63:0] d_cdc, q_cdc;
    logic [63:0] d_cdc_2h, q_cdc_2h;
    logic [ 1:0] wr_2h;
        // Clock generator Dynamic Reconfig
    logic [ 6:0] dyn_addr; 
    logic dyn_en, dyn_rdy, dyn_wen, clk_lck;
    logic [15:0] dyn_d, dyn_q;
        // H2E Interface
    logic h2e_val, h2e_rdy; 
    logic [31:0] d_h2e;
        // E2H Interface
    logic fwd_2h, fwd_2h_full, wr_rst_busy_2h, rd_rst_busy_2h, d_rd_2h, empty_2h, e2h_fifo_rd;
    logic [ 1:0] wo_rd;
    logic fwd_2h_temp, full_2h_temp, empty_2h_temp;
    logic e2h_req, e2h_rdy;
    logic [31:0] d_e2h, d_e2h_temp;
    // Cntrl State Machine
    typedef enum { IDLE, FETCH, XEC } CNTRL_FSM;
    CNTRL_FSM curr_state;
    logic cmd_empty, cmd_req;
    logic [ 5:0] cmd_ex;
    logic [11:0] addr_ex, cmd_id_ex;
    logic [31:0] data_ex;
        // Local Registers
    logic [31:0] scratch; // 0x00 // b0 SPI reset, b1 SPI clk free-run
        // SPI Interface
    logic spi_busy;
    logic [1:0] spi_cmd, spi_wait;
    logic [3:0] spi_reg;
    logic [7:0] spi_data;
    // Unused
    assign VREF     = 2'bZZ;
    assign led      = 4'b0110; 
    assign dyn_addr = 0;
    assign dyn_d    = 0;
    assign dyn_en   = 0;
    assign dyn_wen  = 0;

    assign h2e_rdy = !cmd_full & !wr_rst_busy;
    assign e2h_rdy = !empty_2h_temp;
    fp_hub u_fp_hub (
        // O H2E
        .wi00_ep_dataout(backup_wire_i),
        .wi01_ep_dataout(xfer_mode),
        .wi02_ep_dataout(wi_w0),
        .wi03_ep_dataout(wi_w1),
        .pi80_ep_dataout(d_h2e),
        .pi80_ep_write(h2e_val),
            // .btpi80_ep_blockstrobe(),
        // I H2E
        .wo20_ep_datain(backup_wire_o),
        .wo21_ep_datain(wo_cnt),
        .wo22_ep_datain(wo_w0),
        .wo23_ep_datain(wo_w1),
            // .btpi80_ep_ready(h2e_rdy),
        // I E2H
        .poa0_ep_datain(d_e2h),
            // .btpoa0_ep_ready(e2h_rdy), 
        // O E2H
        .poa0_ep_read(e2h_req),
            // .btpoa0_ep_blockstrobe(),
        // OK Interface
        .okUH(okUH),
        .okHU(okHU),
        .okUHU(okUHU),
        .okAA(okAA),
        .okClk(okClk)); // 100.8 MHz with significant jitter - directly from Cypress USB 3 hub

    // Assemble and Interpret Command From Host
    // CMD[5] = 1/0 indicates mapping to DUT/FPGA - use address from word 1/0
    // CMD[4] = 1 indicates a command adjusting the CLK tree such as reset or dynamic reconfigure
    // CMD[3] = 0/1 indicates read / write
    always_ff @(posedge okClk) begin
        // Assemble Command Words 
        cmd_fwd <= 0;
        clk_cmd <= 0;
        if (xfer_mode[0] == 1 && h2e_val == 1) begin
            if (d_h2e[31] == 0) begin // Word 0, staging word
                cmd    [ 5: 3] <= d_h2e[30:28];
                addr           <= d_h2e[27:16];
                data   [31:16] <= d_h2e[15: 0];
            end else begin // Word 1, execute
                cmd    [ 2: 0] <= d_h2e[30:28];
                cmd_id         <= d_h2e[27:16];
                data   [15: 0] <= d_h2e[15: 0];
                cmd_fwd        <= 1;
                if (cmd[4] == 1) begin
                    cmd_fwd  <= 0;
                    clk_cmd  <= 1;
                end
            end
        end else if (xfer_mode[0] == 0 && xfer_mode[1] == 1 && re_wr == 0) begin
            re_wr   <= 1;
            cmd     <= {wi_w0[30:28], wi_w1[30:28]};
            addr    <= wi_w0[27:16];
            cmd_id  <= wi_w1[27:16];
            data    <= {wi_w0[15: 0], wi_w1[15: 0]};
            cmd_fwd <= 1;
            if (wi_w0[29] == 1) begin
                cmd_fwd  <= 0;
                clk_cmd  <= 1;
            end
        end else if (xfer_mode[0] == 0 && xfer_mode[1] == 0) begin
            re_wr   <= 0;
        end
        //// Dynamic Reconfigure
        // clk_req     <= 0;
        // if (clk_cmd == 1) begin
        //     case (addr)
        //         12'h000 : clk_rst  <= 1;
        //         12'h001 : fifo_rst <= 1;
        //         default: begin 
        //             clk_req <= 1;  
        //         end
        //     endcase
        // end
    end

    always_ff @(posedge okClk) begin
        d_rd_2h <= 0;
        wr_2h   <= 0;
        fwd_2h_temp <= 0;
        if (wr_2h == 3) begin 
            wr_2h <= 2; 
        end else if (wr_2h == 2) begin
            d_e2h_temp  <= {1'b0, q_cdc_2h[61:59], q_cdc_2h[43:32], q_cdc_2h[31:16]};
            fwd_2h_temp <= 1;
            wr_2h       <= 1;
        end else if (wr_2h == 1) begin
            d_e2h_temp  <= {1'b1, q_cdc_2h[58:56], q_cdc_2h[55:44], q_cdc_2h[15: 0]};
            fwd_2h_temp <= 1;
        end else if (empty_2h == 0 && rd_rst_busy_2h == 0 && full_2h_temp == 0) begin
            d_rd_2h <= 1;
            wr_2h   <= 3;
        end

        wo_rd <= 0;
        if (xfer_mode[0] == 0) begin
            if (backup_wire_i[2] == 1) begin
                wo_cnt <= 0;
            end if (wo_rd == 3) begin
                wo_rd <= 2;
            end else if (wo_rd == 2) begin
                wo_rd <= 1;
                wo_w0 <= d_e2h;
            end else if (wo_rd == 1) begin
                wo_w1 <= d_e2h;
                wo_cnt <= wo_cnt + 1;
            end else if (xfer_mode[2] == 0) begin 
                re_rd <= 0;
            end else if (xfer_mode[2] == 1 && re_rd == 0) begin
                re_rd <= 1;
                wo_rd <= 3;
            end
        end
    end

    always_comb begin
        if (xfer_mode[0] == 1) begin
            e2h_fifo_rd <= e2h_req;
        end else begin
            e2h_fifo_rd <= wo_rd[1];
        end
    end

    fifo_32x32 fpga2ok_queue (
        .srst(backup_wire_i[1]),
        .clk(okClk),
        .din(d_e2h_temp),
        .wr_en(fwd_2h_temp),
        .rd_en(e2h_fifo_rd),
        .dout(d_e2h),
        .full(),
        .almost_full(full_2h_temp),
        .empty(), 
        .almost_empty(empty_2h_temp));

    // Clk Gen and CDC ///////////////////////////////////////////////////////////
    clk_network clk_gen (
        // Clock out ports
        .clk_out1           (),
        .clk_out2           (),
        .clk_out3           (logic_clk),
        .clk_out4           (),
        .clk_out5           (),
        .clk_out6           (),
        .clk_out7           (),
        // Dynamic reconfiguration ports
        .daddr              (dyn_addr), 
        .dclk               (okClk),
        .den                (dyn_en),
        .din                (dyn_d), 
        .dout               (dyn_q), 
        .drdy               (dyn_rdy),
        .dwe                (dyn_wen),
        // Status and control signals
        .reset              (backup_wire_i[0]),
        .locked             (clk_lck),
        // Clock in ports
        .clk_in1_p          (sys_clkp),
        .clk_in1_n          (sys_clkn));
    assign backup_wire_o = {24'h0000000, 3'b000, empty_2h_temp, empty_2h, rd_rst_busy_2h, wr_rst_busy, clk_lck};

    // okClk to logic_clk CDC
    assign d_cdc = {2'b00, cmd, cmd_id, addr, data};
    fifo_64x32_cdc ok2fpga_cdc (             // FIFO 64 W X 32 D
        .rst(backup_wire_i[1]),
        .wr_clk(okClk),          
        .din(d_cdc),           
        .wr_en(cmd_fwd),       
        // I / O
        .full(),         
        .prog_full(cmd_full), // Asserts on 28 / 32
        .wr_rst_busy(wr_rst_busy), 
        // CDC okClk => logic_clk
        .rd_clk(logic_clk),     
        .rd_en(cmd_req), 
        .dout(q_cdc),               
        .empty(cmd_empty), 
        .rd_rst_busy(rd_rst_busy));
    assign cmd_ex    = q_cdc[61:56];
    assign cmd_id_ex = q_cdc[55:44];
    assign addr_ex   = q_cdc[43:32];
    assign data_ex   = q_cdc[31: 0];

    // logic_clk to okClk CDC
    fifo_64x32_cdc fpga2ok_cdc (             // FIFO 64 W X 32 D
        .rst(backup_wire_i[1]),    
        .wr_clk(logic_clk),          
        .din(d_cdc_2h),           
        .wr_en(fwd_2h),       
        // I / O
        .full(fwd_2h_full),         
        .prog_full(), // Asserts on 28 / 32
        .wr_rst_busy(wr_rst_busy_2h), 
        // CDC okClk => logic_clk
        .rd_clk(okClk),     
        .rd_en(d_rd_2h), 
        .dout(q_cdc_2h), 
        .empty(empty_2h), 
        .rd_rst_busy(rd_rst_busy_2h));


    // Cntrl State Machine ////////////////////////////////////////////
    always_ff @(posedge logic_clk) begin
        curr_state <= IDLE;
        cmd_req    <= 0;
        spi_cmd[0] <= 0;
        fwd_2h     <= 0;
        case (curr_state)
            IDLE  : begin
                if (cmd_empty == 0 && rd_rst_busy == 0 && fwd_2h_full == 0 && wr_rst_busy_2h == 0) begin
                    cmd_req <= 1;
                    curr_state <= FETCH;
                end
            end 
            FETCH : begin
                cmd_req    <= 0;
                curr_state <= XEC;
            end
            default: begin // XEC
                if (cmd_ex[5] == 1) begin
                    curr_state <= XEC;
                    if (spi_busy == 0) begin
                        if (spi_wait == 2) begin 
                            spi_wait <= 1;
                        end else if (spi_wait == 1) begin
                            spi_wait   <= 0;
                            curr_state <= IDLE;
                            fwd_2h   <= 1;
                            d_cdc_2h <= {2'b00, cmd_ex, cmd_id_ex, addr_ex, 24'h000000, spi_data};
                        end else if (cmd_ex[3] == 0) begin // Read
                            spi_cmd <= 2'b01;
                            spi_wait <= 2;
                        end else if (cmd_ex[3] == 1) begin // Write
                            curr_state <= IDLE; 
                            spi_cmd <= 2'b11;
                        end
                    end
                end else begin 
                    if (cmd_ex[3] == 0) begin // Read
                        if (addr_ex == 12'h000) begin
                            fwd_2h   <= 1;
                            d_cdc_2h <= {2'b00, cmd_ex, cmd_id_ex, addr_ex, scratch};
                        end else if (addr_ex == 12'h001) begin
                            fwd_2h   <= 1;
                            d_cdc_2h <= {2'b00, cmd_ex, cmd_id_ex, addr_ex, 24'h550000, spi_data};
                        end
                    end else begin            // Write
                        if (addr_ex == 12'h000) begin
                            scratch <= data_ex;
                        end
                    end
                end
            end
        endcase
    end

    assign spi_reg = {scratch[1], spi_cmd, scratch[0]};
    spi_host #(
        .ADDR_D    (8),
        .DATA_D    (8),
        .DATA_W    (1)
    ) u_spi_host (
        // System
        .clk       (logic_clk),
        .cmd       (spi_reg), // 3 = clk pass, 2 = rw flag, 1 = start, 0 = rst
        .addr      (addr_ex[7:0]),
        .d         (data_ex[7:0]),
        .q         (spi_data),
        .busy      (spi_busy),
        // SPI Interface
        .sdi       (sdi),
        .ncs       (ncs),
        .sck       (sck),
        .sdo       (sdo));


endmodule