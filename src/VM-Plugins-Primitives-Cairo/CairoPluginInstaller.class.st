"
I install and uninstall the CairoPlugin's patches of Athens-Cairo, by group (`#basic`, `#shape`, `#text`; `docs/CairoPlugin.md` of pharo-vm). `CairoPlugin` is the facade: use it, not me.

## Installing

Installing a patch of the method at `selector` of an Athens class:

1. the current method is recorded as its uFFI source stub (`propertyAt: #ffiNonCompiledMethod ifAbsent:`), never a callout uFFI generated (bound to the libcairo path of the session that generated it);
2. its copy is compiled under `ffi<Selector>` (`ffiNewPath`, `ffiDraw`, ...): the keywords of the original source are replaced at their positions;
3. the methods the patch calls are added (from the mirrors, `<cairoPluginAdded: group patch: selector>`);
4. the patch is compiled at `selector`: a method `<cairoPluginPatch: group>` whose named primitive of the CairoPlugin does the work, and which falls back to the copy when the primitive fails (no plugin, unbound, an argument the plugin does not take).

Everything runs unpreemptively with the system announcements suspended, so Athens-Cairo is not marked modified (Monticello, Iceberg) and Epicea logs nothing.

## Uninstalling

Uninstalling restores the recorded stubs at once and removes what was added; the records then go to a cache, so a reinstall in the same session compiles nothing.

An ffi copy or an added method is removed only once no process runs a patch or an added method of its record (a drawing process preempted inside a patch sends them when it resumes): until then it waits in `pending`, and every install, uninstall and verify tries again.

## What stays installed

- An installed patch is kept only while it is what this version of the package compiles (its source and its added methods' sources): an install replaces a stale one (a newer package loaded over an image with the patches of an older one; the baseline's post-load does it at once, `CairoPlugin refreshAfterLoad`), and verify reports it.
- A group whose guards stop matching after its install (a replicated method changed, a subclass override) is uninstalled by verify and by install, and stays wanted.
- An ffi copy is recognised as ours by identity, or by its source after a recompilation of its class.

## My state

Class-side instance variables, saved with the image:

- `records`: group -> the CairoPluginPatchRecords installed;
- `cache`: key -> the records of an earlier install;
- `wantedGroups`: the groups `CairoPlugin startUp:` installs at each start;
- `lastReport`: what the last install/uninstall/verify skipped or found;
- `pending`: the removals uninstalls deferred: `{ record. selector. method }`.
"
Class {
	#name : 'CairoPluginInstaller',
	#superclass : 'Object',
	#classInstVars : [
		'records',
		'cache',
		'wantedGroups',
		'lastReport',
		'pending'
	],
	#category : 'VM-Plugins-Primitives-Cairo',
	#package : 'VM-Plugins-Primitives-Cairo'
}

