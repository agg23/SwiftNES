//
//  AppDelegate.swift
//  SwiftNES
//
//  Created by Adam Gastineau on 3/23/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Cocoa
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

func outputCallback(_ data: UnsafeMutableRawPointer?, inAudioQueue: AudioQueueRef, inBuffer: AudioQueueBufferRef) {
	let apu: APU = bridge(UnsafeRawPointer(data)!)
	
	apu.buffer.loadBuffer(inBuffer)
	
	AudioQueueEnqueueBuffer(inAudioQueue, inBuffer, 0, nil)
}

@NSApplicationMain
final class AppDelegate: NSObject, NSApplicationDelegate, MTKViewDelegate {

    @IBOutlet weak var window: DisplayWindow!
	
	@IBOutlet weak var metalView: MTKView!
	
	@IBOutlet weak var playPauseEmulationButton: NSMenuItem!
	
	private var device: MTLDevice!
	private var commandQueue: MTLCommandQueue! = nil
	private var pipeline: MTLComputePipelineState! = nil
	
	var sizingRect: NSRect? = nil
	
	private var texture: MTLTexture! = nil
	private var textureOptions = [MTKTextureLoaderOptionTextureUsage: Int(MTLTextureUsage.renderTarget.rawValue) as NSNumber]
	private var textureDescriptor: MTLTextureDescriptor? = nil
	
	private let threadGroupCount = MTLSizeMake(8, 8, 1)
	private var threadGroups: MTLSize?
	
	private var textureLoader: MTKTextureLoader?
	
	private let controllerIO: MacControllerIO
	private var cpu: CPU?
	private var ppu: PPU?
	private var apu: APU?
	private let logger: Logger?
	
	private var frameCount = 0
	private var lastFrameUpdate: Double = 0
	
	private var fileLoaded: Bool
	private var paused: Bool
	
	private var scalingFactor:CGFloat = 2.0
	
	var dataFormat: AudioStreamBasicDescription
	var queue: AudioQueueRef?
	var buffer: AudioQueueBufferRef?
	var buffer2: AudioQueueBufferRef?
	var bufferByteSize: UInt32
	var numPacketsToRead: UInt32
	var packetsToPlay: Int64
	
