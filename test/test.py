# Smoke test for the Tiny Tapeout gl_test job.
#
# It proves the netlist elaborates, resets, and comes up in the input phase. It
# does NOT check the model, and is deliberately kept small.

import cocotb
from cocotb.triggers import Timer

UIO_OE = 0xE6  # a 1 means the chip drives that pin; see docs/info.md
DBG_BUSY, DBG_RX, DBG_TX = 5, 6, 7


async def tick(dut, n=1):
    """One test-clock period (20 ns; the chip itself runs at 45 ns).

    rst_n is synchronous, so the clock must run.
    """
    for _ in range(n):
        dut.clk.value = 0
        await Timer(10, units="ns")
        dut.clk.value = 1
        await Timer(10, units="ns")


@cocotb.test()
async def test_reset_enters_input_phase(dut):
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.clk.value = 0
    dut.rst_n.value = 0

    # At least 4 clocks low with the clock running; see docs/info.md.
    await tick(dut, 5)
    dut.rst_n.value = 1
    await tick(dut, 2)

    oe = int(dut.uio_oe.value)
    assert oe == UIO_OE, f"uio_oe is {oe:#04x}, expected {UIO_OE:#04x}"

    out = int(dut.uio_out.value)
    phase = [(out >> b) & 1 for b in (DBG_BUSY, DBG_RX, DBG_TX)]
    assert sum(phase) == 1, f"phase bits are not one-hot: {phase}"
    assert phase[1] == 1, "after reset the chip must be in the input phase (dbg_rx)"

    dut._log.info("reset OK: uio_oe=0xE6, phase=dbg_rx")
