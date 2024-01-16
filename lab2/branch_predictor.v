module branch_predictor(
    input           clk,        //时钟信号，必须与CPU保持一致
    input           resetn,     //低有效复位信号，必须与CPU保持一致

    //供CPU第一级流水段使用的接口：
    //上一个指令地址
    input[31:0]     old_PC,
    //这周期是否需要更新PC（进行分支预测）
    input           predict_en,
    //预测出的下一个指令地址
    output reg [31:0]    new_PC,
    //是否被预测为执行转移的转移指令
    output reg           predict_jump,

    //分支预测器更新接口：
    //更新使能
    input           upd_en,
    //转移指令地址
    input[31:0]     upd_addr,
    //是否为转移指令    // 我觉得这个好像没用   
    input           upd_jumpinst,
    //若为转移指令，则是否转移
    input           upd_jump,
    //是否预测失败
    input           upd_predfail,
    //转移指令本身的目标地址（无论是否转移）
    input[31:0]     upd_target
);

    parameter   BUFFER_ADDR_LEN = 4;                // 缓冲区地址长度
    parameter   BUFFER_SIZE = 1<<BUFFER_ADDR_LEN;   // 缓冲区大小 2^BUFFER_ADDR_LEN
    parameter   TAG_LEN = 32-BUFFER_ADDR_LEN-2;     // 用于标识地址的tag

    wire [TAG_LEN-1:0]            old_PC_tag, upd_addr_tag;
    wire [BUFFER_ADDR_LEN-1:0]  old_PC_index, upd_addr_index;
    wire [1:0]                  old_PC_offset, upd_addr_offset;

    assign {old_PC_tag, old_PC_index, old_PC_offset} = old_PC;
    assign {upd_addr_tag, upd_addr_index, upd_addr_offset} = upd_addr;

    reg [TAG_LEN-1:0]   branch_inst_tag     [BUFFER_SIZE-1:0];   // 分支指令地址tag寄存器
    reg [31:0]          branch_tar_addr     [BUFFER_SIZE-1:0];   // 分支目标地址寄存器
    reg [1:0]           branch_predict      [BUFFER_SIZE-1:0];   // 分支预测标识 此处使用2位状态码

    // initial
    initial begin
        for (i=0; i<BUFFER_SIZE; i=i+1) begin
            branch_inst_tag[i] <= 0;
            branch_tar_addr[i] <= 0;
            branch_predict[i] <= 0;
        end
    end

    // predict
    always @(*) begin
        if ((branch_inst_tag[old_PC_index] == old_PC_tag) && ((branch_predict[old_PC_index] == 2'b11) || (branch_predict[old_PC_index] == 2'b10))) begin  // 进行分支预测
            new_PC = branch_tar_addr[old_PC_index];
            predict_jump = 1'b1;
        end
        else begin  // state = 01 or 00 不进行分支预测
            new_PC = branch_tar_addr[old_PC_index];
            predict_jump = 1'b0;
        end
    end

    // update
    integer i;
    always@(posedge clk) begin
        if (!resetn) begin
            for (i=0; i<BUFFER_SIZE; i=i+1) begin
                branch_inst_tag[i] <= 0;
                branch_tar_addr[i] <= 0;
                branch_predict[i] <= 0;
            end
        end
        else if (upd_en) begin
            if ((upd_jumpinst) && (upd_jump)) begin     // 成功分支指令
                branch_inst_tag[upd_addr_index] <= upd_addr_tag;
                branch_tar_addr[upd_addr_index] <= upd_target;
                /*if (branch_predict[upd_addr_index] != 2'b11) begin
                    branch_predict[upd_addr_index] <= branch_predict[upd_addr_index] + 2'b01;
                end*/
                if ((branch_predict[upd_addr_index] == 2'b11) || (branch_predict[upd_addr_index] == 2'b01) || (branch_predict[upd_addr_index] == 2'b10)) begin
                    branch_predict[upd_addr_index] <= 2'b11;
                end
                else if (branch_predict[upd_addr_index] == 2'b00) begin
                    branch_predict[upd_addr_index] <= 2'b01;
                end
            end
            else if (upd_predfail) begin   // 分支失败，预测错误
                branch_inst_tag[upd_addr_index] <= upd_addr_tag;
                branch_tar_addr[upd_addr_index] <= upd_target;
                /*if (branch_predict[upd_addr_index] != 2'b00) begin
                    branch_predict[upd_addr_index] <= branch_predict[upd_addr_index] - 2'b01;
                end*/
                if ((branch_predict[upd_addr_index] == 2'b11) || (branch_predict[upd_addr_index] == 2'b01)) begin
                    branch_predict[upd_addr_index] <= branch_predict[upd_addr_index] - 2'b01;
                end
                else if ((branch_predict[upd_addr_index] == 2'b10) || (branch_predict[upd_addr_index] == 2'b10)) begin
                    branch_predict[upd_addr_index] <= 2'b00;
                end
            end
        end
    end

endmodule