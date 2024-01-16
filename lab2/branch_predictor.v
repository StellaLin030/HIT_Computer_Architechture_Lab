module branch_predictor(
    input           clk,        //ʱ���źţ�������CPU����һ��
    input           resetn,     //����Ч��λ�źţ�������CPU����һ��

    //��CPU��һ����ˮ��ʹ�õĽӿڣ�
    //��һ��ָ���ַ
    input[31:0]     old_PC,
    //�������Ƿ���Ҫ����PC�����з�֧Ԥ�⣩
    input           predict_en,
    //Ԥ�������һ��ָ���ַ
    output reg [31:0]    new_PC,
    //�Ƿ�Ԥ��Ϊִ��ת�Ƶ�ת��ָ��
    output reg           predict_jump,

    //��֧Ԥ�������½ӿڣ�
    //����ʹ��
    input           upd_en,
    //ת��ָ���ַ
    input[31:0]     upd_addr,
    //�Ƿ�Ϊת��ָ��    // �Ҿ����������û��   
    input           upd_jumpinst,
    //��Ϊת��ָ����Ƿ�ת��
    input           upd_jump,
    //�Ƿ�Ԥ��ʧ��
    input           upd_predfail,
    //ת��ָ����Ŀ���ַ�������Ƿ�ת�ƣ�
    input[31:0]     upd_target
);

    parameter   BUFFER_ADDR_LEN = 4;                // ��������ַ����
    parameter   BUFFER_SIZE = 1<<BUFFER_ADDR_LEN;   // ��������С 2^BUFFER_ADDR_LEN
    parameter   TAG_LEN = 32-BUFFER_ADDR_LEN-2;     // ���ڱ�ʶ��ַ��tag

    wire [TAG_LEN-1:0]            old_PC_tag, upd_addr_tag;
    wire [BUFFER_ADDR_LEN-1:0]  old_PC_index, upd_addr_index;
    wire [1:0]                  old_PC_offset, upd_addr_offset;

    assign {old_PC_tag, old_PC_index, old_PC_offset} = old_PC;
    assign {upd_addr_tag, upd_addr_index, upd_addr_offset} = upd_addr;

    reg [TAG_LEN-1:0]   branch_inst_tag     [BUFFER_SIZE-1:0];   // ��ָ֧���ַtag�Ĵ���
    reg [31:0]          branch_tar_addr     [BUFFER_SIZE-1:0];   // ��֧Ŀ���ַ�Ĵ���
    reg [1:0]           branch_predict      [BUFFER_SIZE-1:0];   // ��֧Ԥ���ʶ �˴�ʹ��2λ״̬��

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
        if ((branch_inst_tag[old_PC_index] == old_PC_tag) && ((branch_predict[old_PC_index] == 2'b11) || (branch_predict[old_PC_index] == 2'b10))) begin  // ���з�֧Ԥ��
            new_PC = branch_tar_addr[old_PC_index];
            predict_jump = 1'b1;
        end
        else begin  // state = 01 or 00 �����з�֧Ԥ��
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
            if ((upd_jumpinst) && (upd_jump)) begin     // �ɹ���ָ֧��
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
            else if (upd_predfail) begin   // ��֧ʧ�ܣ�Ԥ�����
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