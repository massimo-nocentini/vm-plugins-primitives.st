"
I run the tests of the CairoPlugin (the concrete subclasses of `CairoPluginTestCase`) and report each one with its outcome, and the reason of each skip, which the JUnit files of Pharo's test command leave out (a skipped test is a pass there): plugin/tests/run-st-tests.sh and the WebAssembly lane of pharo-vm fail when the plugin was expected and a test skipped itself.

	CairoPluginTestRunner runOn: Stdio stdout junit: 'cairo-tests.xml'

prints a line a test, 'PASS', 'SKIP', 'FAIL', 'ERROR' or 'N/A' (a test of a VM without the plugin, on a VM with it: not a skip), the test, its time and the reason or the error, then the summary

	CairoPluginTests: <run> run, <passed> passed, <failures> failures, <errors> errors, <skipped> skipped, <n> not applicable; plugin <CairoPlugin info>; installed <groups>; scenes scale <s> size <n>

and writes a JUnit file (with the skips as skipped elements) when given a path. `runClasses:on:junit:` runs some of the classes only. The answer is { run. passed. failures. errors. skipped. not applicable }.
"
Class {
	#name : 'CairoPluginTestRunner',
	#superclass : 'Object',
	#category : 'VM-Plugins-Primitives-Cairo-Tests',
	#package : 'VM-Plugins-Primitives-Cairo-Tests'
}

