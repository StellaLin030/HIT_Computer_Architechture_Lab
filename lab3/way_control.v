`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Harbin Institute of Technology
// Engineer: Zhiyan Lin
// 
// Create Date: 2023/11/02 19:01:36
// Module Name: way_control
//////////////////////////////////////////////////////////////////////////////////
module way_control(
    /* update */
    input       upd_we,         // 更新相关寄存器的写使能信号
    input [3:0] hit,            // 四路的命中情况
    input [3:0] upd_valid,      // 四路的有效位
    input [6:0] upd_index,      // 当前要更新替换位的行
    /* select way */
    input       sel_en,         // 选路的使能信号
    input [6:0] wdata_index,    // 当前从主存写回数据的块索引
    output reg [1:0]    select  // 输出的选路信号
);

    reg [3:0]   valid   [0:127];   // 维护四路中每一行的有效位
    reg [1:0]   replace [0:127][0:3];   // 维护四路中每一行的替换位

    integer i, j;
    initial begin
        for (i=0; i<128; i=i+1) begin
            for (j=0; j<4; j=j+1) begin
                valid[i][j] <= 1'b0;
                replace[i][j] <= j;     // 初始替换位为当前所在路的序号对应的二进制数值
            end
        end
    end

    /* 每次成功读取 Cache 数据后, 更新替换位和有效位的值 */
    always@(upd_we) begin
        for (i=0; i<4; i=i+1) begin
            /* 更新有效位 */
            valid[upd_index][i] <= upd_valid[i];

            /* 更新替换位 */
            if (hit[i]) begin   // 第 i 路命中
                replace[upd_index][i] <= 2'b11; // 更新替换位为 11, 表示最近使用
            end
            else if (replace[upd_index][i]) begin   // 第 i 路未命中, 但替换位不为 00
                replace[upd_index][i] <= replace[upd_index][i] - 2'b01; // 当前替换位减 1
            end
            // 第 i 路未命中且替换位为 00 时不作调整
        end
    end

    /* 从主存写回数据时需要进行选路 */
    /* 二编: 写回也需要更新替换位和有效位, 在写最后一个数时更新 */
    always@(sel_en) begin
        /* 四路对应的 Cache 行都是有效的情况 */
        if (valid[wdata_index] == 4'b1111) begin
            for (i=0; i<4; i=i+1) begin
                if (replace[wdata_index][i] == 2'b00) begin // 选择替换位为 00 的那路作为所替换的路
                    select <= i;
                end
            end
        end
        /* 存在无效路的情况 */
        else begin
            for (i=3; i>=0; i=i-1) begin
                if (valid[wdata_index][i] == 0) begin
                    select <= i;    // 选择无效路中序号最小的一路替换
                end
            end
        end
        /* 写入最后一个数时，更新位信息 */
        if (wdata_index[2:0] == 3'b111) begin
            for (i=0; i<4; i=i+1) begin
                if (i == select) begin
                    valid[wdata_index][i] <= 1;         // 更新被替换的路有效位为 1
                    replace[wdata_index][i] <= 2'b11;   // 更新替换位
                end
                else if (replace[wdata_index][i]) begin
                    replace[wdata_index][i] <= replace[wdata_index][i] - 2'b01; // 更新替换位
                end
            end
        end
    end

endmodule