package backend;

import flixel.FlxG;
import flixel.FlxBasic;
import flixel.FlxSprite;
import flixel.FlxObject;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.effects.FlxFlicker;
import flixel.util.FlxAxes;
import lime.app.Application;

#if sys
import sys.FileSystem;
#end

#if LUA_ALLOWED
import psychlua.*;
#else
import psychlua.LuaUtils;
import psychlua.HScript;
#end

#if HSCRIPT_ALLOWED
import psychlua.HScript.CustomFlxColor;
import psychlua.HScript.CustomFlxTextBorderStyle;
import psychlua.HScript.CustomFlxTextAlign;
import psychlua.HScript.CustomFlxAxes;
#end

/**
 * Base class for states that want full script control.
 * Provides script loading, management, and helper methods.
 * 
 * Performance-focused: Direct calls, minimal overhead, reusable objects.
 */
class ScriptableState extends MusicBeatState
{
	// Scripting
	#if LUA_ALLOWED public var luaArray:Array<FunkinLua> = []; #end
	#if HSCRIPT_ALLOWED public var hscriptArray:Array<HScript> = []; #end

	// Script folder to load from (relative to scripts/)
	public var scriptFolder:String = '';
	
	// Script subfolder for variants (e.g., "default", "alt", etc.)
	public var scriptSubfolder:String = '';
	
	// Track objects added after scripts start loading
	var scriptAddedObjects:Array<FlxBasic> = [];

	// Override add/insert to automatically track script-added objects
	override public function add(obj:FlxBasic):FlxBasic {
		var result = super.add(obj);
		if (obj != null)
			scriptAddedObjects.push(obj);
		return result;
	}

	override public function insert(pos:Int, obj:FlxBasic):FlxBasic {
		var result = super.insert(pos, obj);
		if (obj != null)
			scriptAddedObjects.push(obj);
		return result;
	}

	public inline function createSpriteGroup():FlxTypedGroup<FlxSprite> {
		return new FlxTypedGroup<FlxSprite>();
	}

	/**
	 * Load scripts from the specified folder.
	 * Call this in your create() after setting scriptFolder.
	 */
	public function loadScripts()
	{
		if (scriptFolder == '')
		{
			trace('ScriptableState: No scriptFolder set, skipping script loading');
			return;
		}

		trace('ScriptableState: Loading scripts from: ' + scriptFolder + (scriptSubfolder != '' ? '/' + scriptSubfolder : ''));
		#if MODS_ALLOWED
		
		var filesPushed:Array<String> = [];
		var basePath:String = 'scripts/' + scriptFolder + '/' + (scriptSubfolder != '' ? scriptSubfolder + '/' : '');
		var foldersToCheck:Array<String> = [Paths.getSharedPath(basePath)];

		for (mod in Mods.parseList().enabled)
			foldersToCheck.push(Paths.mods('$mod/' + basePath));

		for (folder in foldersToCheck)
		{
			if (FileSystem.exists(folder))
			{
				for (file in FileSystem.readDirectory(folder))
				{
					#if LUA_ALLOWED
					if (file.toLowerCase().endsWith('.lua') && !filesPushed.contains(file))
					{
						trace('ScriptableState: Loading Lua script: ' + folder + file);
						var script:FunkinLua = new FunkinLua(folder + file);
						luaArray.push(script);
						filesPushed.push(file);
					}
					#end

					#if HSCRIPT_ALLOWED
					if (file.toLowerCase().endsWith('.hx') && !filesPushed.contains(file))
					{
						trace('ScriptableState: Loading HScript: ' + folder + file);
						var script:HScript = new HScript(null, folder + file, null, true);
						hscriptArray.push(script);
						filesPushed.push(file);
					}
					#end
				}
			}
		}

		// Expose objects to scripts
		exposeToScripts();

		// Execute HScripts after variables are set
		#if HSCRIPT_ALLOWED
		for (script in hscriptArray)
		{
			try {
				var ret:Dynamic = script.execute();
				script.returnValue = ret;
			} catch(e:Dynamic) {
				trace('ScriptableState: Error executing script: ' + e);
			}
		}
		#end

		trace('ScriptableState: Finished loading scripts. Lua: ' + luaArray.length + ', HScript: ' + hscriptArray.length);
		#end
	}
	
