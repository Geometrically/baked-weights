![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg)

# Baked-Weights Shakespeare GPT

This chip writes text in the style of Shakespeare. It is a very small language model, and
the whole model is built into the silicon.

All 22,400 weights of this model sit in a read-only memory (a ROM) inside the tile.
They were fixed when the chip was made. There is no way to load new weights, and there is
no memory interface. The chip can only write Shakespeare.

Each weight is one of three values: -1, 0 or +1.
The ternary weights needs no multipliers, because the hardware only adds the input, subtracts
the input, or skips it. Five weights also pack into one byte. That is how a complete
language model fits in 4,480 bytes of ROM on a 4x4 Tiny Tapeout tile.

The chip does the heavy part of the model, not all of it. A microcontroller on the demo
board turns a character into 80 bytes of numbers and sends them to the chip. The chip runs
both of its layers, reads its weights from its own ROM, and sends 40 bytes back. The
microcontroller turns those bytes into the next character. See
[docs/info.md](docs/info.md) for the pin protocol, the full list of numbers, and the test
steps.

## Clock

The chip runs at **22.2 MHz**. One clock period is **45 ns**. The whole design uses that
one clock, and every flip-flop changes on its rising edge. The reset input `rst_n` is
synchronous, so the clock must run for a reset to take effect.

## License

Apache License 2.0 — see [LICENSE](LICENSE).

The ROM in `macro/` is a derived work of an Apache-2.0 layout by Sylvain Munaut / tnt.

## AI Generated Code + Inspirations
I had initally hoped to complete this project by hand before the tapeout deadline, but due to some personal stuff that came up, I regrettably did not have time. Much of the code in this repository is AI generated, while the design was made by me. The idea for this chip was heavily inspired by Taalas HC1.
