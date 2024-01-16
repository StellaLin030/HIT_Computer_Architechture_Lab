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

    //  Sram-Like�ӿ��źţ�����CPU����Cache
    input         cpu_req      ,    //��CPU������Cache
    input  [31:0] cpu_addr     ,    //��CPU������Cache
    output [31:0] cache_rdata  ,    //��Cache���ظ�CPU
    output        cache_addr_ok,    //��Cache���ظ�CPU
    output        cache_data_ok,    //��Cache���ظ�CPU

    //  AXI�ӿ��źţ�����Cache��������
    output [3 :0] arid   ,              //Cache�����淢�������ʱʹ�õ�AXI�ŵ���id��
    output reg [31:0] araddr ,              //Cache�����淢�������ʱ��ʹ�õĵ�ַ
    output reg        arvalid,              //Cache�����淢�������������ź�
    input         arready,              //�������ܷ񱻽��յ������ź�

    input  [3 :0] rid    ,              //������Cache��������ʱʹ�õ�AXI�ŵ���id��
    input  [31:0] rdata  ,              //������Cache���ص�����
    input         rlast  ,              //�Ƿ���������Cache���ص����һ������
    input         rvalid ,              //������Cache��������ʱ��������Ч�ź�
    output reg        rready                //��ʶ��ǰ��Cache�Ѿ�׼���ÿ��Խ������淵�ص�����
);

    integer j;

    /* wire */
    wire        upd_we;             // ѡ·�������ź�
    wire        ram_we;             // Cache дʹ���ź�
    wire [1:0]  way_sel;            // ѡ·�������ѡ���ź�
    wire [3:0]  hit;                // ��·�����ź�
    wire [3:0]  valid;              // ��·��Чλ
    wire [31:0] ram_rdata [0:3];    // ��·��������
    wire [31:0] cpu_raddr;          // ��ǰ����ĵ�ַ
    wire [31:0] cache_wdata;        // ��ǰ������д�� Cache ������

    /* reg */
    reg         init;               // ��ʼ״̬
    reg         cache_miss;         // ���治�����ź�
    reg         cache_we;           // Cache дʹ���źżĴ���
    reg [2:0]   state;              // ״̬�Ĵ���
    reg [2:0]   handshake;          // ��ǰ�������ִ���
    reg [31:0]  current_raddr;      // �ڶ�����ˮ�ε�ǰ Cache ����� CPU �����ַ
    reg [31:0]  current_rdata;      // ��ǰ�����������
    reg [31:0]  current_wdata;      // ��ǰ���������������

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

    /* ʵ����4 �� data_ram, 4 �� tag_ram �� 1 �� way_control ģ�� */
    genvar i;
    generate
        for (i=0; i<4; i=i+1) begin: data_ram_gen
            block_ram u_data_ram(
                // д�˿�
                .clka(clk),
                .wea(ram_we && (way_sel == i)),
                .addra({araddr[11:5], handshake}),
                .dina(cache_wdata),
                // ���˿�
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
                // д�˿�
                .wen(ram_we && (way_sel == i)),
                .valid_wdata(1'b1),
                .tag_wdata(araddr[31:12]),
                .windex(araddr[11:5]),
                // ���˿�
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
                    if (rvalid) begin   // �� rvalid Ϊ��ʱ���� rdata
                        cache_we <= 1'b1;
                        handshake <= handshake + 1;
                        current_wdata <= rdata;
                        if ({araddr[31:5], handshake, 2'b00} == current_raddr) begin  // ����������
                            current_rdata <= current_wdata;
                        end
                        if (rlast) begin
                            state <= 3'b010;
                        end
                    end
                end
                3'b010: begin
                    if ({araddr[31:5], handshake, 2'b00} == current_raddr) begin  // ����������
                        current_rdata <= current_wdata;
                    end
                    cache_miss <= 1'b0;
                    arvalid <= 1'b0;
                    rready <= 1'b0;
                    cache_we <= 1'b0;
                    state <= 3'b011;
                    init <= 1'b0;
                end
                /* �ڸ����ڷ���������, ���������������ַ������, �������µ�ַ */
                3'b011: begin
                    if (cpu_req && cache_addr_ok) begin // ��ַ���ֳɹ�
                        current_raddr <= cpu_addr;      // ���������������� miss �����
                        state <= 3'b000;
                    end
                end
            endcase
        end
    end
    
    assign cpu_raddr = current_raddr;                           // ����ѡ·ģ����¿���Ϣʹ��
    assign upd_we = ((state == 3'b000) && (hit != 4'b0000));    // ѡ·ģ�����Ϣ����ʹ���ź�
    assign ram_we = cache_we;                                   // �����ݴ�����д�� Cache ��ʹ���ź�
    assign cache_wdata = current_wdata;                         // ��ǰ������д�� Cache ������

    /* Sram-like */
    assign cache_rdata = ((state == 3'b000) && (hit == 4'b0001)) ? ram_rdata[0] :
                         ((state == 3'b000) && (hit == 4'b0010)) ? ram_rdata[1] :
                         ((state == 3'b000) && (hit == 4'b0100)) ? ram_rdata[2] :
                         ((state == 3'b000) && (hit == 4'b1000)) ? ram_rdata[3] :
                         (state == 3'b011) ? current_rdata : 32'b0;
    // �� Cache �ɹ�����ǰ���ݷ��غ�����µĵ�ַ
    assign cache_addr_ok = ((state == 3'b000) && ((hit != 4'b0000) || init)) || (state == 3'b011);
    // �����������, cache_rdata��״̬000��ʱ�������ط���;
    // ������治����, cache_rdata��״̬011��ʱ�������ط���.
    assign cache_data_ok = ((state == 3'b000) && (hit != 4'b0000)) || (state == 3'b011);
    /* AXI */
    assign arid = 4'b0000;

endmodule
