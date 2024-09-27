 module spi_host #(
    parameter ADDR_D = 8,
    parameter DATA_D = 8,
    parameter DATA_W = 1
) (
    // System
    input  logic                       clk,
    input  logic [3:0]                 cmd, // 3 = clk pass, 2 = rw flag, 1 = start, 0 = rst
    input  logic [ADDR_D-1 : 0]        addr,
    input  logic [DATA_D*DATA_W-1 : 0] d,
    output logic [DATA_D*DATA_W-1 : 0] q,
    output logic                       busy,
    // SPI Interface
    input  logic [DATA_W-1 : 0]        sdi,
    output logic [DATA_W-1 : 0 ]       sdo,
    output logic                       sck,
    output logic                       ncs
);
    
    typedef enum { WAIT, ADDR, DATA } SPI_FSM;
    SPI_FSM curr_state;

    logic [2:0] sub_cntr; 
    logic [ADDR_D-1:0] reg_addr;
    logic [DATA_W-1:0][DATA_D-1:0] reg_sdo, reg_sdi;
    logic rw_flag, pass_flag, clk_en, trigger;

    always_ff @(posedge clk) begin
        pass_flag <= cmd[3];
        if (cmd[0] == 1'b1) begin // Reset
            curr_state <= WAIT;
            ncs        <= 1'b1;
            busy       <= 1'b0;
            clk_en     <= 1'b0;
            trigger    <= 0;
        end else begin
            clk_en  <= 1;
            trigger <= 0;
            case (curr_state)
                WAIT : begin
                    clk_en <= 0;
                    if ((cmd[1] == 1'b1 && sck == 1) || trigger == 1) begin
                        curr_state <= ADDR;
                        sub_cntr   <= ADDR_D-1;
                        rw_flag    <= cmd[2];
                        reg_addr   <= {addr[ADDR_D-2:0], 1'b0};
                        sdo        <= {addr[ADDR_D-1], addr[ADDR_D-1], addr[ADDR_D-1], addr[ADDR_D-1]};
                        for (int idx=0; idx<DATA_W; ++idx) begin
                            reg_sdo[idx][DATA_D-1:0] <= d[(idx+1)*DATA_D-1 -: DATA_D];
                        end
                        ncs  <= 1'b0;
                        busy <= 1'b1;
                    end else if (cmd[1] == 1 && sck == 0) begin
                        trigger <= 1;
                        busy    <= 1'b1;
                    end
                end
                ADDR : begin
                    if (sck == 1) begin
                        sub_cntr <= sub_cntr - 1;
                        sdo      <= {reg_addr[ADDR_D-1], reg_addr[ADDR_D-1], reg_addr[ADDR_D-1], reg_addr[ADDR_D-1]};
                        reg_addr <= {reg_addr[ADDR_D-2:0], 1'b0};
                        if (sub_cntr == 0) begin
                            curr_state <= DATA;
                            sub_cntr <= DATA_D-1;
                            for (int idx=0; idx<DATA_W; ++idx) begin
                                reg_sdo[idx] <= {reg_sdo[idx][DATA_D-2:0], 1'b0};
                                sdo[idx]     <= reg_sdo[idx][DATA_D-1];
                                if (rw_flag == 0) begin
                                    reg_sdi[idx] <= {reg_sdi[idx], sdi[idx]};
                                end  
                            end
                        end
                    end
                end
                default: begin // DATA
                    if (sck == 1) begin 
                        sub_cntr <= sub_cntr - 1;
                        if (sub_cntr == 0) begin
                            if (rw_flag == 0) begin
                                for (int idx=0; idx<DATA_W; ++idx) begin
                                    q[(idx+1)*DATA_D-1 -: DATA_D] <= {reg_sdi[idx]};
                                end
                            end
                            rw_flag    <= 1;
                            curr_state <= WAIT;
                            ncs        <= 1'b1;
                            busy       <= 1'b0;
                        end else begin 
                            for (int idx=0; idx<DATA_W; ++idx) begin
                                reg_sdo[idx] <= {reg_sdo[idx][DATA_D-2:0], 1'b0};
                                sdo[idx]     <= reg_sdo[idx][DATA_D-1];
                                if (rw_flag == 0) begin
                                    reg_sdi[idx] <= {reg_sdi[idx], sdi[idx]};
                                end      
                            end
                        end
                    end
                end
            endcase
        end
    end

    always_ff @(posedge clk) begin
        sck <= !sck;
        if (cmd[0] == 1) begin
            sck <= 1;
        end
    end

endmodule