	/**
	 * Get available script subfolders for the current scriptFolder.
	 * Returns array of subfolder names found in both shared and mod directories.
	 */
	public function getScriptVariants():Array<String>
	{
		var variants:Array<String> = [];
		#if MODS_ALLOWED
		var basePath:String = 'scripts/' + scriptFolder + '/';
		var foldersToCheck:Array<String> = [Paths.getSharedPath(basePath)];
		
		for (mod in Mods.parseList().enabled)
			foldersToCheck.push(Paths.mods('$mod/' + basePath));
		
		for (folder in foldersToCheck)
		{
			if (FileSystem.exists(folder) && FileSystem.isDirectory(folder))
			{
				for (item in FileSystem.readDirectory(folder))
				{
					var itemPath = folder + item;
					if (FileSystem.isDirectory(itemPath) && !variants.contains(item))
						variants.push(item);
				}
			}
		}
		#end
		return variants;
	}
	
	/**
	 * Reload scripts with a different subfolder variant.
	 * Cleans up existing scripts before loading new ones.
	 */
	public function reloadScriptsWithVariant(variant:String)
	{
		// Call onDestroy on scripts before cleanup
		#if LUA_ALLOWED
		for (script in luaArray)
			script.call('onDestroy', []);
		#end
		
		#if HSCRIPT_ALLOWED
		for (script in hscriptArray)
		{
			@:privateAccess
			if (script.exists('onDestroy'))
				script.call('onDestroy', []);
		}
		#end
		
		// Remove all objects that scripts added
		for (obj in scriptAddedObjects)
		{
			if (obj != null)
				remove(obj, true);
		}
		scriptAddedObjects = [];
		
		// Clean up script arrays
		#if LUA_ALLOWED
		for (script in luaArray)
			script.stop();
		luaArray = [];
		#end
		
		#if HSCRIPT_ALLOWED
		for (script in hscriptArray)
			script.destroy();
		hscriptArray = [];
		#end
		
		// Set new variant and reload
		scriptSubfolder = variant;
		loadScripts();
		callOnScripts('onCreate');
		callOnScripts('onCreatePost');
	}

	/**
	 * Expose essential objects and classes to scripts.
	 * Override this to add state-specific variables.
	 */
	public function exposeToScripts()
	{
		#if HSCRIPT_ALLOWED
		for (script in hscriptArray)
		{
			// State reference
			script.set('game', this);
			
			// Core Flixel classes
			script.set('FlxG', FlxG);
			script.set('FlxMath', flixel.math.FlxMath);
			script.set('FlxSprite', FlxSprite);
			script.set('FlxObject', FlxObject);
			script.set('FlxTypedGroup', FlxTypedGroup);
			script.set('FlxSound', flixel.sound.FlxSound);
			script.set('FlxText', FlxText);
			script.set('FlxColor', CustomFlxColor);
			script.set('FlxTextBorderStyle', CustomFlxTextBorderStyle);
			script.set('FlxTextAlign', CustomFlxTextAlign);
			script.set('FlxAxes', CustomFlxAxes);
			script.set('FlxTween', FlxTween);
			script.set('FlxEase', FlxEase);
			script.set('FlxFlicker', FlxFlicker);
			
			// Utility classes
			script.set('Math', Math);
			script.set('Type', Type);
			script.set('Reflect', Reflect);
			script.set('Paths', Paths);
			script.set('ClientPrefs', ClientPrefs);
			script.set('controls', controls);
			script.set('Application', Application);
			
			// Script control
			script.set('Function_Stop', LuaUtils.Function_Stop);
			script.set('Function_Continue', LuaUtils.Function_Continue);
			
			trace('ScriptableState: Exposed base objects to HScript: ' + script.origin);
		}
		#end
	}