	override init() {
		dataFormat = AudioStreamBasicDescription(mSampleRate: 0, mFormatID: 0, mFormatFlags: 0, mBytesPerPacket: 0, mFramesPerPacket: 0, mBytesPerFrame: 0, mChannelsPerFrame: 0, mBitsPerChannel: 0, mReserved: 0)
		queue = nil
		buffer = nil
		buffer2 = nil
		bufferByteSize = 0x700
		numPacketsToRead = 0
		packetsToPlay = 1
		
		fileLoaded = false
		paused = true
		
		logger = Logger(path: "/Users/adam/nes.log")
		
		controllerIO = MacControllerIO()
		
		dataFormat.mSampleRate = 44100
		dataFormat.mFormatID = kAudioFormatLinearPCM
		
		// Sort out endianness
		if (NSHostByteOrder() == NS_BigEndian) {
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
	
	func windowSetup() {
		guard let device = device else {
			// Should never occur
			print("ERROR: No device")
			return
		}

		var rect = window.frameRect(forContentRect: NSMakeRect(0, 0, 256 * scalingFactor, 240 * scalingFactor))
		
		rect.origin = window.frame.origin
		
		window.setFrame(rect, display: false)
		
		let width = 256 * scalingFactor
		let height = 240 * scalingFactor
		
		let windowSize = NSMakeSize(width, height)
		
		window.contentMinSize = windowSize
		window.contentMaxSize = windowSize
		
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: MTLPixelFormat.bgra8Unorm, width: Int(width), height: Int(height), mipmapped: false)
		textureDescriptor = descriptor
        texture = device.makeTexture(descriptor: descriptor)
		
		metalView.colorPixelFormat = MTLPixelFormat.bgra8Unorm
	}

    func applicationDidFinishLaunching(_ aNotification: Notification) {
		let rect = window.convertToBacking(NSMakeRect(0, 0, 256 * scalingFactor, 240 * scalingFactor))
		self.sizingRect = rect
		
		let width = Int(rect.width)
		let height = Int(rect.height)
		
		window.controllerIO = controllerIO
		
		// Set up Metal
		device = MTLCreateSystemDefaultDevice()

		guard let device = device else {
			// Should never occur
			print("ERROR: No device")
			return
		}
		
		metalView.device = device
		metalView.preferredFramesPerSecond = 60
		metalView.delegate = self
		
		metalView.drawableSize = metalView.frame.size
		
        commandQueue = device.makeCommandQueue()
		
		textureLoader = MTKTextureLoader(device: device)
		
		threadGroups = MTLSizeMake((width + threadGroupCount.width)/threadGroupCount.width, (height + threadGroupCount.height)/threadGroupCount.height, 1)
		
		windowSetup()
		
		metalView.draw()
    }
	
	func application(_ sender: NSApplication, openFile filename: String) -> Bool {
		return loadROM(URL(fileURLWithPath: filename))
	}
	
	// MARK: - Menu Controls
	
	@IBAction func openROM(_ sender: AnyObject) {
		let openDialog = NSOpenPanel()
		
		paused = true
		
		if(openDialog.runModal() == NSFileHandlingPanelOKButton) {
			let _ = loadROM(openDialog.url!)
		}
		
		paused = !fileLoaded
	}
	
	
	@IBAction func playPauseEmulation(_ sender: AnyObject) {
		if(!fileLoaded) {
			return
		}
		
		paused = !paused
		
		// TODO: Handle AudioQueue when paused
		if(paused) {
			playPauseEmulationButton.title = "Resume Emulation"
		} else {
			playPauseEmulationButton.title = "Pause Emulation"
		}
	}
	
	@IBAction func setRenderScale(_ sender: AnyObject) {
		var tag = sender.tag
		let scaleTag: Int

		if let unwrappedTag = tag,
			unwrappedTag > 1,
			unwrappedTag < 3 {
			scaleTag = unwrappedTag
		} else {
			scaleTag = 1
		}

		scalingFactor = CGFloat(scaleTag)
		ppu?.setRenderScale(scaleTag)

		windowSetup()
	}
	
	@IBAction func dumpPPUMemory(_ sender: AnyObject) {
		ppu?.dumpMemory()
	}
	
	
	override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
		if(menuItem == playPauseEmulationButton) {
			return fileLoaded
		}
		
		return true
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
		fileLoaded = fileIO.loadFile(url.path)
		
		if(!fileLoaded) {
			return false
		}
		
		NSDocumentController.shared().noteNewRecentDocumentURL(url)
		
		playPauseEmulationButton.isEnabled = true
		
		let apu = APU(memory: mainMemory)
		self.apu = apu
		
		let ppu = PPU(cpuMemory: mainMemory, ppuMemory: ppuMemory)
		self.ppu = ppu
		ppu.setRenderScale(Int(scalingFactor))
		
		mainMemory.ppu = ppu
		mainMemory.apu = apu
		
		let cpu = CPU(mainMemory: mainMemory, ppu: ppu, apu: apu, logger: logger)
		self.cpu = cpu
		apu.cpu = cpu
		ppu.cpu = cpu
		
		cpu.reset()
		
		initializeAudio(with: apu)

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
		let width = Int(256 * scalingFactor)
		let height = Int(240 * scalingFactor)
		
		let bytesPerPixel = 4
		let bytesPerRow = width * bytesPerPixel
		
        metalView.currentDrawable!.texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: UnsafeRawPointer(screen), bytesPerRow: bytesPerRow)
		
        let commandBuffer = commandQueue.makeCommandBuffer()
		
		commandBuffer.present(metalView.currentDrawable!)
		
		commandBuffer.commit()
	}
	
	func applicationWillTerminate(_ aNotification: Notification) {
		logger?.endLogging()
    }

	// MARK: - MTKViewDelegate
	
	func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
		
	}

	func draw(in view: MTKView) {
		frameCount += 1
		let now  = getTimestamp()
		let diff = now - lastFrameUpdate
		if diff >= 1000 {
			let fps = (Double(frameCount) / diff) * 1000
			
			window.title = String(format: "SwiftNES [%.0f]", fps)
			
			frameCount = 0
			lastFrameUpdate = now
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
}

