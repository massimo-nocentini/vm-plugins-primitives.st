"
I am signalled by `CairoPlugin bind`, `CairoPlugin install:` and the bind primitive when the CairoPlugin cannot be used: `code` is the failure Symbol of the primitive (`#'not found'`, `#'inappropriate operation'`, `#'bad index'`, `#'bad argument'`, `#'unsupported operation'`, ...) or one of the facade's own:

- `#'no plugin'` (the VM has no CairoPlugin),
- `#unbound` (installing needs a bound plugin),
- `#layout` (the image's Athens classes do not have the slots the plugin reads),
- `#runner` (`CairoLibrary` does not run its callouts on the VM thread),
- `#install` (installing a group failed and was undone).
"
Class {
	#name : 'CairoPluginError',
	#superclass : 'Error',
	#instVars : [
		'code'
	],
	#category : 'VM-Plugins-Primitives-Cairo',
	#package : 'VM-Plugins-Primitives-Cairo'
}

{ #category : 'signalling' }
CairoPluginError class >> signal: aString code: aSymbol [
	"Signal a new instance of me with the message aString and the failure code aSymbol"

	^ self new
		  code: aSymbol;
		  signal: aString
]

{ #category : 'accessing' }
CairoPluginError >> code [
	"The failure Symbol (see my class comment)"

	^ code
]

{ #category : 'accessing' }
CairoPluginError >> code: aSymbol [

	code := aSymbol
]
