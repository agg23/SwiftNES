//
//  ViewController.swift
//  SwiftNES-iOS
//
//  Created by Adam Gastineau on 6/19/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import UIKit
import QuartzCore
import Metal
import MetalKit
import AudioToolbox

func bridge<T : AnyObject>(_ obj : T) -> UnsafeRawPointer {
	return UnsafeRawPointer(Unmanaged.passUnretained(obj).toOpaque())
	// return unsafeAddressOf(obj) // ***
}

func bridge<T : AnyObject>(_ ptr : UnsafeRawPointer) -> T {
	return Unmanaged<T>.fromOpaque(ptr).takeUnretainedValue()
	// return unsafeBitCast(ptr, T.self) // ***
}

var count = 0

func outputCallback(_ data: UnsafeMutableRawPointer?, inAudioQueue: AudioQueueRef, inBuffer: AudioQueueBufferRef) {
	let apu: APU = bridge(UnsafeRawPointer(data)!)
	
	apu.buffer.loadBuffer(inBuffer)
	
	AudioQueueEnqueueBuffer(inAudioQueue, inBuffer, 0, nil)
}

class ViewController: UIViewController, MTKViewDelegate {

	@IBOutlet weak var metalView: MTKView!
	
	private var device: MTLDevice!
	private var commandQueue: MTLCommandQueue! = nil
	private var pipeline: MTLComputePipelineState! = nil
	
	private var texture: MTLTexture! = nil
	private var textureOptions = [MTKTextureLoaderOptionTextureUsage: Int(MTLTextureUsage.renderTarget.rawValue) as NSNumber]
	private var textureDescriptor: MTLTextureDescriptor? = nil
	
	private let threadGroupCount = MTLSizeMake(8, 8, 1)
	private var threadGroups: MTLSize?
	
	private var textureLoader: MTKTextureLoader?
	
	private let controllerIO: iOSControllerIO
	private var cpu: CPU?
	private var ppu: PPU?
	private var apu: APU?
	private let logger: Logger?
	
	private var frameCount = 0
	private var lastFrameUpdate: Double = 0
	
	private var fileLoaded: Bool
	private var paused: Bool
	
	var dataFormat: AudioStreamBasicDescription
	var queue: AudioQueueRef?
	var buffer: AudioQueueBufferRef?
	var buffer2: AudioQueueBufferRef?
	var bufferByteSize: UInt32
	var numPacketsToRead: UInt32
	var packetsToPlay: Int64
	