	// Script callback methods
	public function callOnScripts(
		funcToCall:String, args:Array<Dynamic> = null,
		ignoreStops = false, exclusions:Array<String> = null,
		excludeValues:Array<Dynamic> = null):Dynamic {

		var returnVal:Dynamic = LuaUtils.Function_Continue;
		if (args == null) args = [];
		if (exclusions == null) exclusions = [];
		if (excludeValues == null) excludeValues = [LuaUtils.Function_Continue];

		var result:Dynamic = callOnLuas(funcToCall, args, ignoreStops, exclusions, excludeValues);
		if (result == null || excludeValues.contains(result))
			result = callOnHScript(funcToCall, args, ignoreStops, exclusions, excludeValues);
		return result;
	}

	public function callOnLuas(funcToCall:String, args:Array<Dynamic> = null, ignoreStops = false, exclusions:Array<String> = null,
			excludeValues:Array<Dynamic> = null):Dynamic
	{
		var returnVal:Dynamic = LuaUtils.Function_Continue;
		#if LUA_ALLOWED
		if (args == null) args = [];
		if (exclusions == null) exclusions = [];
		if (excludeValues == null) excludeValues = [LuaUtils.Function_Continue];

		var arr:Array<FunkinLua> = [];
		for (script in luaArray)
		{
			if (script.closed)
			{
				arr.push(script);
				continue;
			}

			if (exclusions.contains(script.scriptName))
				continue;

			var myValue:Dynamic = script.call(funcToCall, args);
			if ((myValue == LuaUtils.Function_StopLua || myValue == LuaUtils.Function_StopAll) && !excludeValues.contains(myValue) && !ignoreStops)
			{
				returnVal = myValue;
				break;
			}

			if (myValue != null && !excludeValues.contains(myValue))
				returnVal = myValue;

			if (script.closed)
				arr.push(script);
		}

		if (arr.length > 0)
			for (script in arr)
				luaArray.remove(script);
		#end
		return returnVal;
	}

	public function callOnHScript(funcToCall:String, args:Array<Dynamic> = null, ?ignoreStops:Bool = false, exclusions:Array<String> = null,
			excludeValues:Array<Dynamic> = null):Dynamic
	{
		var returnVal:Dynamic = LuaUtils.Function_Continue;

		#if HSCRIPT_ALLOWED
		if (exclusions == null) exclusions = [];
		if (excludeValues == null) excludeValues = [LuaUtils.Function_Continue];

		var len:Int = hscriptArray.length;
		if (len < 1) return returnVal;

		for (script in hscriptArray)
		{
			@:privateAccess
			if (script == null || !script.exists(funcToCall) || exclusions.contains(script.origin))
				continue;

			var callValue = script.call(funcToCall, args);
			if (callValue != null)
			{
				var myValue:Dynamic = callValue.returnValue;

				if ((myValue == LuaUtils.Function_StopHScript || myValue == LuaUtils.Function_StopAll)
					&& !excludeValues.contains(myValue)
					&& !ignoreStops)
				{
					returnVal = myValue;
					break;
				}

				if (myValue != null && !excludeValues.contains(myValue))
					returnVal = myValue;
			}
		}
		#end

		return returnVal;
	}

	public function setOnScripts(variable:String, arg:Dynamic, exclusions:Array<String> = null)
	{
		if (exclusions == null) exclusions = [];
		setOnLuas(variable, arg, exclusions);
		setOnHScript(variable, arg, exclusions);
	}

	public function setOnLuas(variable:String, arg:Dynamic, exclusions:Array<String> = null)
	{
		#if LUA_ALLOWED
		if (exclusions == null) exclusions = [];

		for (script in luaArray)
		{
			if (exclusions.contains(script.scriptName))
				continue;

			script.set(variable, arg);
		}
		#end
	}

	public function setOnHScript(variable:String, arg:Dynamic, exclusions:Array<String> = null)
	{
		#if HSCRIPT_ALLOWED
		if (exclusions == null) exclusions = [];

		for (script in hscriptArray)
		{
			if (exclusions.contains(script.origin))
				continue;

			script.set(variable, arg);
		}
		#end
	}

	override function destroy()
	{
		#if LUA_ALLOWED
		for (script in luaArray)
		{
			script.call('onDestroy', []);
			script.stop();
		}
		luaArray = [];
		#end

		#if HSCRIPT_ALLOWED
		for (script in hscriptArray)
		{
			script.call('onDestroy', []);
			script.destroy();
		}
		hscriptArray = [];
		#end

		super.destroy();
	}
}
