<p align="center"><img src="../../wiki/images/swiftneslogo.png" alt="SwiftNES"/></p>
# SwiftNES - The Accurate Swift NES Emulator
SwiftNES is a NES emulator aiming to be one of the most accurate in existence, using Apple's latest technologies Swift and Metal.
SwiftNES uses all original code, as I wanted to write the emulator from scratch. As such, certain design decisions were made that I now know were not optimal.
All NES hardware operations are emulated on a cycle-by-cycle basis. While this makes the emulator considerably more resource hungry, it ensures absolute accuracy to the hardware, bugs and all.

<p align="center">
	<img src="../../wiki/images/screenshots/dk.png" alt="Donkey Kong"/>
	<img src="../../wiki/images/screenshots/duckhunt.png" alt="Duck Hunt"/>
	<img src="../../wiki/images/screenshots/smb.png" alt="Super Mario Bros."/>
	<img src="../../wiki/images/screenshots/excitebike.png" alt="Excitebike"/>
</p>

## Features

* Full cycle accurate 6502 emulator, including cycle accurate timing on all illegal opcodes, minus decimal mode emulation (which is not used by the NES)
* Cycle accurate 2C02 PPU emulation, with in-progress open bus handling
* Work-in-progress 2A03 APU (slight bugs in sound reproduction)
* Mapper 0 support (more mappers coming soon)
* Retina Mac display support, along with display resizing using pixel doubling

## Accuracy

The final goal behind SwiftNES is to make it one of the most accurate NES emulators in existence. This has caused the design to move away from efficiency and towards hardware accuracy.
In order to keep the system simple, the various components making up the NES (the CPU, PPU, and APU) are emulated on a cycle-by-cycle basis, using the CPU clock cycle as the base tick.
This has the added bonus of increasing the similarity to the inner workings of the NES.

In order to verify the accuracy of each SwiftNES build, the project includes a unit testing system using XCTest that automatically tests SwiftNES against verified NES test ROMs (see [this collection](https://github.com/christopherpow/nes-test-roms)). Although some of the NES test ROMs in the above repo are not actively being tested, the emulator passes 62 of the 72 tests that are run, with this number rising every day.

## Challenges

SwiftNES has faced several challenges throughout development, mainly due to poor documentation. The PPU has presented innumerable problems, mainly due to its relative complexity
to the rest of the NES, and the inability to properly test every feature due to its visual nature. The smallest tweaks in the PPU can have very large results, especially with NMI (Vblank) timing.
At some point, the CPU was transitioned to using read and write cycles to time instructions, as opposed to using a lookup table to obtain the cycle length of an opcode. This both decreased CPU usage
dramatically and significantly increased the accuracy of the emulator.

Currently, I am struggling to debug various sound issues without a real indication of whether the issues are occurring. Additionally, I recently discovered several bugs with how CPU interrupts were handled, and therefore the interrupt system is currently undergoing a rewrite.

## Todo

- [ ] Ensure the CPU properly times all interrupt edge cases correctly, such as NMIs during a BRK, etc...
- [ ] Clean up PPU open bus, ensuring reads of the PPU registers properly returns data off of the bus
- [ ] Fix slight sound reproduction issues
- [ ] Add additional mappers, particularly Mapper 3 ([the Nintendo MMC3](http://wiki.nesdev.com/w/index.php/MMC3))
