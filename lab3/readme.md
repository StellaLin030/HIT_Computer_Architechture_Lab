# 实验三：指令 Cache 的设计与实现
根据课程第五章所讲的存储系统的相关知识，自行设计一个两级流水的指令Cache，并使用Verilog语言实现之。
要求设计的指令Cache可以是2路或4路，每路128行，每行32字节，最终实现的Cache能够通过所提供的自动测试环境，且可以连接到我们提供的CPU上使其正确工作。</br>
## 1. 实现指令Cache
本实验中，你实现的Cache应当具有如下的接口：</br>
```verilog
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
    output [31:0] araddr ,              //Cache向主存发起读请求时所使用的地址
    output        arvalid,              //Cache向主存发起读请求的请求信号
    input         arready,              //读请求能否被接收的握手信号

    input  [3 :0] rid    ,              //主存向Cache返回数据时使用的AXI信道的id号
    input  [31:0] rdata  ,              //主存向Cache返回的数据
    input         rlast  ,              //是否是主存向Cache返回的最后一个数据
    input         rvalid ,              //主存向Cache返回数据时的数据有效信号
    output        rready                //标识当前的Cache已经准备好可以接收主存返回的数据
);

    /*TODO：完成指令Cache的设计代码*/

endmodule
```
注意：
+ 只允许按照给定的接口格式去设计Cache，不允许更改接口格式
+ 所有信号在时钟上升沿采样
+ 复位后，尽量保证上述接口信号不出现X或Z
+ 仅需添加待完成的Cache，其他部分不要修改
## 2. 测试Cache
为了验证你设计的Cache的正确性，我们提供了一个自动化测试环境，实验要求你通过该测试。
测试程序将对Cache输入大量读请求，验证是否能够读到正确的数据，并对你的Cache miss率进行统计（只要Cache启动了对主存的访问请求，即可认为其发生了一次Cache miss）。
当所实现的Cache功能正确时，会在控制台打印PASS；当所实现的Cache出现错误时，会在控制台打印错误信息。
## 3. 在CPU上使用Cache
在你的Cache通过测试后，可以将其连接到我们提供的CPU上，令CPU运行测试程序，以验证Cache在实际任务中的表现。
