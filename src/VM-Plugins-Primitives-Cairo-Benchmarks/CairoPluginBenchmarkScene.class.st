"
I am one workload of `CairoPluginBenchmark`, at one surface size: what to do before each run (untimed: reset the cached Roassal paths, invalidate a Roassal canvas), the run itself (the part that is timed; it answers a surface, a Form or the name of an SVG file), and how to get the bytes whose fingerprint the modes must share from what the run answered.
"
Class {
	#name : 'CairoPluginBenchmarkScene',
	#superclass : 'Object',
	#instVars : [
		'name',
		'size',
		'beforeBlock',
		'runBlock',
		'bytesBlock'
	],
	#category : 'VM-Plugins-Primitives-Cairo-Benchmarks',
	#package : 'VM-Plugins-Primitives-Cairo-Benchmarks'
}

{ #category : 'instance creation' }
CairoPluginBenchmarkScene class >> name: aString size: anInteger run: aBlock [
	"A scene whose run answers an AthensCairoSurface (the bytes are its pixels)"

	^ self new
		  setName: aString size: anInteger;
		  runBlock: aBlock;
		  bytesBlock: [ :surface | CairoPluginTestSupport bytesOf: surface ];
		  yourself
]

{ #category : 'running' }
CairoPluginBenchmarkScene >> before [
	"The untimed preparation of a run"

	beforeBlock ifNotNil: [ beforeBlock value ]
]

{ #category : 'accessing' }
CairoPluginBenchmarkScene >> beforeBlock: aBlock [

	beforeBlock := aBlock
]

{ #category : 'running' }
CairoPluginBenchmarkScene >> bytesOf: aResult [
	"The bytes of what a run answered, whose fingerprint every mode must have"

	^ bytesBlock value: aResult
]

{ #category : 'accessing' }
CairoPluginBenchmarkScene >> bytesBlock: aBlock [

	bytesBlock := aBlock
]

{ #category : 'accessing' }
CairoPluginBenchmarkScene >> name [

	^ name
]

{ #category : 'running' }
CairoPluginBenchmarkScene >> run [
	"The timed part: answers what bytesOf: takes"

	^ runBlock value
]

{ #category : 'accessing' }
CairoPluginBenchmarkScene >> runBlock: aBlock [

	runBlock := aBlock
]

{ #category : 'initialization' }
CairoPluginBenchmarkScene >> setName: aString size: anInteger [

	name := aString.
	size := anInteger
]

{ #category : 'accessing' }
CairoPluginBenchmarkScene >> surfaceSize [
	"The size reported (the side of the surface; 800 for the frame of 800 x 600)"

	^ size
]

{ #category : 'running' }
CairoPluginBenchmarkScene >> warm [
	"An untimed run, after a mode switch (uFFI generates the callouts of the restored stubs on their first call)"

	self before.
	^ self run
]