	required init?(coder aDecoder: NSCoder) {
		dataFormat = AudioStreamBasicDescription(mSampleRate: 0, mFormatID: 0, mFormatFlags: 0, mBytesPerPacket: 0, mFramesPerPacket: 0, mBytesPerFrame: 0, mChannelsPerFrame: 0, mBitsPerChannel: 0, mReserved: 0)
		queue = nil
		buffer = nil
		buffer2 = nil
		bufferByteSize = 0x700
		numPacketsToRead = 0
		packetsToPlay = 1
		
		logger = Logger(path: "/Users/adam/nes.log")
		
		controllerIO = iOSControllerIO()
		
		fileLoaded = false
		paused = true
		
		super.init(coder: aDecoder)
		
		dataFormat.mSampleRate = 44100
		dataFormat.mFormatID = kAudioFormatLinearPCM
		
		// Sort out endianness
		if NSHostByteOrder() == NS_BigEndian {
			dataFormat.mFormatFlags = kLinearPCMFormatFlagIsBigEndian | kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked
		} else {
			dataFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked
		}
		
		dataFormat.mFramesPerPacket = 1
		dataFormat.mBytesPerFrame = 2
		dataFormat.mBytesPerPacket = dataFormat.mBytesPerFrame * dataFormat.mFramesPerPacket
		dataFormat.mChannelsPerFrame = 1
		dataFormat.mBitsPerChannel = 16
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view, typically from a nib.
		let device = MTLCreateSystemDefaultDevice()
		self.device = device
		
		metalView.device = device
		metalView.preferredFramesPerSecond = 60
		metalView.delegate = self
		metalView.framebufferOnly = false
		
		metalView.drawableSize = metalView.frame.size
		
		self.commandQueue = device.newCommandQueue()
		
		self.textureLoader = MTKTextureLoader(device: device)
		
//		self.threadGroups = MTLSizeMake((width+threadGroupCount.width)/threadGroupCount.width, (height+threadGroupCount.height)/threadGroupCount.height, 1)
//		
//		let library:MTLLibrary!  = self.device.newDefaultLibrary()
//		let function:MTLFunction! = library.newFunction(withName: "kernel_passthrough")
//		self.pipeline = try! self.device!.newComputePipelineState(with: function)
		
//		windowSetup()
		
		metalView.draw()
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
	
	func loadROM(_ url: URL) -> Bool {
		guard let logger = logger else {
			print("ERROR: Set up logger before attempting to load ROM")
			return false
		}

		let mapper = Mapper()
		
		let mainMemory = CPUMemory(mapper: mapper)
		mainMemory.controllerIO = controllerIO
		
		let ppuMemory = PPUMemory(mapper: mapper)
		let fileIO = FileIO(mainMemory: mainMemory, ppuMemory: ppuMemory)
		fileIO.loadFile(url.path)
		
//		NSDocumentController.shared().noteNewRecentDocumentURL(url)
		
//		self.playPauseEmulationButton.isEnabled = true
		
		let apu = APU(memory: mainMemory)
		self.apu = apu
		
		let ppu = PPU(cpuMemory: mainMemory, ppuMemory: ppuMemory)
		ppu.setRenderScale(1)
		self.ppu = ppu
		
		mainMemory.ppu = ppu
		mainMemory.apu = apu
		
		cpu = CPU(mainMemory: mainMemory, ppu: ppu, apu: apu, logger: logger)
		apu.cpu = cpu
		ppu.cpu = cpu
		
		cpu.reset()
		
		initializeAudio()

		guard let queue = queue else {
			return false
		}
		
		AudioQueueStart(queue, nil)
		
		paused = false
		
		return true
	}
	
	// MARK: - Audio
	
	func initializeAudio(with apu: APU) {
		if let queue = queue {
			if let buffer = buffer {
				AudioQueueFreeBuffer(queue, buffer)
			}

			if let buffer = buffer2 {
				AudioQueueFreeBuffer(queue, buffer)
			}

			AudioQueueDispose(queue, true)
		}

		AudioQueueNewOutput(&dataFormat, outputCallback, UnsafeMutableRawPointer(mutating: bridge(apu)), CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue, 0, &queue)

		guard let queue = queue else {
			print("ERROR: Failed to initialize queue")
			return
		}

		AudioQueueAllocateBuffer(queue, bufferByteSize, &buffer)
		AudioQueueAllocateBuffer(queue, bufferByteSize, &buffer2)

		guard let buffer = buffer,
			let buffer2 = buffer2 else {
				print("ERROR: Failed to initialize buffers")
				return
		}

		outputCallback(UnsafeMutableRawPointer(mutating: bridge(apu)), inAudioQueue: queue, inBuffer: buffer)
		outputCallback(UnsafeMutableRawPointer(mutating: bridge(apu)), inAudioQueue: queue, inBuffer: buffer2)
	}

	// MARK: - Graphics
	
	func render(_ screen: inout [UInt32]) {
		let width = Int(256 * 1)
		let height = Int(240 * 1)
		
		let bytesPerPixel = 4
		let bytesPerRow = width * bytesPerPixel
		
//		let drawable = self.metalView.currentDrawable!.texture
		metalView.currentDrawable!.texture.replace(MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: UnsafeRawPointer(screen), bytesPerRow: bytesPerRow)
		
		let commandBuffer = commandQueue.commandBuffer()
		
		commandBuffer.present(metalView.currentDrawable!)
		
		commandBuffer.commit()
	}

	func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
		
	}
	
	func draw(in view: MTKView) {
		self.frameCount += 1
		let now  = getTimestamp()
		let diff = now - lastFrameUpdate
		if diff >= 1000 {
			let fps = (Double(frameCount) / diff) * 1000
			
//			self.window.title = String(format: "SwiftNES [%.0f]", fps)
			
			self.frameCount = 0
			self.lastFrameUpdate = now
		}
		
		if(!paused) {
			while cpu?.step() == true {
				guard let ppu = ppu else {
					break
				}

				if ppu.frameReady == true {
					ppu.frameReady = false

					render(&ppu.frame)
					return
				}
			}
		}
	}
	
	func getTimestamp() -> Double {
		var tv:timeval = timeval()
		gettimeofday(&tv, nil)
		return (Double(tv.tv_sec)*1e3 + Double(tv.tv_usec)*1e-3)
	}
	
	@IBAction func run(_ sender: AnyObject) {
		print(loadROM(Bundle.main.url(forResource: "smb3", withExtension: "nes")!))
	}
	
	@IBAction func touchDown(_ sender: AnyObject) {
		controllerIO.buttonPressEvent(sender.tag!)
	}
	
	@IBAction func touchUp(_ sender: AnyObject) {
		controllerIO.buttonUpEvent(sender.tag!)
	}
	
}

