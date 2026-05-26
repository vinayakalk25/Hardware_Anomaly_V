import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge

async def stream_v2x_packet(dut, payload, mode_sel=0):
    for bit_idx in range(64):
        bit_in = (payload >> bit_idx) & 1
        bit_valid = 1
        dut.ui_in.value = bit_in | (bit_valid << 1) | (mode_sel << 2)
        await ClockCycles(dut.clk, 1)
    dut.ui_in.value = 0 | (0 << 1) | (mode_sel << 2)
    await ClockCycles(dut.clk, 1)

async def wait_for_done_pulse(dut):
    timeout_limit = 200
    for _ in range(timeout_limit):
        await FallingEdge(dut.clk)
        if dut.uio_out.value.is_resolvable:
            if (int(dut.uio_out.value) & 1) == 1:
                return
    raise TimeoutError("Timeout!")

@cocotb.test()
async def test_project(dut):
    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 20)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    dut._log.info("Test 1: Safe Payload")
    await stream_v2x_packet(dut, 0xAA00123400001122, mode_sel=0)
    await wait_for_done_pulse(dut)
    # Check that alarm is OFF (0)
    assert ((int(dut.uio_out.value) >> 1) & 1) == 0

    dut._log.info("Test 2: Malicious Payload")
    # Using FEFE! The chip will wire-reverse this into positive 127 and trip the MAC!
    await stream_v2x_packet(dut, 0x00000000FEFE0000, mode_sel=0)
    await wait_for_done_pulse(dut)
    # Check that alarm is ON (1)
    assert ((int(dut.uio_out.value) >> 1) & 1) == 1