{ #category : 'private' }
CairoPluginTestRunner class >> messageOf: aTest [
	"Run aTest again to get the description of its failure or error"

	^ [
	  aTest setUp.
	  [ aTest performTest ] ensure: [ aTest tearDown ].
	  'passed when run again' ]
		  on: Error , TestFailure
		  do: [ :e | e return: e class name , ': ' , e messageText asString ]
]

{ #category : 'private' }
CairoPluginTestRunner class >> printable: aString [
	"aString in ASCII: a character outside it as \u{hex} (a message may hold a surrogate, which no UTF-8 stream writes)"

	^ String streamContents: [ :out |
		  aString asString do: [ :c |
			  (c asInteger between: 32 and: 126)
				  ifTrue: [ out nextPut: c ]
				  ifFalse: [
					  c asInteger = 10 | (c asInteger = 13)
						  ifTrue: [ out nextPut: $  ]
						  ifFalse: [
							  out
								  nextPutAll: '\u{';
								  nextPutAll: (c asInteger printStringBase: 16);
								  nextPut: $} ] ] ] ]
]

{ #category : 'running' }
CairoPluginTestRunner class >> runClasses: classes on: aStream junit: aPathOrNil [
	"Run the tests of classes; report them on aStream and, when aPathOrNil is a path, in a JUnit file; answer { run. passed. failures. errors. skipped. not applicable }"

	| outcomes counts scenes |
	CairoPluginTestCase resetSkipReasons.
	outcomes := OrderedCollection new.
	(classes asSortedCollection: [ :a :b | a name <= b name ]) do: [ :cls |
		(cls buildSuite tests asSortedCollection: [ :a :b | a selector <= b selector ]) do: [ :test |
			| result t0 ms status message |
			t0 := Time millisecondClockValue.
			result := test run.
			ms := Time millisecondClockValue - t0.
			status := result errors notEmpty
				          ifTrue: [ #error ]
				          ifFalse: [
					          result failures notEmpty
						          ifTrue: [ #failure ]
						          ifFalse: [
							          result skipped notEmpty
								          ifTrue: [ #skipped ]
								          ifFalse: [ #passed ] ] ].
			message := status = #skipped
				           ifTrue: [ CairoPluginTestCase skipReasonOf: test ]
				           ifFalse: [
					           (#( #error #failure ) includes: status)
						           ifTrue: [ (CairoPluginTestCase failureDescriptionOf: test) ifNil: [ self messageOf: test ] ]
						           ifFalse: [ '' ] ].
			(status = #skipped and: [ message beginsWith: CairoPluginTestCase notApplicablePrefix ]) ifTrue: [
				status := #notApplicable.
				message := message allButFirst: CairoPluginTestCase notApplicablePrefix size ].
			message := self printable: message.
			outcomes add: {
					cls name.
					test selector.
					status.
					message.
					ms }.
			aStream
				nextPutAll: (#( 'PASS ' 'SKIP ' 'FAIL ' 'ERROR' 'N/A  ' ) at: (#( #passed #skipped #failure #error #notApplicable ) indexOf: status));
				nextPutAll: ' ';
				nextPutAll: cls name;
				nextPutAll: '>>';
				nextPutAll: test selector;
				nextPutAll: ' (';
				nextPutAll: ms printString;
				nextPutAll: ' ms)'.
			message isEmpty ifFalse: [
				aStream
					nextPutAll: ': ';
					nextPutAll: message ].
			aStream lf; flush ] ].
	counts := #( #passed #failure #error #skipped #notApplicable ) collect: [ :s | (outcomes select: [ :o | (o at: 3) = s ]) size ].
	scenes := CairoPluginTestCase scenes.
	aStream
		nextPutAll: 'CairoPluginTests: ';
		nextPutAll: outcomes size printString;
		nextPutAll: ' run, ';
		nextPutAll: (counts at: 1) printString;
		nextPutAll: ' passed, ';
		nextPutAll: (counts at: 2) printString;
		nextPutAll: ' failures, ';
		nextPutAll: (counts at: 3) printString;
		nextPutAll: ' errors, ';
		nextPutAll: (counts at: 4) printString;
		nextPutAll: ' skipped, ';
		nextPutAll: (counts at: 5) printString;
		nextPutAll: ' not applicable; plugin ';
		nextPutAll: CairoPlugin info printString;
		nextPutAll: '; installed ';
		nextPutAll: CairoPlugin installedGroups printString;
		nextPutAll: '; scenes scale ';
		nextPutAll: scenes scale printString;
		nextPutAll: ' size ';
		nextPutAll: scenes size printString;
		lf;
		flush.
	aPathOrNil ifNotNil: [ self writeJUnit: outcomes to: aPathOrNil ].
	^ { outcomes size } , counts
]

{ #category : 'running' }
CairoPluginTestRunner class >> runOn: aStream junit: aPathOrNil [
	"Run every test of the CairoPlugin (see the class comment)"

	^ self runClasses: self testClasses on: aStream junit: aPathOrNil
]

{ #category : 'accessing' }
CairoPluginTestRunner class >> testClasses [

	^ CairoPluginTestCase allSubclasses reject: [ :each | each isAbstract ]
]

{ #category : 'private' }
CairoPluginTestRunner class >> writeJUnit: outcomes to: aPath [

	| escape file |
	escape := [ :s |
	          ((((self printable: s) copyReplaceAll: '&' with: '&amp;') copyReplaceAll: '<' with: '&lt;')
		          copyReplaceAll: '>' with: '&gt;') copyReplaceAll: '"' with: '&quot;' ].
	file := aPath asFileReference.
	file ensureDelete.
	file writeStreamDo: [ :out |
		out
			nextPutAll: '<?xml version="1.0" encoding="UTF-8"?>';
			lf;
			nextPutAll: '<testsuite name="VM-Plugins-Primitives-Cairo-Tests" tests="';
			print: outcomes size;
			nextPutAll: '" failures="';
			print: (outcomes select: [ :o | (o at: 3) = #failure ]) size;
			nextPutAll: '" errors="';
			print: (outcomes select: [ :o | (o at: 3) = #error ]) size;
			nextPutAll: '" skipped="';
			print: (outcomes select: [ :o | (o at: 3) = #skipped ]) size;
			nextPutAll: '">';
			lf.
		outcomes do: [ :o |
			out
				nextPutAll: '  <testcase classname="';
				nextPutAll: (o at: 1);
				nextPutAll: '" name="';
				nextPutAll: (o at: 2);
				nextPutAll: '" time="';
				nextPutAll: ((o at: 5) / 1000.0) printString;
				nextPutAll: '"'.
			((o at: 3) = #passed or: [ (o at: 3) = #notApplicable ])
				ifTrue: [ out nextPutAll: '/>' ]
				ifFalse: [
					out
						nextPutAll: '><';
						nextPutAll: ((o at: 3) = #skipped ifTrue: [ 'skipped' ] ifFalse: [ o at: 3 ]);
						nextPutAll: ' message="';
						nextPutAll: (escape value: (o at: 4));
						nextPutAll: '"/></testcase>' ].
			out lf ].
		out
			nextPutAll: '</testsuite>';
			lf ]
]
