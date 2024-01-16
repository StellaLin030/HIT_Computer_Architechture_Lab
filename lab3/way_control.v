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
    input       upd_we,         // ������ؼĴ�����дʹ���ź�
    input [3:0] hit,            // ��·���������
    input [3:0] upd_valid,      // ��·����Чλ
    input [6:0] upd_index,      // ��ǰҪ�����滻λ����
    /* select way */
    input       sel_en,         // ѡ·��ʹ���ź�
    input [6:0] wdata_index,    // ��ǰ������д�����ݵĿ�����
    output reg [1:0]    select  // �����ѡ·�ź�
);

    reg [3:0]   valid   [0:127];   // ά����·��ÿһ�е���Чλ
    reg [1:0]   replace [0:127][0:3];   // ά����·��ÿһ�е��滻λ

    integer i, j;
    initial begin
        for (i=0; i<128; i=i+1) begin
            for (j=0; j<4; j=j+1) begin
                valid[i][j] <= 1'b0;
                replace[i][j] <= j;     // ��ʼ�滻λΪ��ǰ����·����Ŷ�Ӧ�Ķ�������ֵ
            end
        end
    end

    /* ÿ�γɹ���ȡ Cache ���ݺ�, �����滻λ����Чλ��ֵ */
    always@(upd_we) begin
        for (i=0; i<4; i=i+1) begin
            /* ������Чλ */
            valid[upd_index][i] <= upd_valid[i];

            /* �����滻λ */
            if (hit[i]) begin   // �� i ·����
                replace[upd_index][i] <= 2'b11; // �����滻λΪ 11, ��ʾ���ʹ��
            end
            else if (replace[upd_index][i]) begin   // �� i ·δ����, ���滻λ��Ϊ 00
                replace[upd_index][i] <= replace[upd_index][i] - 2'b01; // ��ǰ�滻λ�� 1
            end
            // �� i ·δ�������滻λΪ 00 ʱ��������
        end
    end

    /* ������д������ʱ��Ҫ����ѡ· */
    /* ����: д��Ҳ��Ҫ�����滻λ����Чλ, ��д���һ����ʱ���� */
    always@(sel_en) begin
        /* ��·��Ӧ�� Cache �ж�����Ч����� */
        if (valid[wdata_index] == 4'b1111) begin
            for (i=0; i<4; i=i+1) begin
                if (replace[wdata_index][i] == 2'b00) begin // ѡ���滻λΪ 00 ����·��Ϊ���滻��·
                    select <= i;
                end
            end
        end
        /* ������Ч·����� */
        else begin
            for (i=3; i>=0; i=i-1) begin
                if (valid[wdata_index][i] == 0) begin
                    select <= i;    // ѡ����Ч·�������С��һ·�滻
                end
            end
        end
        /* д�����һ����ʱ������λ��Ϣ */
        if (wdata_index[2:0] == 3'b111) begin
            for (i=0; i<4; i=i+1) begin
                if (i == select) begin
                    valid[wdata_index][i] <= 1;         // ���±��滻��·��ЧλΪ 1
                    replace[wdata_index][i] <= 2'b11;   // �����滻λ
                end
                else if (replace[wdata_index][i]) begin
                    replace[wdata_index][i] <= replace[wdata_index][i] - 2'b01; // �����滻λ
                end
            end
        end
    end

endmodule