{ #category : 'private - compiling' }
CairoPluginInstaller class >> addedSourcesFor: spec [
	"The methods the patch of spec calls: an Array of selector -> source, from its mirror (none for a generated patch)"

	| mirror |
	mirror := spec at: 5.
	mirror ifNil: [ ^ #(  ) ].
	^ ((mirror methods select: [ :m |
		    (m hasPragmaNamed: #cairoPluginAdded:patch:) and: [
			    ((m pragmaAt: #cairoPluginAdded:patch:) arguments at: 2)
			    = (spec at: 3) ] ]) asSortedCollection: [ :a :b |
		   a selector <= b selector ]) asArray collect: [ :m |
		  m selector -> m sourceCode ]
]

{ #category : 'tables' }
CairoPluginInstaller class >> basicTable [
	"The generated patches of the group #basic: { className. isMeta. selector. primitiveName. cairo functions it calls }. The group also has the two mirror patches of #mirrorPatches"

	^ #(
	#( #AthensCairoCanvas false #newPath 'primitiveNewPath' #( 'cairo_new_path' ) )
	#( #AthensCairoCanvas false #fill 'primitiveFill' #( 'cairo_fill' ) )
	#( #AthensCairoCanvas false #fillPreserve 'primitiveFillPreserve' #( 'cairo_fill_preserve' ) )
	#( #AthensCairoCanvas false #stroke 'primitiveStroke' #( 'cairo_stroke' ) )
	#( #AthensCairoCanvas false #primPaint 'primitivePaint' #( 'cairo_paint' ) )
	#( #AthensCairoCanvas false #primSaveState 'primitiveSave' #( 'cairo_save' ) )
	#( #AthensCairoCanvas false #primRestoreState 'primitiveRestore' #( 'cairo_restore' ) )
	#( #AthensCairoCanvas false #primClip 'primitiveClip' #( 'cairo_clip' ) )
	#( #AthensCairoCanvas false #resetClip 'primitiveResetClip' #( 'cairo_reset_clip' ) )
	#( #AthensCairoCanvas false #setPathMatrix 'primitiveSetPathMatrix' #( 'cairo_set_matrix' ) )
	#( #AthensCairoCanvas false #setPathMatrix: 'primitiveSetMatrix' #( 'cairo_set_matrix' ) )
	#( #AthensCairoCanvas false #primSetSourceR:g:b:a: 'primitiveSetSourceRGBA' #( 'cairo_set_source_rgba' ) )
	#( #AthensCairoCanvas false #primSetSource: 'primitiveSetSource' #( 'cairo_set_source' ) )
	#( #AthensCairoCanvas false #primResetDashes: 'primitiveResetDash' #( 'cairo_set_dash' ) )
	#( #AthensCairoCanvas false #primSetDashesLengths:count:offset: 'primitiveSetDash' #( 'cairo_set_dash' ) )
	#( #AthensCairoCanvas false #primRectangleX:y:width:height: 'primitiveRectangle' #( 'cairo_rectangle' ) )
	#( #AthensCairoCanvas false #primSetLineWidth: 'primitiveSetLineWidth' #( 'cairo_set_line_width' ) )
	#( #AthensCairoCanvas false #primSetLineJoin: 'primitiveSetLineJoin' #( 'cairo_set_line_join' ) )
	#( #AthensCairoCanvas false #primSetLineCap: 'primitiveSetLineCap' #( 'cairo_set_line_cap' ) )
	#( #AthensCairoCanvas false #loadPath: 'primitiveAppendPath' #( 'cairo_append_path' ) )
	#( #AthensCairoCanvas false #getCurrentPoint 'primitiveGetCurrentPoint' #( 'cairo_get_current_point' ) )
	#( #AthensCairoCanvas false #setAA: 'primitiveSetAntialias' #( 'cairo_set_antialias' ) )
	#( #AthensCairoCanvas false #setFillRule: 'primitiveSetFillRule' #( 'cairo_set_fill_rule' ) )
	#( #AthensCairoCanvas false #setScaledFont: 'primitiveSetScaledFont' #( 'cairo_set_scaled_font' ) )
	#( #AthensCairoCanvas false #showGlyphs:size: 'primitiveShowGlyphs' #( 'cairo_show_glyphs' ) )
	#( #AthensCairoCanvas false #primSetFontSize: 'primitiveSetFontSize' #( 'cairo_set_font_size' ) )
	#( #AthensCairoCanvas false #textPath: 'primitiveTextPath' #( 'cairo_text_path' ) )
	#( #AthensCairoPathBuilder false #moveToX:Y: 'primitiveBuilderMoveTo' #( 'cairo_move_to' ) )
	#( #AthensCairoPathBuilder false #lineToX:Y: 'primitiveBuilderLineTo' #( 'cairo_line_to' ) )
	#( #AthensCairoPathBuilder false #primCurveViaX:Y:viaX:Y:toX:Y: 'primitiveBuilderCurveTo' #( 'cairo_curve_to' ) )
	#( #AthensCairoPathBuilder false #closePath 'primitiveBuilderClosePath' #( 'cairo_close_path' ) )
	#( #AthensCairoPathBuilder false #newPath 'primitiveBuilderNewPath' #( 'cairo_new_path' ) )
	#( #AthensCairoPathBuilder false #arcCenterX:centerY:radius:startAngle:endAngle: 'primitiveBuilderArc' #( 'cairo_arc' ) )
	#( #AthensCairoPathBuilder false #arcNegativeCenterX:centerY:radius:startAngle:endAngle: 'primitiveBuilderArcNegative' #( 'cairo_arc_negative' ) )
	#( #AthensCairoPath true #primDestroyPath: 'primitivePathDestroy' #( 'cairo_path_destroy' ) )
	#( #AthensCairoMatrix false #initx:y:sx:sy:shx:shy: 'primitiveMatrixInit' #( 'cairo_matrix_init' ) )
	#( #AthensCairoMatrix false #primLoadIdentity 'primitiveMatrixInitIdentity' #( 'cairo_matrix_init_identity' ) )
	#( #AthensCairoMatrix false #primTranslateX:Y: 'primitiveMatrixTranslate' #( 'cairo_matrix_translate' ) )
	#( #AthensCairoMatrix false #primScaleX:Y: 'primitiveMatrixScale' #( 'cairo_matrix_scale' ) )
	#( #AthensCairoMatrix false #primRotateByRadians: 'primitiveMatrixRotate' #( 'cairo_matrix_rotate' ) )
	#( #AthensCairoMatrix false #primMultiplyBy: 'primitiveMatrixMultiply' #( 'cairo_matrix_multiply' ) )
	#( #AthensCairoMatrix false #invert 'primitiveMatrixInvert' #( 'cairo_matrix_invert' ) )
	#( #AthensCairoMatrix false #primTransformX:Y: 'primitiveMatrixTransformPoint' #( 'cairo_matrix_transform_point' ) )
	#( #AthensCairoMatrix false #primSetTranslateX:Y: 'primitiveMatrixInitTranslate' #( 'cairo_matrix_init_translate' ) )
	#( #AthensCairoMatrix false #primSetScaleX:Y: 'primitiveMatrixInitScale' #( 'cairo_matrix_init_scale' ) )
	#( #AthensCairoMatrix false #primSetRotationInRadians: 'primitiveMatrixInitRotate' #( 'cairo_matrix_init_rotate' ) )
	#( #AthensCairoPaintMode false #getOperator 'primitiveGetOperator' #( 'cairo_get_operator' ) )
	#( #AthensCairoPaintMode false #setOperator: 'primitiveSetOperator' #( 'cairo_set_operator' ) )
	#( #AthensCairoSurface false #flush 'primitiveSurfaceFlush' #( 'cairo_surface_flush' ) )
	#( #CairoScaledFont false #lock 'primitiveScaledFontLockFace' #( 'cairo_ft_scaled_font_lock_face' ) )
	#( #CairoScaledFont false #unlock 'primitiveScaledFontUnlockFace' #( 'cairo_ft_scaled_font_unlock_face' ) )
	#( #CairoScaledFont false #getExtentsOfGlyphs:ofLength:into: 'primitiveScaledFontGlyphExtents' #( 'cairo_scaled_font_glyph_extents' ) )
	#( #CairoScaledFont false #getExtentsOf:into: 'primitiveScaledFontTextExtents' #( 'cairo_scaled_font_text_extents' ) )
	#( #CairoScaledFont false #getExtents: 'primitiveScaledFontExtents' #( 'cairo_scaled_font_extents' ) )
	#( #CairoFreetypeFontRenderer false #convertString:len:ofFont:toGlyphs:numGlyphs:x:y: 'primitiveTextToGlyphs' #( 'cairo_scaled_font_text_to_glyphs' ) )
	#( #CairoFreetypeFontRenderer false #freeGlyphs: 'primitiveGlyphFree' #( 'cairo_glyph_free' ) )
	#( #CairoFontMetricsProvider false #convertString:len:ofFont:toGlyphs:numGlyphs:x:y: 'primitiveTextToGlyphs' #( 'cairo_scaled_font_text_to_glyphs' ) )
	#( #CairoFontMetricsProvider false #freeGlyphs: 'primitiveGlyphFree' #( 'cairo_glyph_free' ) ) )
]

{ #category : 'state' }
CairoPluginInstaller class >> cache [

	^ cache ifNil: [ cache := Dictionary new ]
]

{ #category : 'private - checks' }
CairoPluginInstaller class >> collisionIn: specs [
	"Answer a description of the first spec whose ffi selector is already used by a method that is not our copy, or nil"

	specs do: [ :spec |
		| cls ffiSel current |
		cls := self targetClassOf: spec.
		ffiSel := self ffiSelectorFor: (spec at: 3).
		current := cls compiledMethodAt: (spec at: 3) ifAbsent: [ nil ].
		((current isNil or: [ self isPatch: current ]) not and: [
			 (cls includesSelector: ffiSel) and: [
				 (self isOurCopy: (cls compiledMethodAt: ffiSel) key: (self keyOf: spec)) not ] ])
			ifTrue: [
				^ 'collision: ' , (self nameOf: spec) , ' (' , cls name , '>>' , ffiSel
				  , ' exists and is not a copy of CairoPlugin)' ] ].
	^ nil
]

{ #category : 'tables' }
CairoPluginInstaller class >> coveredFunctions [
	"group -> the cairo functions (C names) whose calls the installed group makes through the plugin: with the group installed, none of them may be called through the FFI by the methods it patches (the benchmark's no-fallback check)"

	| d |
	d := Dictionary new.
	d
		at: #basic
		put: ((self basicTable inject: Set new into: [ :s :row |
				   s
					   addAll: (row at: 5);
					   yourself ])
				 addAll: #( 'cairo_get_scaled_font' 'cairo_copy_path' );
				 yourself) asSortedCollection asArray.
	d at: #shape put: #( 'cairo_append_path' 'cairo_fill' 'cairo_new_path' 'cairo_rectangle' 'cairo_set_dash'
		   'cairo_set_line_cap' 'cairo_set_line_join' 'cairo_set_line_width' 'cairo_set_matrix'
		   'cairo_set_source_rgba' 'cairo_stroke' ).
	d at: #text put: #( 'cairo_ft_scaled_font_lock_face' 'cairo_ft_scaled_font_unlock_face' 'cairo_get_scaled_font'
		   'cairo_glyph_free' 'cairo_scaled_font_glyph_extents' 'cairo_scaled_font_text_to_glyphs'
		   'cairo_set_font_size' 'cairo_set_matrix' 'cairo_set_scaled_font' 'cairo_set_source_rgba'
		   'cairo_show_glyphs' ).
	^ d
]

{ #category : 'private - compiling' }
CairoPluginInstaller class >> ffiSelectorFor: aSelector [
	"#newPath -> #ffiNewPath, #moveToX:Y: -> #ffiMoveToX:Y:"

	^ ('ffi' , aSelector first asUppercase asString , aSelector allButFirst) asSymbol
]

{ #category : 'private - compiling' }
CairoPluginInstaller class >> generatedSourceFor: spec original: original [
	"The source of a generated #basic patch: the original's header (its argument names), the pragmas, and the call of the ffi copy"

	| sel ffiSel args header call |
	sel := spec at: 3.
	ffiSel := self ffiSelectorFor: sel.
	args := (RBParser parseMethod: original sourceCode) arguments collect: [ :a | a name ].
	header := self message: sel arguments: args.
	call := self message: ffiSel arguments: args.
	^ String streamContents: [ :s |
		  s
			  nextPutAll: header;
			  cr;
			  tab;
			  nextPutAll: '"Installed by CairoPlugin (group #basic): ';
			  nextPutAll: (spec at: 4);
			  nextPutAll: ' of the CairoPlugin; its';
			  cr;
			  tab;
			  nextPutAll: 'original, the Athens method, is #';
			  nextPutAll: ffiSel;
			  nextPutAll: ', which runs when the primitive fails."';
			  cr;
			  tab;
			  nextPutAll: '<cairoPluginPatch: #basic>';
			  cr;
			  tab;
			  nextPutAll: '<primitive: ''';
			  nextPutAll: (spec at: 4);
			  nextPutAll: ''' module: ''CairoPlugin''>';
			  cr;
			  tab;
			  nextPutAll: '^ self ';
			  nextPutAll: call ]
]

{ #category : 'tables' }
CairoPluginInstaller class >> groups [

	^ #( #basic #shape #text )
]

{ #category : 'private - checks' }
CairoPluginInstaller class >> groupRefusal: group force: force [
	"Answer nil when group can be installed as a whole, else why not"

	| problems |
	(self mirrorsOf: group) do: [ :mirror |
		| cls |
		cls := Smalltalk globals at: (self mirrorTargetOf: mirror) ifAbsent: [ nil ].
		(cls isNil or: [ cls allInstVarNames ~= mirror instVarNames asArray ]) ifTrue: [
			^ (self mirrorTargetOf: mirror) , ' does not have the instance variables of '
			  , mirror name ] ].
	(group = #text and: [ self missingOptionalSymbols notEmpty ]) ifTrue: [
		^ 'the plugin lacks ' , (self missingOptionalSymbols inject: '' into: [ :a :b |
			    a isEmpty
				    ifTrue: [ b ]
				    ifFalse: [ a , ' ' , b ] ]) ].
	group = #basic ifTrue: [ ^ nil ].
	problems := (CairoPluginGuards mismatchesOf: group)
	            , (CairoPluginGuards subclassOverridesOf: group).
	problems isEmpty ifFalse: [
		^ problems inject: '' into: [ :a :b |
			  a isEmpty
				  ifTrue: [ b ]
				  ifFalse: [ a , '; ' , b ] ] ].
	^ nil
]

{ #category : 'private - installing' }
CairoPluginInstaller class >> healAndReport: reportDrift [
	"For every installed patch: put our patch back where uFFI overwrote it (a process inside the first call of a cold original when the patch was installed: uFFI then installs its callout with methodDict at:put:, so the current method is not ours and its #ffiNonCompiledMethod is the recorded original). Answer what was healed and, when reportDrift, the drift (a patch replaced by something else: reported, not healed) and the missing copies and added methods"

	| problems |
	problems := OrderedCollection new.
	self records keysAndValuesDo: [ :g :recs |
		recs do: [ :r |
			| cls current |
			cls := r targetClass.
			cls
				ifNil: [
					reportDrift ifTrue: [
						problems add: r methodName , ': the class is gone' ] ]
				ifNotNil: [
					current := cls compiledMethodAt: r selector ifAbsent: [ nil ].
					(self isPatch: current) ifFalse: [
						(current notNil and: [
							 (current propertyAt: #ffiNonCompiledMethod ifAbsent: [ nil ])
							 == r original ])
							ifTrue: [
								self put: r method in: cls at: r selector protocol: r originalProtocol.
								problems add:
									'healed: ' , r methodName , ' (overwritten by uFFI)' ]
							ifFalse: [
								reportDrift ifTrue: [
									problems add: r methodName , ': not patched any more' ] ] ].
					reportDrift ifTrue: [
						(cls includesSelector: r ffiSelector) ifFalse: [
							problems add: cls name , '>>' , r ffiSelector , ': missing' ].
						r added do: [ :a |
							(cls includesSelector: a selector) ifFalse: [
								problems add: cls name , '>>' , a selector , ': missing' ] ] ] ] ] ].
	^ problems
]

{ #category : 'installing' }
CairoPluginInstaller class >> install: groups force: force [
	"Install the groups (a collection of #basic #shape #text) whose checks pass; answer the requested groups that are installed afterwards. force: install even when the plugin is not bound (the patches then fall back). Signals CairoPluginError when nothing can be installed (layout, runner) or a group failed (undone)"

	| requested |
	lastReport := OrderedCollection new.
	requested := self groups select: [ :g | groups includes: g ].
	self preconditionsForce: force.
	self quietly: [
		self flushPending.
		lastReport addAll: (self healAndReport: false).
		requested do: [ :g | self installGroup: g force: force ] ].
	self wantedGroups: (self groups select: [ :g |
			 (self wantedGroups includes: g) or: [ requested includes: g ] ]).
	lastReport addAll: self verify.
	^ requested select: [ :g | self installedGroups includes: g ]
]

{ #category : 'private - installing' }
CairoPluginInstaller class >> installGroup: group force: force [

	| refusal specs collision log |
	refusal := self groupRefusal: group force: force.
	refusal ifNotNil: [
		"a group installed earlier whose checks fail now (a replicated method changed since): uninstalled, still wanted"
		(self installedGroups includes: group) ifTrue: [
			self uninstallGroup: group.
			^ lastReport add: group printString , ' uninstalled: ' , refusal ].
		^ lastReport add: group printString , ' not installed: ' , refusal ].
	"the patches an older version of the package installed: uninstalled here, installed again below"
	(self staleRecordsOf: group) do: [ :r |
		self uninstallRecord: r cache: false.
		self forgetRecord: r.
		lastReport add: 'stale patch replaced: ' , r methodName , ' (group ' , group printString , ')' ].
	specs := (self specsOf: group) select: [ :spec |
		         | why |
		         why := self specRefusal: spec.
		         why ifNotNil: [
			         lastReport add: (self nameOf: spec) , ' not patched: ' , why ].
		         why isNil ].
	collision := self collisionIn: specs.
	collision ifNotNil: [
		^ lastReport add: group printString , ' not installed: ' , collision ].
	log := OrderedCollection new.
	[ specs do: [ :spec | self installSpec: spec group: group log: log ] ]
		on: Error
		do: [ :e |
			log reverseDo: [ :undo | [ undo value ] on: Error do: [ :e2 | "keep undoing" ] ].
			^ CairoPluginError
				  signal: 'CairoPlugin: installing ' , group printString , ' failed ('
					  , e description , '); undone'
				  code: #install ]
]

{ #category : 'private - installing' }
CairoPluginInstaller class >> installSpec: spec group: group log: log [
	"Install the patch of spec (see my class comment), recording in log the blocks that undo each step"

	| cls sel current original protocol ffiSel source addedSources key cached record patch ffiCopy addedRecords |
	cls := self targetClassOf: spec.
	sel := spec at: 3.
	current := cls compiledMethodAt: sel.
	(self isPatch: current) ifTrue: [ ^ self ].
	original := current propertyAt: #ffiNonCompiledMethod ifAbsent: [ current ].
	protocol := cls protocolNameOfSelector: sel.
	ffiSel := self ffiSelectorFor: sel.
	source := self patchSourceFor: spec original: original.
	addedSources := self addedSourcesFor: spec.
	key := self keyOf: spec.
	cached := self cache at: key ifAbsent: [ nil ].
	(cached notNil and: [
		 cached original == original and: [
			 cached source = source and: [
				 cached addedSources = (addedSources collect: [ :a | a value ]) ] ] ])
		ifFalse: [ cached := nil ].
	"1. the ffi copy"
	self log: log restoring: cls selector: ffiSel.
	cached
		ifNil: [
			cls compile: (self rename: original sourceCode selector: sel to: ffiSel) classified: protocol.
			ffiCopy := cls compiledMethodAt: ffiSel ]
		ifNotNil: [
			ffiCopy := cached ffiCopy.
			self put: ffiCopy in: cls at: ffiSel protocol: protocol ].
	(cls compiledMethodAt: sel) == current ifFalse: [
		self error: 'compiling ' , ffiSel , ' changed ' , sel ].
	"2. the added methods"
	addedRecords := addedSources withIndexCollect: [ :a :i |
		                | m |
		                self log: log restoring: cls selector: a key.
		                cached
			                ifNil: [
				                cls
					                compile: a value
					                classified: protocol
					                withStamp: nil
					                notifying: nil
					                logSource: false.
				                m := cls compiledMethodAt: a key ]
			                ifNotNil: [
				                m := (cached added at: i) method.
				                self put: m in: cls at: a key protocol: protocol ].
		                (m hasPragmaNamed: #cairoPluginAdded:patch:) ifFalse: [
			                self error: a key , ' is not a CairoPlugin method' ].
		                CairoPluginPatchRecord new
			                targetClassName: (spec at: 1);
			                isMeta: (spec at: 2);
			                selector: a key;
			                group: group;
			                kind: #added;
			                method: m;
			                source: a value;
			                originalProtocol: protocol;
			                yourself ].
	"3. the patch"
	log add: [ self put: current in: cls at: sel protocol: protocol ].
	cached
		ifNil: [
			cls
				compile: source
				classified: protocol
				withStamp: nil
				notifying: nil
				logSource: false.
			patch := cls compiledMethodAt: sel ]
		ifNotNil: [
			patch := cached method.
			self put: patch in: cls at: sel protocol: protocol ].
	(self isPatch: patch) ifFalse: [
		self error: sel , ' is not a CairoPlugin patch' ].
	record := CairoPluginPatchRecord new
		          targetClassName: (spec at: 1);
		          isMeta: (spec at: 2);
		          selector: sel;
		          group: group;
		          kind: #patch;
		          original: original;
		          originalProtocol: protocol;
		          ffiSelector: ffiSel;
		          ffiCopy: ffiCopy;
		          method: patch;
		          source: source;
		          added: addedRecords asArray;
		          yourself.
	self recordsOf: group put: record log: log.
	self cache removeKey: key ifAbsent: [  ]
]

{ #category : 'state' }
CairoPluginInstaller class >> installedGroups [
	"The groups with installed patches, in the order of #groups"

	^ self groups select: [ :g |
		  (self records at: g ifAbsent: [ #(  ) ]) notEmpty ]
]

{ #category : 'private - checks' }
CairoPluginInstaller class >> isOurCopy: aMethod key: key [
	"Whether aMethod (at an ffi selector) is the ffi copy we compiled for the patch of key, uFFI's callout generated from it, or its recompilation (see isCopy:of:)"

	self records do: [ :recs |
		recs do: [ :r |
			(r key = key and: [ self isCopy: aMethod of: r ]) ifTrue: [ ^ true ] ] ].
	(self cache at: key ifAbsent: [ nil ]) ifNotNil: [ :r |
		(self isCopy: aMethod of: r) ifTrue: [ ^ true ] ].
	self pending do: [ :item |
		((item at: 1) key = key and: [ (self stubOf: aMethod) == (item at: 3) ]) ifTrue: [ ^ true ] ].
	^ false
]

{ #category : 'private - checks' }
CairoPluginInstaller class >> isCopy: aMethod of: r [
	"Whether aMethod is the ffi copy of the record r: the copy itself, uFFI's callout generated from it, or, after a recompilation of its class (recompileAll, a class variable added, a compiler option: new CompiledMethods from the same sources), a method of the copy's source"

	| stub |
	(aMethod isNil or: [ r ffiCopy isNil ]) ifTrue: [ ^ false ].
	stub := self stubOf: aMethod.
	stub == r ffiCopy ifTrue: [ ^ true ].
	^ [ stub selector = r ffiSelector and: [ stub sourceCode = r ffiCopy sourceCode ] ]
		  on: Error
		  do: [ :e | false ]
]

{ #category : 'private - checks' }
CairoPluginInstaller class >> stubOf: aMethod [
	"aMethod, or the uFFI source stub it was generated from"

	^ aMethod propertyAt: #ffiNonCompiledMethod ifAbsent: [ aMethod ]
]

{ #category : 'private - checks' }
CairoPluginInstaller class >> isCurrent: r [
	"Whether the installed record r is what this version of the package compiles: its spec is still in the tables, and its patch's source and its added methods' sources are those computed now"

	| spec |
	spec := (self specsOf: r group) detect: [ :each | (self keyOf: each) = r key ] ifNone: [ ^ false ].
	^ [
	  (self patchSourceFor: spec original: r original) = r source and: [
		  ((self addedSourcesFor: spec) collect: [ :a | a value ]) asArray = r addedSources asArray ] ]
		  on: Error
		  do: [ :e | false ]
]

{ #category : 'private - checks' }
CairoPluginInstaller class >> staleRecordsOf: group [
	"The installed records of group that are not what this version of the package compiles (isCurrent:)"

	^ (self records at: group ifAbsent: [ #(  ) ]) reject: [ :r | self isCurrent: r ]
]

{ #category : 'testing' }
CairoPluginInstaller class >> hasStalePatches [
	"Whether an installed patch is not what this version of the package compiles"

	^ self installedGroups anySatisfy: [ :g | (self staleRecordsOf: g) notEmpty ]
]

{ #category : 'testing' }
CairoPluginInstaller class >> isPatch: aMethod [
	"Whether aMethod is one of our patches"

	^ aMethod notNil and: [ aMethod hasPragmaNamed: #cairoPluginPatch: ]
]

{ #category : 'private - compiling' }
CairoPluginInstaller class >> keyOf: spec [

	^ { (spec at: 1). (spec at: 2). (spec at: 3) }
]

{ #category : 'state' }
CairoPluginInstaller class >> lastReport [
	"What the last install:, uninstall: or verify skipped, refused, healed or found (an Array of Strings)"

	^ (lastReport ifNil: [ #(  ) ]) asArray
]

{ #category : 'private - installing' }
CairoPluginInstaller class >> log: log restoring: cls selector: sel [
	"Add to log the block that puts back what is now at sel in cls (or removes sel when it is absent)"

	| previous protocol |
	previous := cls compiledMethodAt: sel ifAbsent: [ nil ].
	previous
		ifNil: [
			log add: [
				(cls includesSelector: sel) ifTrue: [ cls removeSelector: sel ] ] ]
		ifNotNil: [
			protocol := cls protocolNameOfSelector: sel.
			log add: [ self put: previous in: cls at: sel protocol: protocol ] ]
]

{ #category : 'private - compiling' }
CairoPluginInstaller class >> message: aSelector arguments: names [
	"'moveToX: x Y: y' from #moveToX:Y: and #(x y); 'newPath' from #newPath and #()"

	| keywords |
	names isEmpty ifTrue: [ ^ aSelector asString ].
	keywords := aSelector keywords.
	^ String streamContents: [ :s |
		  keywords withIndexDo: [ :k :i |
			  i > 1 ifTrue: [ s space ].
			  s
				  nextPutAll: k;
				  space;
				  nextPutAll: (names at: i) ] ]
]

{ #category : 'tables' }
CairoPluginInstaller class >> mirrorPatches [
	"The patches compiled from the mirrors: { className. isMeta. selector. nil. mirror class }, per group"

	^ {
		  (#basic -> {
			   { #AthensCairoCanvas. false. #getScaledFont. nil. CairoPluginMirrorAthensCairoCanvas }.
			   { #AthensCairoPathBuilder. false. #copyPath. nil. CairoPluginMirrorAthensCairoPathBuilder } }).
		  (#shape -> { { #AthensCairoCanvas. false. #draw. nil. CairoPluginMirrorAthensCairoCanvas } }).
		  (#text -> { { #CairoFreetypeFontRenderer. false. #renderCharacters:from:to:. nil.
			    CairoPluginMirrorCairoFreetypeFontRenderer } }) }
]

{ #category : 'private - checks' }
CairoPluginInstaller class >> mirrorTargetOf: aMirrorClass [
	"CairoPluginMirrorAthensCairoCanvas -> #AthensCairoCanvas"

	^ (aMirrorClass name allButFirst: 'CairoPluginMirror' size) asSymbol
]

{ #category : 'private - checks' }
CairoPluginInstaller class >> mirrorsOf: group [

	^ ((self specsOf: group) collect: [ :spec | spec at: 5 ] thenSelect: [ :m |
		   m notNil ]) asSet asArray
]

{ #category : 'private - checks' }
CairoPluginInstaller class >> missingOptionalSymbols [
	"The optional cairo functions the bound plugin lacks (element 7 of its info), empty without the plugin"

	^ CairoPlugin info
		  ifNil: [ #(  ) ]
		  ifNotNil: [ :info |
			  info size >= 7
				  ifTrue: [ (info at: 7) ifNil: [ #(  ) ] ]
				  ifFalse: [ #(  ) ] ]
]

{ #category : 'private - compiling' }
CairoPluginInstaller class >> nameOf: spec [

	^ (spec at: 1) , ((spec at: 2)
		   ifTrue: [ ' class>>' ]
		   ifFalse: [ '>>' ]) , (spec at: 3)
]

{ #category : 'state' }
CairoPluginInstaller class >> originalAt: key [
	"The recorded original (uFFI stub) of the installed patch of key ({ className. isMeta. selector }), or nil"

	self records do: [ :recs |
		recs do: [ :r | r key = key ifTrue: [ ^ r original ] ] ].
	^ nil
]

{ #category : 'private - compiling' }
CairoPluginInstaller class >> patchSourceFor: spec original: original [

	^ (spec at: 5)
		  ifNil: [ self generatedSourceFor: spec original: original ]
		  ifNotNil: [ :mirror | (mirror >> (spec at: 3)) sourceCode ]
]

{ #category : 'private - installing' }
CairoPluginInstaller class >> preconditionsForce: force [
	"Signal CairoPluginError unless the patches can be installed at all"

	| layoutProblem |
	(Smalltalk globals includesKey: #AthensCairoCanvas) ifFalse: [
		CairoPluginError signal: 'CairoPlugin: the image has no Athens-Cairo' code: #layout ].
	layoutProblem := CairoPluginLayout problem.
	layoutProblem ifNotNil: [
		CairoPluginError
			signal: 'CairoPlugin: the Athens classes do not fit the plugin: ' , layoutProblem
			code: #layout ].
	self runnerIsSameThread ifFalse: [
		CairoPluginError
			signal: 'CairoPlugin: CairoLibrary does not run its callouts with TFSameThreadRunner'
			code: #runner ].
	(force or: [ CairoPlugin isBound ]) ifFalse: [
		CairoPluginError signal: 'CairoPlugin: the plugin is not bound' code: #unbound ]
]

{ #category : 'private - installing' }
CairoPluginInstaller class >> put: aMethod in: cls at: sel protocol: protocol [
	"Install aMethod (already compiled) at sel of cls, in protocol, without compiling or logging. Pharo 14+ deprecates addSelector:withMethod: for its method installer, which it calls the same way"

	(cls respondsTo: #methodInstaller)
		ifTrue: [
			cls methodInstaller
				logged: false;
				install: aMethod into: cls compiler: nil ]
		ifFalse: [ cls addSelector: sel withMethod: aMethod ].
	(protocol notNil and: [ (cls protocolNameOfSelector: sel) ~= protocol ])
		ifTrue: [ cls classify: sel under: protocol ]
]

{ #category : 'private - installing' }
CairoPluginInstaller class >> quietly: aBlock [
	"Run aBlock unpreemptively with the system announcements suspended: Monticello, Iceberg and Epicea see nothing"

	^ [ SystemAnnouncer uniqueInstance suspendAllWhile: aBlock ]
		  valueUnpreemptively
]

{ #category : 'state' }
CairoPluginInstaller class >> records [

	^ records ifNil: [ records := Dictionary new ]
]

{ #category : 'private - installing' }
CairoPluginInstaller class >> recordsOf: group put: aRecord log: log [
	"Record aRecord as installed in group, replacing an older record of the same method"

	| recs old |
	recs := self records at: group ifAbsentPut: [ OrderedCollection new ].
	old := recs detect: [ :r | r key = aRecord key ] ifNone: [ nil ].
	old
		ifNil: [ recs add: aRecord ]
		ifNotNil: [ recs at: (recs indexOf: old) put: aRecord ].
	log add: [
		old
			ifNil: [ recs remove: aRecord ifAbsent: [  ] ]
			ifNotNil: [ recs at: (recs indexOf: aRecord) put: old ].
		recs isEmpty ifTrue: [ self records removeKey: group ifAbsent: [  ] ] ]
]

{ #category : 'private - compiling' }
CairoPluginInstaller class >> rename: aSource selector: oldSelector to: newSelector [
	"Answer aSource with its selector replaced by newSelector: each keyword is replaced at its position in the source (last first), so comments, pragmas and formatting stay as they are"

	| positions oldParts newParts result |
	positions := (RBParser parseMethod: aSource) keywordsPositions asArray.
	oldParts := oldSelector keywords.
	newParts := newSelector keywords.
	positions size = oldParts size ifFalse: [
		self error: 'cannot rename ' , oldSelector ].
	result := aSource.
	positions size to: 1 by: -1 do: [ :i |
		| p |
		p := positions at: i.
		(result copyFrom: p to: p + (oldParts at: i) size - 1) = (oldParts at: i)
			ifFalse: [ self error: 'cannot rename ' , oldSelector ].
		result := (result copyFrom: 1 to: p - 1) , (newParts at: i)
		          , (result copyFrom: p + (oldParts at: i) size to: result size) ].
	^ result
]

{ #category : 'state' }
CairoPluginInstaller class >> reset [
	"Forget every record and the cache (only for a package reload: the patches installed stay)"

	records := nil.
	cache := nil.
	lastReport := nil
]

{ #category : 'private - checks' }
CairoPluginInstaller class >> runnerIsSameThread [
	"Whether CairoLibrary runs its callouts on the VM thread (cairo objects are not thread-safe; the plugin runs on the VM thread)"

	^ [ CairoLibrary uniqueInstance runner class == TFSameThreadRunner ]
		  on: Error
		  do: [ :e | false ]
]

{ #category : 'tables' }
CairoPluginInstaller class >> specRefusal: spec [
	"Answer nil when the patch of spec can be installed, else why not (a #basic method whose guard fails, a selector not defined locally, lock/unlock when the plugin lacks the optional cairo_ft functions)"

	| cls current |
	cls := self targetClassOf: spec.
	cls ifNil: [ ^ 'the class is missing' ].
	current := cls compiledMethodAt: (spec at: 3) ifAbsent: [ nil ].
	current ifNil: [ ^ 'not defined in ' , cls name ].
	((#( #lock #unlock ) includes: (spec at: 3)) and: [
		 (spec at: 1) = #CairoScaledFont and: [
			 self missingOptionalSymbols notEmpty ] ]) ifTrue: [
		^ 'the plugin lacks the cairo_ft functions' ].
	(self isPatch: current) ifTrue: [ ^ nil ].
	^ CairoPluginGuards mismatchOf: (self keyOf: spec)
]

{ #category : 'tables' }
CairoPluginInstaller class >> specsOf: group [
	"The patches of group: { className. isMeta. selector. primitiveName or nil. mirror class or nil }"

	| specs |
	specs := OrderedCollection new.
	group = #basic ifTrue: [
		self basicTable do: [ :row |
			specs add: { (row at: 1). (row at: 2). (row at: 3). (row at: 4). nil } ] ].
	(self mirrorPatches detect: [ :a | a key = group ] ifNone: [ nil ])
		ifNotNil: [ :a | specs addAll: a value ].
	^ specs asArray
]

{ #category : 'private - compiling' }
CairoPluginInstaller class >> targetClassOf: spec [

	| cls |
	cls := Smalltalk globals at: (spec at: 1) ifAbsent: [ ^ nil ].
	^ (spec at: 2)
		  ifTrue: [ cls class ]
		  ifFalse: [ cls ]
]

{ #category : 'installing' }
CairoPluginInstaller class >> uninstall: groups [
	"Uninstall groups (keeps the wanted groups: the facade decides about them); answer the groups still installed"

	lastReport := OrderedCollection new.
	self quietly: [
		(self groups reverse select: [ :g | groups includes: g ]) do: [ :g |
			self uninstallGroup: g ].
		self flushPending ].
	^ self installedGroups
]

{ #category : 'private - installing' }
CairoPluginInstaller class >> uninstallGroup: group [

	(self records at: group ifAbsent: [ #(  ) ]) reverseDo: [ :r |
		self uninstallRecord: r cache: true ].
	self records removeKey: group ifAbsent: [  ]
]

{ #category : 'private - installing' }
CairoPluginInstaller class >> forgetRecord: r [
	"Remove the record r from the installed ones"

	(self records at: r group ifAbsent: [ nil ]) ifNotNil: [ :recs |
		recs remove: r ifAbsent: [  ].
		recs isEmpty ifTrue: [ self records removeKey: r group ifAbsent: [  ] ] ]
]

{ #category : 'private - installing' }
CairoPluginInstaller class >> uninstallRecord: r cache: keep [
	"Put the recorded original back when the method is still ours (or uFFI's callout of the original), queue the removal of the added methods and of the ffi copy (flushPending removes them once no process runs the patch or an added method), and, when keep, keep r in the cache"

	| cls current |
	cls := r targetClass.
	cls ifNil: [ ^ lastReport add: r methodName , ': the class is gone' ].
	current := cls compiledMethodAt: r selector ifAbsent: [ nil ].
	((self isPatch: current) or: [
		 current notNil and: [
			 (current propertyAt: #ffiNonCompiledMethod ifAbsent: [ nil ]) == r original ] ])
		ifTrue: [
			self put: r original in: cls at: r selector protocol: r originalProtocol.
			(cls compiledMethodAt: r selector) == r original ifFalse: [
				lastReport add: r methodName , ': the original could not be restored' ] ]
		ifFalse: [
			lastReport add:
				r methodName , ': not patched any more (changed since the install), kept' ].
	r added reverseDo: [ :a |
		(cls compiledMethodAt: a selector ifAbsent: [ nil ]) ifNotNil: [ :m |
			(m hasPragmaNamed: #cairoPluginAdded:patch:) ifTrue: [
				self pending add: { r. a selector. m } ] ] ].
	(cls compiledMethodAt: r ffiSelector ifAbsent: [ nil ]) ifNotNil: [ :m |
		(self isCopy: m of: r)
			ifTrue: [ self pending add: { r. r ffiSelector. self stubOf: m } ]
			ifFalse: [
				lastReport add: cls name , '>>' , r ffiSelector
					, ': not the copy CairoPlugin compiled, kept' ] ].
	keep ifTrue: [ self cache at: r key put: r ]
]

{ #category : 'state' }
CairoPluginInstaller class >> pending [
	"The removals the uninstalls deferred: { record. selector. method (a uFFI stub for an ffi copy) }"

	^ pending ifNil: [ pending := OrderedCollection new ]
]

{ #category : 'private - installing' }
CairoPluginInstaller class >> flushPending [
	"Remove the ffi copies and added methods queued by the uninstalls, except those of a record whose patch or added method a process runs (it would send them when it resumes); forget those that were replaced or put back by an install since"

	| running installed |
	self pending isEmpty ifTrue: [ ^ self ].
	running := self runningMethods.
	installed := self installedMethods.
	pending := self pending reject: [ :item |
		           | r sel m cls current |
		           r := item at: 1.
		           sel := item at: 2.
		           m := item at: 3.
		           cls := r targetClass.
		           current := cls ifNotNil: [ cls compiledMethodAt: sel ifAbsent: [ nil ] ].
		           (current isNil or: [ (self stubOf: current) ~~ m or: [ installed includes: m ] ])
			           ifTrue: [ true ]
			           ifFalse: [
				           ((running includes: r method) or: [
					            r added anySatisfy: [ :a | running includes: a method ] ])
					           ifTrue: [ false ]
					           ifFalse: [
						           cls removeSelector: sel.
						           true ] ] ]
]

{ #category : 'private - installing' }
CairoPluginInstaller class >> installedMethods [
	"The patches, ffi copies and added methods of the installed records (an IdentitySet)"

	| set |
	set := IdentitySet new.
	self records do: [ :recs |
		recs do: [ :r |
			set add: r method.
			r ffiCopy ifNotNil: [ :c | set add: c ].
			r added do: [ :a | set add: a method ] ] ].
	^ set
]

{ #category : 'private - installing' }
CairoPluginInstaller class >> runningMethods [
	"The methods a context of a process runs, the active process included (an IdentitySet of CompiledMethods: a block's is its home method)"

	| set active |
	set := IdentitySet new.
	active := Processor activeProcess.
	Process allSubInstancesDo: [ :p |
		| ctx |
		ctx := p == active
			       ifTrue: [ thisContext ]
			       ifFalse: [ p suspendedContext ].
		[ ctx notNil ] whileTrue: [
			set add: ctx method.
			ctx := ctx sender ] ].
	^ set
]

{ #category : 'verifying' }
CairoPluginInstaller class >> verify [
	"Check the installed patches (see CairoPlugin class>>#verify); heal uFFI's overwrite of a patch; answer the problems found, as Strings"

	| problems |
	problems := OrderedCollection new.
	self quietly: [ self flushPending ].
	self installedGroups isEmpty ifTrue: [
		self missingOptionalSymbols do: [ :s |
			problems add: 'missing optional symbol: ' , s ].
		^ problems asArray ].
	self runnerIsSameThread ifFalse: [
		self quietly: [
			self groups reverse do: [ :g | self uninstallGroup: g ].
			self flushPending ].
		problems add:
			'runner is not TFSameThreadRunner: every group uninstalled (wanted groups kept)'.
		^ problems asArray ].
	CairoPlugin isBound ifFalse: [ problems add: 'installed but unbound' ].
	self quietly: [ problems addAll: (self healAndReport: true) ].
	self installedGroups do: [ :g |
		(self staleRecordsOf: g) do: [ :r |
			problems add: 'stale patch: ' , r methodName , ' (group ' , g printString
				, '; install replaces it)' ] ].
	"#basic: a patched method whose guard stopped matching (its record is uninstalled)"
	(self records at: #basic ifAbsent: [ #(  ) ]) copy do: [ :r |
		(CairoPluginGuards mismatchOf: r key) ifNotNil: [ :m |
			self quietly: [
				self uninstallRecord: r cache: true.
				self forgetRecord: r ].
			problems add: m , ' (group #basic, ' , r methodName , ' uninstalled)' ] ].
	(self installedGroups copyWithout: #basic) do: [ :g |
		| overrides mismatches |
		overrides := CairoPluginGuards subclassOverridesOf: g.
		overrides isEmpty ifFalse: [
			self quietly: [ self uninstallGroup: g ].
			overrides do: [ :o |
				problems add: o , ' (group ' , g printString , ' uninstalled)' ] ].
		(self installedGroups includes: g) ifTrue: [
			"a replicated method changed since the install: the primitive would bypass it"
			mismatches := CairoPluginGuards mismatchesOf: g.
			mismatches isEmpty ifFalse: [
				self quietly: [ self uninstallGroup: g ].
				mismatches do: [ :m |
					problems add: m , ' (group ' , g printString , ' uninstalled)' ] ] ] ].
	self quietly: [ self flushPending ].
	self missingOptionalSymbols do: [ :s |
		problems add: 'missing optional symbol: ' , s ].
	^ problems asArray
]

{ #category : 'state' }
CairoPluginInstaller class >> wantedGroups [
	"The groups CairoPlugin startUp: installs when the image starts on a VM with the plugin"

	^ wantedGroups ifNil: [ #(  ) ]
]

{ #category : 'state' }
CairoPluginInstaller class >> wantedGroups: groups [

	wantedGroups := self groups select: [ :g | groups includes: g ]
]
