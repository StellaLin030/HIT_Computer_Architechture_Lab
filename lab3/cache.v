`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Harbin Institute of Technology
// Engineer: Zhiyan Lin
// 
// Create Date: 2023/10/31 17:05:31
// Module Name: cache
//////////////////////////////////////////////////////////////////////////////////
module cache (
    input            clk             ,  // clock, 100MHz
    input            rst             ,  // active low

    //  Sram-Like接口信号，用于CPU访问Cache
    input         cpu_req      ,    //由CPU发送至Cache
    input  [31:0] cpu_addr     ,    //由CPU发送至Cache
    output [31:0] cache_rdata  ,    //由Cache返回给CPU
    output        cache_addr_ok,    //由Cache返回给CPU
    output        cache_data_ok,    //由Cache返回给CPU

    //  AXI接口信号，用于Cache访问主存
    output [3 :0] arid   ,              //Cache向主存发起读请求时使用的AXI信道的id号
    output reg [31:0] araddr ,              //Cache向主存发起读请求时所使用的地址
    output reg        arvalid,              //Cache向主存发起读请求的请求信号
    input         arready,              //读请求能否被接收的握手信号

    input  [3 :0] rid    ,              //主存向Cache返回数据时使用的AXI信道的id号
    input  [31:0] rdata  ,              //主存向Cache返回的数据
    input         rlast  ,              //是否是主存向Cache返回的最后一个数据
    input         rvalid ,              //主存向Cache返回数据时的数据有效信号
    output reg        rready                //标识当前的Cache已经准备好可以接收主存返回的数据
);

    integer j;

    /* wire */
    wire        upd_we;             // 选路器更新信号
    wire        ram_we;             // Cache 写使能信号
    wire [1:0]  way_sel;            // 选路器输出的选择信号
    wire [3:0]  hit;                // 四路命中信号
    wire [3:0]  valid;              // 四路有效位
    wire [31:0] ram_rdata [0:3];    // 四路读出数据
    wire [31:0] cpu_raddr;          // 当前请求的地址
    wire [31:0] cache_wdata;        // 当前从主存写回 Cache 的数据

    /* reg */
    reg         init;               // 初始状态
    reg         cache_miss;         // 缓存不命中信号
    reg         cache_we;           // Cache 写使能信号寄存器
    reg [2:0]   state;              // 状态寄存器
    reg [2:0]   handshake;          // 当前数据握手次序
    reg [31:0]  current_raddr;      // 第二级流水段当前 Cache 处理的 CPU 请求地址
    reg [31:0]  current_rdata;      // 当前捕获的请求字
    reg [31:0]  current_wdata;      // 当前从主存读出的数据

    /* initialization */
    initial begin
        init <= 1'b1;
        cache_miss <= 1'b0;
        cache_we <= 1'b0;
        state <= 3'b000;
        handshake <= 3'b111;
        current_raddr <= 32'b0;
        current_rdata <= 32'b0;
        current_wdata <= 32'b0;
        
        araddr <= 32'b0;
        arvalid <= 1'b0;
        rready <= 1'b0;
    end

    /* 实例化4 个 data_ram, 4 个 tag_ram 和 1 个 way_control 模块 */
    genvar i;
    generate
        for (i=0; i<4; i=i+1) begin: data_ram_gen
            block_ram u_data_ram(
                // 写端口
                .clka(clk),
                .wea(ram_we && (way_sel == i)),
                .addra({araddr[11:5], handshake}),
                .dina(cache_wdata),
                // 读端口
                .clkb(clk),
                .enb(cpu_req && cache_addr_ok),
                .addrb(cpu_addr[11:2]),
                .doutb(ram_rdata[i])
            );
        end
    endgenerate

    generate
        for (i=0; i<4; i=i+1) begin: tag_ram_gen
            icache_tagv_table u_tag_ram(
                .clk(clk),
                .resetn(rst),
                // 写端口
                .wen(ram_we && (way_sel == i)),
                .valid_wdata(1'b1),
                .tag_wdata(araddr[31:12]),
                .windex(araddr[11:5]),
                // 读端口
                .rden(cpu_req && cache_addr_ok),
                .cpu_addr(cpu_addr),
                .hit(hit[i]),
                .valid(valid[i])
            );
        end
    endgenerate

    way_control u_way_control(
        .upd_we(upd_we),
        .hit(hit),
        .upd_valid(valid),
        .upd_index(cpu_raddr[11:5]),
        .sel_en(ram_we),
        .wdata_index(araddr[11:5]),
        .select(way_sel)
    );
    
    /* state operation */
    always@(posedge clk) begin
        if (rst) begin
            case (state)
                3'b000: begin
                    if (cpu_req & cache_addr_ok) begin
                        current_raddr <= cpu_addr;
                    end
                    if (cpu_addr != 32'b0) begin
                    /* cache not miss */
                    if (hit) begin
                        cache_miss <= 1'b0;
                        state <= 3'b000;
                    end
                    /* cache miss */
                    else begin
                        cache_miss <= 1'b1;
                        araddr <= {current_raddr[31:5], 5'b00000};
                        arvalid <= 1'b1;
                        rready <= 1'b0;
                        if (arready) begin
                            state <= 3'b001;
                        end
                    end
                    end
                end
                3'b001: begin
                    arvalid <= 1'b0;
                    rready <= 1'b1;
                    if (rvalid) begin   // 当 rvalid 为高时接收 rdata
                        cache_we <= 1'b1;
                        handshake <= handshake + 1;
                        current_wdata <= rdata;
                        if ({araddr[31:5], handshake, 2'b00} == current_raddr) begin  // 捕获请求字
                            current_rdata <= current_wdata;
                        end
                        if (rlast) begin
                            state <= 3'b010;
                        end
                    end
                end
                3'b010: begin
                    if ({araddr[31:5], handshake, 2'b00} == current_raddr) begin  // 捕获请求字
                        current_rdata <= current_wdata;
                    end
                    cache_miss <= 1'b0;
                    arvalid <= 1'b0;
                    rready <= 1'b0;
                    cache_we <= 1'b0;
                    state <= 3'b011;
                    init <= 1'b0;
                end
                /* 在该周期返回请求字, 读出被阻塞请求地址的数据, 并接收新地址 */
                3'b011: begin
                    if (cpu_req && cache_addr_ok) begin // 地址握手成功
                        current_raddr <= cpu_addr;      // 处理连续两条请求 miss 的情况
                        state <= 3'b000;
                    end
                end
            endcase
        end
    end
    
    assign cpu_raddr = current_raddr;                           // 仅供选路模块更新块信息使用
    assign upd_we = ((state == 3'b000) && (hit != 4'b0000));    // 选路模块块信息更新使能信号
    assign ram_we = cache_we;                                   // 将数据从主存写回 Cache 的使能信号
    assign cache_wdata = current_wdata;                         // 当前从主存写回 Cache 的数据

    /* Sram-like */
    assign cache_rdata = ((state == 3'b000) && (hit == 4'b0001)) ? ram_rdata[0] :
                         ((state == 3'b000) && (hit == 4'b0010)) ? ram_rdata[1] :
                         ((state == 3'b000) && (hit == 4'b0100)) ? ram_rdata[2] :
                         ((state == 3'b000) && (hit == 4'b1000)) ? ram_rdata[3] :
                         (state == 3'b011) ? current_rdata : 32'b0;
    // 在 Cache 成功将当前数据返回后接收新的地址
    assign cache_addr_ok = ((state == 3'b000) && ((hit != 4'b0000) || init)) || (state == 3'b011);
    // 如果缓存命中, cache_rdata在状态000的时钟上升沿返回;
    // 如果缓存不命中, cache_rdata在状态011的时钟上升沿返回.
    assign cache_data_ok = ((state == 3'b000) && (hit != 4'b0000)) || (state == 3'b011);
    /* AXI */
    assign arid = 4'b0000;

endmodule
