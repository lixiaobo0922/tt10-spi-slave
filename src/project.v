/*
 * Copyright (c) 2026 Xiaobo Li
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_spi_slave_lixiaobo (
    input  wire [7:0] ui_in,    // 专用输入: [0]=sck, [1]=cs_n, [2]=mosi
    output wire [7:0] uo_out,   // 专用输出: [0]=miso
    input  wire [7:0] uio_in,   // 双向输入 (未用到)
    output wire [7:0] uio_out,  // 双向输出 (未用到)
    output wire [7:0] uio_oe,   // 双向使能 (置0)
    input  wire       ena,      // 设计使能信号
    input  wire       clk,      // 系统主时钟
    input  wire       rst_n     // 异步复位 (低电平有效)
);

    // --- 1. 同步链 (Metastability Hardening) ---
    // ASIC 内部寄存器对外部信号极其敏感，必须进行同步处理
    reg [2:0] r_sck_sync, r_cs_sync, r_mosi_sync;

    always @(posedge clk) begin
        if (!rst_n) begin
            r_sck_sync  <= 3'b0;
            r_cs_sync   <= 3'b1; // 片选默认拉高
            r_mosi_sync <= 3'b0;
        end else begin
            r_sck_sync  <= {r_sck_sync[1:0],  ui_in[0]}; // sck
            r_cs_sync   <= {r_cs_sync[1:0],   ui_in[1]}; // cs_n
            r_mosi_sync <= {r_mosi_sync[1:0],  ui_in[2]}; // mosi
        end
    end

    // 使用同步后的信号（滞后 2-3 个 clk 周期以保安全）
    wire w_sck  = r_sck_sync[2];
    wire w_cs_n = r_cs_sync[2];
    wire w_mosi = r_mosi_sync[2];

    // 边沿检测
    reg r_sck_dly;
    always @(posedge clk) r_sck_dly <= w_sck;
    wire w_sck_posedge = (w_sck == 1'b1 && r_sck_dly == 1'b0);

    // --- 2. SPI 核心逻辑 (SPI Mode 0) ---
    reg [2:0] r_bit_count;
    reg [7:0] r_rx_data;
    reg [7:0] r_tx_shift = 8'hA5; // 测试预装载数据: 0xA5
    reg       r_miso;

    always @(posedge clk) begin
        if (!rst_n || w_cs_n) begin
            r_bit_count <= 3'b0;
            r_rx_data   <= 8'b0;
            r_miso      <= 1'b0;
            r_tx_shift  <= 8'hA5; // 每次选中时重置数据
        end else if (w_sck_posedge) begin
            // 采样 MOSI
            r_rx_data <= {r_rx_data[6:0], w_mosi};
            
            // 更新 MISO (移位)
            r_miso <= r_tx_shift[7];
            r_tx_shift <= {r_tx_shift[6:0], 1'b0};
            
            r_bit_count <= r_bit_count + 1'b1;
        end
    end

    // --- 3. 输出赋值 ---
    assign uo_out[0] = r_miso;     // miso 连接到 uo_out[0]
    assign uo_out[7:1] = 7'b0;     // 未使用引脚置零，避免功耗漂移
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;         // 确保双向 IO 处于高阻/输入模式

endmodule
