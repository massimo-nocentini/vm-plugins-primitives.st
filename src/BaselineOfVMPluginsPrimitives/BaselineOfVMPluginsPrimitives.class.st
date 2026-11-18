"
I load the Smalltalk side of the UtilsPlugin of the Pharo VM (pharo-vm, plugins/UtilsPlugin, docs/UtilsPlugin.md):

- `VM-Plugins-Primitives` (group `Core`): the fused multiply-add of Floats (`Float>>#times:plus:`), the splitting of strings (`String>>#strtok:inclusive:`, `String>>#linesIncludeEmptySubstrings:`), the points of Bezier curves by the de Casteljau scheme (`SequenceableCollection>>#bezierPointsAt:`), and Knuth's lagged Fibonacci generator (`KnuthRandom`). Each answers through the plugin when the VM has it, and through its Smalltalk twin (`UtilsPluginSmalltalk`) otherwise, with the same result, bit for bit;
- `VM-Plugins-Primitives-Tests` (group `Tests`): their tests, on both ways.

```
Metacello new
	baseline: 'VMPluginsPrimitives';
	repository: 'github://massimo-nocentini/vm-plugins-primitives.st:master/src';
	load
```
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
			group: 'Core' with: #( 'VM-Plugins-Primitives' );
			group: 'Tests' with: #( 'VM-Plugins-Primitives-Tests' );
			group: 'default' with: #( 'Core' 'Tests' ) ]
]
