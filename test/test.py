# SPDX-FileCopyrightText: © 2026 Xiaobo Li
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge

@cocotb.test()
async def test_spi_slave(dut):
    dut._log.info("开始 SPI Slave 仿真测试")

    # 1. 设置主时钟 (10MHz)
    # 根据你的 config.json，主频约为 50MHz (20ns)，这里设定 20ns 周期
    clock = Clock(dut.clk, 20, unit="ns") 
    cocotb.start_soon(clock.start())

    # 2. 复位初始化
    dut._log.info("执行系统复位")
    dut.ena.value = 1
    dut.ui_in.value = 0      # ui_in[0]=sck, [1]=cs_n, [2]=mosi
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5) # 等待同步链稳定

    # 定义引脚简写
    # ui_in 映射: [0]=sck, [1]=cs_n, [2]=mosi
    def set_spi_inputs(sck, cs_n, mosi):
        dut.ui_in.value = (mosi << 2) | (cs_n << 1) | sck

    dut._log.info("模拟 SPI 读取过程 (读取芯片预装载的 0xA5)")
    
    # 3. 模拟 SPI 传输 (Mode 0)
    # 拉低片选开始传输
    set_spi_inputs(sck=0, cs_n=0, mosi=0)
    await ClockCycles(dut.clk, 5) # 补偿同步链延迟

    expected_data = 0xA5
    read_data = 0

    for i in range(8):
        # SCK 上升沿：芯片会采样 MOSI 并准备移出 MISO
        set_spi_inputs(sck=1, cs_n=0, mosi=0)
        await ClockCycles(dut.clk, 5) # 必须等待，让芯片内部检测到同步后的 SCK 上升沿
        
        # 采样 MISO (uo_out[0])
        # 将 LogicArray 转换为整数，然后再进行位移操作
        uo_val = int(dut.uo_out.value)
        bit = (uo_val >> 0) & 1
        read_data = (read_data << 1) | bit
        
        # SCK 下降沿
        set_spi_inputs(sck=0, cs_n=0, mosi=0)
        await ClockCycles(dut.clk, 5)

    # 4. 结果校验
    dut._log.info(f"读取到的数据: {hex(read_data)}")
    assert read_data == expected_data, f"数据不匹配！期望 {hex(expected_data)}，实际得到 {hex(read_data)}"

    # 释放片选
    set_spi_inputs(sck=0, cs_n=1, mosi=0)
    await ClockCycles(dut.clk, 5)
    dut._log.info("SPI 测试完成！")
