package
{
	import flash.display.Sprite;
	import flash.display.MovieClip;
	import flash.display.IGraphicsData;
	import flash.display.GraphicsSolidFill;
	import flash.display.GraphicsPath;
	import flash.display.GraphicsPathCommand;

	import flash.utils.Dictionary;
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;

	import flash.geom.Matrix;
	import flash.net.FileReference;

	import com.codeazur.as3swf.SWF;

	import com.codeazur.as3swf.data.SWFFillStyle;
	import com.codeazur.as3swf.data.SWFShapeRecordStyleChange;
	import com.codeazur.as3swf.data.SWFShapeRecord;
	import com.codeazur.as3swf.data.SWFShapeRecordStraightEdge;
	import com.codeazur.as3swf.data.SWFShapeRecordEnd;
	import com.codeazur.as3swf.data.SWFShapeWithStyle;
	import com.codeazur.as3swf.data.SWFMatrix;
	import com.codeazur.as3swf.data.SWFRectangle;
	import com.codeazur.as3swf.data.SWFSymbol;
	import com.codeazur.as3swf.data.SWFScene;

	import com.codeazur.as3swf.tags.TagEnd;
	import com.codeazur.as3swf.tags.TagShowFrame;
	import com.codeazur.as3swf.tags.TagDefineSceneAndFrameLabelData;
	import com.codeazur.as3swf.tags.TagFileAttributes;
	import com.codeazur.as3swf.tags.TagSetBackgroundColor;
	import com.codeazur.as3swf.tags.TagDefineSprite;
	import com.codeazur.as3swf.tags.TagPlaceObject2;
	import com.codeazur.as3swf.tags.TagDefineShape;
	import com.codeazur.as3swf.tags.TagSymbolClass;
	import com.codeazur.as3swf.tags.TagDoABC;

	import org.as3commons.bytecode.emit.IAbcBuilder;
	import org.as3commons.bytecode.emit.IPackageBuilder;
	import org.as3commons.bytecode.emit.IClassBuilder;
	import org.as3commons.bytecode.emit.ICtorBuilder;

	import org.as3commons.bytecode.emit.impl.AbcBuilder;

	import org.as3commons.bytecode.abc.enum.Opcode;
	import org.as3commons.bytecode.abc.QualifiedName;
	import org.as3commons.bytecode.abc.LNamespace;
	import org.as3commons.bytecode.abc.enum.MultinameKind;
	import org.as3commons.bytecode.abc.Multiname;
	import org.as3commons.bytecode.abc.NamespaceSet;
	import org.as3commons.bytecode.io.AbcSerializer;
	import org.as3commons.bytecode.abc.AbcFile;
	import flash.display.Loader;
	import flash.events.Event;
	import flash.net.URLLoader;
	import flash.net.URLRequest;

	public class BlenderToSFPA extends Sprite
	{
		private var mcsWithClasses:Vector.<MovieClip> = new <MovieClip>[];
		private var props:Dictionary = new Dictionary();
		private var symbolCache:Dictionary = new Dictionary(true);

		public function BlenderToSFPA()
		{
			super();
			var loader:URLLoader = new URLLoader;
			loader.dataFormat = "text";
			var self:BlenderToSFPA = this;
			loader.addEventListener(Event.COMPLETE, function(e:Event):void
				{
					self.makeSWF(makeAllEverything(JSON.parse(loader.data)));
				});
			loader.load(new URLRequest("DUMP.json"));
		}

		// generates bytecode equivalent of doing `this[mcName][key] = prop`
		private function setProperty(constructorBuilder:ICtorBuilder, mcName:String, key:String, prop:*):void
		{
			trace(mcName, key, prop);
			constructorBuilder
				.addOpcode(Opcode.getlocal_0)
				.addOpcode(Opcode.getproperty, [new QualifiedName(mcName, LNamespace.PUBLIC, MultinameKind.QNAME)]);

			if (prop is int)
				constructorBuilder.addOpcode(Opcode.pushbyte, [prop]);
			else if (prop is String)
				constructorBuilder.addOpcode(Opcode.pushstring, [prop]);
			else if (prop is Number)
				constructorBuilder.addOpcode(Opcode.pushdouble, [prop]);
			else if (prop is Boolean)
				prop
					? constructorBuilder.addOpcode(Opcode.pushtrue)
					: constructorBuilder.addOpcode(Opcode.pushfalse);

			if (prop is Array)
			{
				for (var i:int = 0; i < prop["length"]; i++)
				{
					if (prop[i] is int)
						constructorBuilder.addOpcode(Opcode.pushbyte, [prop[i]]);
					else if (prop[i] is String)
						constructorBuilder.addOpcode(Opcode.pushstring, [prop[i]]);
					else if (prop[i] is Number)
						constructorBuilder.addOpcode(Opcode.pushdouble, [prop[i]]);
					else if (prop[i] is Boolean)
						prop[i]
							? constructorBuilder.addOpcode(Opcode.pushtrue)
							: constructorBuilder.addOpcode(Opcode.pushfalse);
				}
				constructorBuilder.addOpcode(Opcode.newarray, [prop["length"]]);
			}

			constructorBuilder.addOpcode(Opcode.setproperty, [new Multiname(key, NamespaceSet.PUBLIC_NSSET, MultinameKind.MULTINAME)]);
		}

		// Makes a SWF with allEverything placed on Stage
		private function makeSWF(allEverything:MovieClip):void
		{
			var swf:SWF = new SWF();
			swf.frameRate = 24;
			swf.frameCount = 1;
			swf.version = 34;

			var sceneAndLabelData:TagDefineSceneAndFrameLabelData = new TagDefineSceneAndFrameLabelData();
			sceneAndLabelData.scenes.push(new SWFScene(0, 'Scene 1'));

			swf.tags.push(new TagFileAttributes());
			swf.tags.push(TagSetBackgroundColor.create(0xcccccc));
			swf.tags.push(sceneAndLabelData);

			var allEverythingSprite:TagDefineSprite = toSWFSprite(swf, allEverything);

			var placeAllEverything:TagPlaceObject2 = new TagPlaceObject2();
			placeAllEverything.hasMatrix = true;
			placeAllEverything.matrix = new SWFMatrix();
			placeAllEverything.matrix.scaleX = 0.5;
			placeAllEverything.matrix.scaleY = 0.5;
			placeAllEverything.hasCharacter = true;
			placeAllEverything.characterId = allEverythingSprite.characterId;
			placeAllEverything.hasName = true;
			placeAllEverything.instanceName = allEverything.name;
			placeAllEverything.depth = 1;
			swf.tags.push(placeAllEverything);

			// Generate Bytecode
			const abcBuilder:IAbcBuilder = new AbcBuilder;
			const packageBuilder:IPackageBuilder = abcBuilder.definePackage("");

			// Main Class
			var classBuilder:IClassBuilder = packageBuilder.defineClass("MainTimeline");
			classBuilder.superClassName = "flash.display.MovieClip";
			classBuilder.isDynamic = true;
			classBuilder.defineProperty(allEverything.name, "flash.display.MovieClip");
			var constructorBuilder:ICtorBuilder = classBuilder.defineConstructor();
			constructorBuilder.addOpcode(Opcode.getlocal_0);
			constructorBuilder.addOpcode(Opcode.pushscope);
			constructorBuilder.addOpcode(Opcode.getlocal_0);
			constructorBuilder.addOpcode(Opcode.constructsuper, [0]);
			for (var key:String in props[allEverything.name])
			{
				setProperty(constructorBuilder, allEverything.name, key, props[allEverything.name][key]);
			}
			constructorBuilder.addOpcode(Opcode.returnvoid);

			// Child Classes (e.g. interact, baddies, aPlats)
			generateAS3(allEverything, packageBuilder);

			// Export generated Bytecode and add it to SWF
			var doABCTag:TagDoABC = TagDoABC.create(new AbcSerializer().serializeAbcFile(abcBuilder.build()));
			swf.tags.push(doABCTag);

			// Make Symbolclass to tell flash what class links to what movie clip and what the main class is
			var symbolClass:TagSymbolClass = new TagSymbolClass();
			symbolClass.symbols.push(SWFSymbol.create(0, "MainTimeline"));
			for (var i:int = 0; i < mcsWithClasses.length; i++)
			{
				var currentMC:MovieClip = mcsWithClasses[i];
				symbolClass.symbols.push(SWFSymbol.create(symbolCache[currentMC].characterId, currentMC.name));
			}

			swf.tags.push(symbolClass);

			swf.tags.push(new TagShowFrame());
			swf.tags.push(new TagEnd());

			var out:ByteArray = new ByteArray();
			swf.publish(out);
			new FileReference().save(out, "SWF.swf");
			trace("SWF Writen!");
		}

		private var classesWithAsFiles:Vector.<String> = new <String>["baddies", "aPlats", "interact"];
		private function generateAS3(allEverything:MovieClip, packageBuilder:IPackageBuilder):void
		{
			var numAsFiles:int = classesWithAsFiles.length;
			for (var i:int = 0; i < numAsFiles; i++)
			{
				var mc:MovieClip = allEverything.getChildByName(classesWithAsFiles[i]) as MovieClip;
				if (mc == null)
				{
					continue;
				}
				trace("generateAS3", i, mc.name);
				mcsWithClasses.push(mc);
				var key:String;
				var classBuilder:IClassBuilder = packageBuilder.defineClass(mc.name);
				classBuilder.superClassName = "flash.display.MovieClip";
				classBuilder.isDynamic = true;
				for (i = 0; i < mc.numChildren; i++)
				{
					var currChild:MovieClip = mc.getChildAt(i) as MovieClip;
					if (currChild.name && currChild.name.length > 0)
					{
						classBuilder.defineProperty(currChild.name, "flash.display.MovieClip");
					}
				}
				var constructorBuilder:ICtorBuilder = classBuilder.defineConstructor();
				constructorBuilder.addOpcode(Opcode.getlocal_0);
				constructorBuilder.addOpcode(Opcode.pushscope);

				constructorBuilder.addOpcode(Opcode.getlocal_0);
				constructorBuilder.addOpcode(Opcode.constructsuper, [0]);

				for (i = 0; i < mc.numChildren; i++)
				{
					currChild = mc.getChildAt(i) as MovieClip;
					for (key in props[currChild.name])
					{
						setProperty(constructorBuilder, currChild.name, key, props[currChild.name][key]);
					}
				}
				constructorBuilder.addOpcode(Opcode.returnvoid);

			}
		}

		private var chid:int = 1;
		private function toSWFSprite(swf:SWF, mc:MovieClip):TagDefineSprite
		{
			if (symbolCache[mc] != null)
				return symbolCache[mc];
			var shape:SWFShapeWithStyle = new SWFShapeWithStyle();
			var numChildren:int = mc.numChildren;
			var hasChildren:Boolean = numChildren > 0;
			var children:Vector.<TagPlaceObject2> = new Vector.<TagPlaceObject2>(mc.numChildren, true);
			var data:Vector.<IGraphicsData> = mc.graphics.readGraphicsData(false);
			var shouldAppendShape:Boolean = data.length > 0;
			var i:int = 0;

			if (hasChildren)
			{
				for (i = 0; i < numChildren; i++)
				{
					var child:MovieClip = mc.getChildAt(i) as MovieClip;
					var sprite:TagDefineSprite = toSWFSprite(swf, child);
					var placer:TagPlaceObject2 = new TagPlaceObject2();
					placer.hasCharacter = true;
					placer.characterId = symbolCache[child].characterId;
					placer.hasName = child.name.length > 0;
					placer.instanceName = child.name;
					placer.hasMatrix = true;
					placer.matrix = new SWFMatrix();
					var transformMatrix:Matrix = child.transform.matrix;
					placer.matrix.scaleX = transformMatrix.a;
					placer.matrix.rotateSkew0 = transformMatrix.b;
					placer.matrix.rotateSkew1 = transformMatrix.c;
					placer.matrix.scaleY = transformMatrix.d;
					placer.matrix.translateX = transformMatrix.tx * 20; // translation is in twips
					placer.matrix.translateY = transformMatrix.ty * 20; // translation is in twips
					placer.depth = (numChildren - i);
					children[i] = placer;
				}
			}

			if (shouldAppendShape)
			{
				var lastX:Number = 0;
				var lastY:Number = 0;
				for (i = 0; i < data.length; i++)
				{
					var current:IGraphicsData = data[i];
					if (current is GraphicsSolidFill)
					{
						shape.initialFillStyles.push(new SWFFillStyle());
						shape.initialFillStyles[shape.initialFillStyles.length - 1].rgb = (current as GraphicsSolidFill).color;
						shape.initialFillStyles[shape.initialFillStyles.length - 1].type = 0x00;
					}
					else if (current is GraphicsPath)
					{
						var currentPath:GraphicsPath = current as GraphicsPath;
						var l:int = 0;
						var currentPathData:Vector.<Number> = currentPath.data;
						for (var j:int = 0; j < currentPath.commands.length; j++)
						{
							var record:SWFShapeRecord;
							switch (currentPath.commands[j])
							{
								case GraphicsPathCommand.MOVE_TO:
									lastX = currentPathData[l++];
									lastY = currentPathData[l++];
									record = new SWFShapeRecordStyleChange();
									(record as SWFShapeRecordStyleChange).fillStyle1 = shape.initialFillStyles.length;
									(record as SWFShapeRecordStyleChange).stateFillStyle1 = true;
									(record as SWFShapeRecordStyleChange).stateMoveTo = true;
									(record as SWFShapeRecordStyleChange).moveDeltaX = lastX * 20;
									(record as SWFShapeRecordStyleChange).moveDeltaY = lastY * 20;
									shape.records.push(record);
									break;
								case GraphicsPathCommand.LINE_TO:
									var x:Number = currentPathData[l++];
									var y:Number = currentPathData[l++];

									var dx:Number = (x - lastX) * 20;
									var dy:Number = (y - lastY) * 20;
									record = new SWFShapeRecordStraightEdge();
									(record as SWFShapeRecordStraightEdge).generalLineFlag = (dx != 0 && dy != 0);
									(record as SWFShapeRecordStraightEdge).vertLineFlag = (dx == 0);
									(record as SWFShapeRecordStraightEdge).deltaX = dx;
									(record as SWFShapeRecordStraightEdge).deltaY = dy;
									shape.records.push(record);
									lastX = x;
									lastY = y;
									break;
							}
						}
					}
				}
				shape.records.push(new SWFShapeRecordEnd());
				var tagShape:TagDefineShape = new TagDefineShape();
				tagShape.shapeBounds = new SWFRectangle();
				tagShape.shapeBounds.rect = mc.getBounds(mc);
				tagShape.shapes = shape;
				tagShape.characterId = chid++;
				swf.tags.push(tagShape);
			}

			var tagSprite:TagDefineSprite = new TagDefineSprite();
			tagSprite.characterId = chid++;
			swf.tags.push(tagSprite);

			if (shouldAppendShape)
			{
				var tagPlace:TagPlaceObject2 = new TagPlaceObject2();
				tagPlace.hasMatrix = true;
				tagPlace.matrix = new SWFMatrix();
				tagPlace.hasCharacter = true;
				tagPlace.characterId = tagShape.characterId;
				tagPlace.depth = 1;
				tagSprite.tags.push(tagPlace);
			}

			if (hasChildren)
			{
				for (i = 0; i < numChildren; i++)
				{
					tagSprite.tags.push(children[i]);
				}
			}
			tagSprite.tags.push(new TagShowFrame());

			// trace(mc.name);
			// trace(tagSprite);
			// trace(children);
			symbolCache[mc] = tagSprite;
			return tagSprite;
		}

		// TODO: Generate MC from Blender JSON
		private function makeAllEverything(data:Object):MovieClip
		{
			var rootDataNode:Object = data['AllEverything'];

			var allEverything:MovieClip = new MovieClip;
			allEverything.name = "AllEverything";

			for (var key:String in rootDataNode)
			{
				var currObj:Object = rootDataNode[key];
				trace(key);
				var container:MovieClip = new MovieClip;
				container.name = key;
				allEverything.addChild(container);
				if (classesWithAsFiles.indexOf(key) != -1)
				{
					for (var childKey:String in currObj)
					{
						trace(childKey);
						var childObj:Object = currObj[childKey];
						var child:MovieClip = new MovieClip;
						child.graphics.beginFill(0);
						child.graphics.drawRect(0, 0, 50, 50);
						child.graphics.endFill();

						container.addChild(child);
						child.name = childKey;

						child.x = childObj["x"];
						child.y = childObj["y"];

						child.scaleX = childObj["scaleX"];
						child.scaleY = childObj["scaleY"];

						child.rotation = childObj["rot"];

						props[child.name] = JSON.parse(JSON.stringify(childObj.props));
					}
				}
				else
				{

					for (var i:uint = 0; i < currObj['shapes']['length']; i++)
					{
						var moveTo:Boolean = true;
						var shape:Array = currObj['shapes'][i];
						container.graphics.beginFill(0);

						for (var j:uint = 0; j < shape.length; j += 2)
						{
							if (moveTo)
							{
								container.graphics.moveTo(shape[j], shape[j + 1]);
								moveTo = false;
							}
							else
							{
								container.graphics.lineTo(shape[j], shape[j + 1]);
							}
						}
						container.graphics.endFill();

					}

					container.x = currObj["x"];
					container.y = currObj["y"];

					container.scaleX = currObj["scaleX"];
					container.scaleY = currObj["scaleY"];

					container.rotation = currObj["rot"];

					props[container.name] = JSON.parse(JSON.stringify(currObj.props));
				}
			}

			props[allEverything.name] = new Object();
			props[allEverything.name].backgroundZs = [0];
			props[allEverything.name].LevelStatus = "Normal";
			stage.addChild(allEverything);
			return allEverything;
		}
	}
}