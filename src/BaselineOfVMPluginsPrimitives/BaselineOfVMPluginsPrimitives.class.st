"
I load the Smalltalk side of the UtilsPlugin of the Pharo VM (pharo-vm, plugins/UtilsPlugin, docs/UtilsPlugin.md):

- `VM-Plugins-Primitives` (group `Core`): the fused multiply-add of Floats (`Float>>#times:plus:`), the splitting of strings (`String>>#strtok:inclusive:`, `String>>#linesIncludeEmptySubstrings:`), the points of Bezier curves by the de Casteljau scheme (`SequenceableCollection>>#bezierPointsAt:`), and Knuth's lagged Fibonacci generator (`KnuthRandom`). Each answers through the plugin when the VM has it, and through its Smalltalk twin (`UtilsPluginSmalltalk`) otherwise, with the same result, bit for bit;
- `VM-Plugins-Primitives-Tests` (group `Tests`): their tests, on both ways;
- `VM-Plugins-Primitives-Cairo` (group `Cairo`, opt-in, not in `default`): the image side of the CairoPlugin (pharo-vm, plugins/CairoPlugin, docs/CairoPlugin.md), Athens drawing through cairo without the FFI's callout: `CairoPlugin install` patches the hot Athens-Cairo methods at run time (reversibly, `CairoPlugin uninstall`), each falling back to its original FFI callout when the primitive fails or the VM has no plugin;
- `VM-Plugins-Primitives-Cairo-Tests` (group `CairoTests`) and `VM-Plugins-Primitives-Cairo-Benchmarks` (group `CairoBenchmarks`): its tests and benchmarks.

```
Metacello new
	baseline: 'VMPluginsPrimitives';
	repository: 'github://massimo-nocentini/vm-plugins-primitives.st:master/src';
	load
```

and, for the Cairo packages, `load: #( 'Cairo' )` (or `#( 'Cairo' 'CairoTests' )`).
"
Class {
	#name : 'BaselineOfVMPluginsPrimitives',
	#superclass : 'BaselineOf',
	#category : 'BaselineOfVMPluginsPrimitives',
	#package : 'BaselineOfVMPluginsPrimitives'
}

{ #category : 'baselines' }
BaselineOfVMPluginsPrimitives >> baseline: spec [

	<baseline>
	spec for: #common do: [
		spec
			package: 'VM-Plugins-Primitives';
			package: 'VM-Plugins-Primitives-Tests'
			with: [ spec requires: #( 'VM-Plugins-Primitives' ) ].
		spec
			package: 'VM-Plugins-Primitives-Cairo'
			with: [ spec postLoadDoIt: #cairoPluginPostLoad ];
			package: 'VM-Plugins-Primitives-Cairo-Tests'
			with: [ spec requires: #( 'VM-Plugins-Primitives-Cairo' ) ];
			package: 'VM-Plugins-Primitives-Cairo-Benchmarks'
			with: [ spec requires: #( 'VM-Plugins-Primitives-Cairo-Tests' ) ].
		spec
			group: 'Core' with: #( 'VM-Plugins-Primitives' );
			group: 'Tests' with: #( 'VM-Plugins-Primitives-Tests' );
			group: 'Cairo' with: #( 'VM-Plugins-Primitives-Cairo' );
			group: 'CairoTests' with: #( 'VM-Plugins-Primitives-Cairo-Tests' );
			group: 'CairoBenchmarks' with: #( 'VM-Plugins-Primitives-Cairo-Benchmarks' );
			group: 'default' with: #( 'Core' 'Tests' ) ]
]

{ #category : 'doits' }
BaselineOfVMPluginsPrimitives >> cairoPluginPostLoad [
	"After a load of VM-Plugins-Primitives-Cairo: a newer version loaded over an image with the patches of an older one replaces them (CairoPlugin class>>refreshAfterLoad; its class initialize runs again only when its own source changes)"

	(Smalltalk globals at: #CairoPlugin ifAbsent: [ nil ]) ifNotNil: [ :c |
		c refreshAfterLoad ]
]
