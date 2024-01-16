# 实验二：分支预测
现有一个五级流水线CPU，要求你为其实现一个动态分支预测器，解决分支指令导致的控制相关，实现效率较高的取指。</br>
在本实验中，你需要实现一个具有这样的接口的分支预测器：</br>

```verilog
module branch_predictor(
    input           clk,        //时钟信号，必须与CPU保持一致
    input           resetn,     //低有效复位信号，必须与CPU保持一致

    //供CPU第一级流水段使用的接口：
    //上一个指令地址
    input[31:0]     old_PC,
    //这周期是否需要更新PC（进行分支预测）
    input           predict_en,
    //预测出的下一个指令地址
    output[31:0]    new_PC,
    //是否被预测为执行转移的转移指令
    output          predict_jump,

    //分支预测器更新接口：
    //更新使能
    input           upd_en,
    //转移指令地址
    input[31:0]     upd_addr,
    //是否为转移指令
    input           upd_jumpinst,
    //若为转移指令，则是否转移
    input           upd_jump,
    //是否预测失败
    input           upd_predfail,
    //转移指令本身的目标地址（无论是否转移）
    input[31:0]     upd_target
);

endmodule
```
