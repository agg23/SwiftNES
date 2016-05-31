//
//  SwiftNESTests.swift
//  SwiftNESTests
//
//  Created by Adam Gastineau on 3/23/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import XCTest
@testable import SwiftNES

let defaultPath = "/Users/adam/testROMs/";

class SwiftNESTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
	
	func romTest(path: String, testAddress: Int, desiredResult: UInt8, intermediary: UInt8, maxInstructions: Int) {
		let logger = Logger(path: "/Users/adam/nestesting.log");
		
		let controllerIO = ControllerIO();
		
		let mapper = Mapper();
		
		let mainMemory = CPUMemory(mapper: mapper);
		mainMemory.controllerIO = controllerIO;
		
		let ppuMemory = PPUMemory(mapper: mapper);
		let fileIO = FileIO(mainMemory: mainMemory, ppuMemory: ppuMemory);
		XCTAssert(fileIO.loadFile(path));
		
		let ppu = PPU(cpuMemory: mainMemory, ppuMemory: ppuMemory);
		
		let apu = APU(memory: mainMemory);
		
		mainMemory.ppu = ppu;
		mainMemory.apu = apu;
		
		let cpu = CPU(mainMemory: mainMemory, ppu: ppu, apu: apu, logger: logger);
		apu.cpu = cpu;
		ppu.cpu = cpu;
		
		cpu.reset();
		
		var intermediaryFound = false;
		
		var instructionCount = 0;
		
		while(cpu.step()) {
			if(instructionCount > maxInstructions) {
				XCTAssertGreaterThan(maxInstructions, instructionCount);
				return;
			}
			
			if(cpu.errorOccured) {
				XCTAssert(!cpu.errorOccured);
				return;
			}
			
			let result = mainMemory.readMemory(testAddress);
			
			if(result == intermediary) {
				intermediaryFound = true;
			} else if(intermediaryFound && result != intermediary) {
				XCTAssertEqual(result, desiredResult);
				return;
			}
			
			instructionCount += 1;

		}
	}
	
	// MARK: - CPU Instruction Testing
	
	// MARK: - blargg's CPU Behavior Instruction Tests
	
	func testCPUBasics() {
		romTest(defaultPath + "instr_test-v5/rom_singles/01-basics.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testImplied() {
		romTest(defaultPath + "instr_test-v5/rom_singles/02-implied.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testImmediate() {
		romTest(defaultPath + "instr_test-v5/rom_singles/03-immediate.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testZeroPage() {
		romTest(defaultPath + "instr_test-v5/rom_singles/04-zero_page.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testZeroPageXY() {
		romTest(defaultPath + "instr_test-v5/rom_singles/05-zp_xy.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testAbsolute() {
		romTest(defaultPath + "instr_test-v5/rom_singles/06-absolute.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testAbsoluteXY() {
		romTest(defaultPath + "instr_test-v5/rom_singles/07-abs_xy.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testIndirectX() {
		romTest(defaultPath + "instr_test-v5/rom_singles/08-ind_x.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testIndirectY() {
		romTest(defaultPath + "instr_test-v5/rom_singles/09-ind_y.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testBranches() {
		romTest(defaultPath + "instr_test-v5/rom_singles/10-branches.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testStack() {
		romTest(defaultPath + "instr_test-v5/rom_singles/11-stack.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testJump() {
		romTest(defaultPath + "instr_test-v5/rom_singles/12-jmp_jsr.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testRTS() {
		romTest(defaultPath + "instr_test-v5/rom_singles/13-rts.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testRTI() {
		romTest(defaultPath + "instr_test-v5/rom_singles/14-rti.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testBRK() {
		romTest(defaultPath + "instr_test-v5/rom_singles/15-brk.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testSpecialInstructions() {
		romTest(defaultPath + "instr_test-v5/rom_singles/16-special.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	// MARK: - Instruction Timing
	
	func testInstructionTiming() {
		// Needs implemented APU
		romTest(defaultPath + "instr_timing/rom_singles/1-instr_timing.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 50000000);
	}
	
	func testBranchTiming() {
		// Needs implemented APU
		romTest(defaultPath + "instr_timing/rom_singles/2-branch_timing.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 50000000);
	}
	
	// MARK: - Instruction Execution from Any Address
	
	func testCPUExecSpace() {
		romTest(defaultPath + "cpu_exec_space/test_cpu_exec_space_ppuio.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	// MARK: - Interrupts
	
	func testCLILatency() {
		// Needs implemented APU
		romTest(defaultPath + "cpu_interrupts_v2/rom_singles/1-cli_latency.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testNMIBRK() {
		romTest(defaultPath + "cpu_interrupts_v2/rom_singles/2-nmi_and_brk.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testNMIIRQ() {
		romTest(defaultPath + "cpu_interrupts_v2/rom_singles/3-nmi_and_irq.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testIRQDMA() {
		romTest(defaultPath + "cpu_interrupts_v2/rom_singles/4-irq_and_dma.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testBranchDelaysIRQ() {
		romTest(defaultPath + "cpu_interrupts_v2/rom_singles/5-branch_delays_irq.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	// MARK: - Dummy Read Testing
	
	func testABSWrap() {
		romTest(defaultPath + "instr_misc/rom_singles/01-abs_x_wrap.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
    
	func testBranchWrap() {
		romTest(defaultPath + "instr_misc/rom_singles/02-branch_wrap.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testDummyReads() {
		romTest(defaultPath + "instr_misc/rom_singles/03-dummy_reads.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testDummyReadsAPU() {
		// Needs implemented APU
		romTest(defaultPath + "instr_misc/rom_singles/04-dummy_reads_apu.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	// MARK: - PPU Testing
	
	func testOAMRead() {
		romTest(defaultPath + "oam_read/oam_read.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testOAMStress() {
		romTest(defaultPath + "oam_stress/oam_stress.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testPPUOpenBus() {
		romTest(defaultPath + "ppu_open_bus/ppu_open_bus.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	// Blargg's PPU tests cannot be automated
	
	func testPowerUpPaletteConst() {
		// Expected failure
		XCTAssert(false);
	}
	
	func testSpriteRAMConst() {
		XCTAssertEqual(1, 1);
	}
	
	func testVBLClearTime() {
		XCTAssertEqual(1, 1);
	}
	
	func testPaletteRAMConst() {
		XCTAssertEqual(1, 1);
	}
	
	func testVRAMAccessConst() {
		XCTAssertEqual(1, 1);
	}
	
	// Blargg's Sprite 0 Hit tests cannot be automated.
	
	func testSpriteHitBasicsConst() {
		XCTAssertEqual(1, 1);
	}
	
	func testSpriteHitAlignmentConst() {
		XCTAssertEqual(1, 1);
	}
	
	func testSpriteHitCornersConst() {
		XCTAssertEqual(1, 1);
	}
	
	func testSpriteHitFlipConst() {
		XCTAssertEqual(1, 1);
	}
	
	func testSpriteHitLeftClipConst() {
		XCTAssertEqual(1, 1);
	}
	
	func testSpriteHitRightEdgeConst() {
		XCTAssertEqual(1, 1);
	}
	
	func testSpriteHitScreenBottomConst() {
		XCTAssertEqual(1, 1);
	}
	
	func testSpriteHitDoubleHeightConst() {
		XCTAssertEqual(1, 1);
	}
	
	func testSpriteHitTimingBasicsConst() {
		XCTAssertEqual(1, 1);
	}
	
	func testSpriteHitTimingOrderConst() {
		XCTAssertEqual(1, 1);
	}
	
	func testSpriteHitEdgeTimingConst() {
		XCTAssertEqual(1, 1);
	}
	
	// Blargg's new VBL/NMI Timing tests cannot be automated
	
	func testVBLNMIFrameBasicsConst() {
		XCTAssertEqual(1, 1);
	}
	
	func testVBLTimingConst() {
		XCTAssertEqual(1, 1);
	}
	
	func testEvenOddFramesConst() {
		XCTAssertEqual(1, 1);
	}
	
	func testVBLClearTimingConst() {
		XCTAssertEqual(1, 1);
	}
	
	func testNMISuppressionConst() {
		XCTAssertEqual(1, 1);
	}
	
	func testNMIDisableConst() {
		XCTAssertEqual(1, 1);
	}
	
	func testNMITimingConst() {
		XCTAssertEqual(1, 1);
	}
	
	// MARK: - VBlank flag and NMI Testing
	
	func testVBLBasics() {
		romTest(defaultPath + "ppu_vbl_nmi/rom_singles/01-vbl_basics.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testVBLSetTiming() {
		romTest(defaultPath + "ppu_vbl_nmi/rom_singles/02-vbl_set_time.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testVBLClearTiming() {
		romTest(defaultPath + "ppu_vbl_nmi/rom_singles/03-vbl_clear_time.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testNMIControl() {
		romTest(defaultPath + "ppu_vbl_nmi/rom_singles/04-nmi_control.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testNMITiming() {
		romTest(defaultPath + "ppu_vbl_nmi/rom_singles/05-nmi_timing.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testVBLSupression() {
		romTest(defaultPath + "ppu_vbl_nmi/rom_singles/06-suppression.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testNMINearVBLClear() {
		romTest(defaultPath + "ppu_vbl_nmi/rom_singles/07-nmi_on_timing.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testNMINearVBLSet() {
		romTest(defaultPath + "ppu_vbl_nmi/rom_singles/08-nmi_off_timing.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testEvenOddFrameSkipping() {
		romTest(defaultPath + "ppu_vbl_nmi/rom_singles/09-even_odd_frames.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testEvenOddFrameTiming() {
		romTest(defaultPath + "ppu_vbl_nmi/rom_singles/10-even_odd_timing.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	// MARK: - APU Testing
	
	// blargg's Basic APU Tests
	
	func testLengthCounters() {
		romTest(defaultPath + "apu_test/rom_singles/1-len_ctr.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testLengthTableEntries() {
		romTest(defaultPath + "apu_test/rom_singles/2-len_table.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testAPUIRQFlag() {
		romTest(defaultPath + "apu_test/rom_singles/3-irq_flag.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testAPUClockJitter() {
		romTest(defaultPath + "apu_test/rom_singles/4-jitter.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testLengthCounterTiming() {
		romTest(defaultPath + "apu_test/rom_singles/5-len_timing.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testIRQFlagTiming() {
		romTest(defaultPath + "apu_test/rom_singles/6-irq_flag_timing.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testDMCBasics() {
		romTest(defaultPath + "apu_test/rom_singles/7-dmc_basics.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
	
	func testDMCRates() {
		romTest(defaultPath + "apu_test/rom_singles/8-dmc_rates.nes", testAddress: 0x6000, desiredResult: 0x00, intermediary: 0x80, maxInstructions: 5000000);
	}
}
