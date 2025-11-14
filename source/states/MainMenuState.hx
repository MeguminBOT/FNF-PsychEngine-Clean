package states;

import backend.ScriptableState;
import states.editors.MasterEditorMenu;
import options.OptionsState;
#if LUA_ALLOWED
import psychlua.*;
#else
import psychlua.LuaUtils;
import psychlua.HScript;
#end
#if LUA_ALLOWED
import psychlua.*;
#else
import psychlua.LuaUtils;
import psychlua.HScript;
#end

class MainMenuState extends ScriptableState {
	public static var psychEngineVersion:String = '1.0.4'; // This is also used for Discord RPC
	
	static var showOutdatedWarning:Bool = true;

	var variantSelector:FlxText;
	var variantsList:Array<String> = [];
	var currentVariantIndex:Int = 0;
	public static var savedVariant:String = 'psych'; // Persist selection across state changes

	override function create() {
		super.create();

		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("In the Menus", null);
		#end

		persistentUpdate = persistentDraw = true;
		FlxG.camera.bgColor = FlxColor.BLACK;

		// Set script folder and detect variants
		scriptFolder = 'MainMenuState';
		variantsList = getScriptVariants();
		
		// Ensure we have at least one variant
		if (variantsList.length == 0)
			variantsList.push('psych'); // Default fallback
		
		// Load saved variant or first available
		if (variantsList.contains(savedVariant))
		{
			currentVariantIndex = variantsList.indexOf(savedVariant);
			scriptSubfolder = savedVariant;
		}
		else if (variantsList.length > 0)
		{
			scriptSubfolder = variantsList[0];
			savedVariant = variantsList[0];
		}
		
		loadScripts();
		callOnScripts('onCreate');
		callOnScripts('onCreatePost');

		// Create variant selector UI if multiple variants exist
		if (variantsList.length > 1)
		{
			variantSelector = new FlxText(FlxG.width - 320, 12, 300, '', 16);
			variantSelector.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, RIGHT, OUTLINE, FlxColor.BLACK);
			variantSelector.scrollFactor.set();
			updateVariantText();
			add(variantSelector);
		}

		var psychVer:FlxText = new FlxText(12, FlxG.height - 44, 0, "Psych Engine v" + psychEngineVersion, 12);
		psychVer.scrollFactor.set();
		psychVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(psychVer);
	}
	
	function updateVariantText()
	{
		if (variantSelector != null && variantsList.length > 0)
		{
			var current = variantsList[currentVariantIndex];
			variantSelector.text = '< ${current} >';
		}
	}
	
	function switchVariant(direction:Int)
	{
		if (variantsList.length <= 1) return;
		
		currentVariantIndex += direction;
		if (currentVariantIndex < 0)
			currentVariantIndex = variantsList.length - 1;
		if (currentVariantIndex >= variantsList.length)
			currentVariantIndex = 0;
		
		var newVariant = variantsList[currentVariantIndex];
		savedVariant = newVariant;
		
		FlxG.sound.play(Paths.sound('scrollMenu'));
		updateVariantText();
		
		// Remove variant selector before reload (will be recreated after)
		if (variantSelector != null)
		{
			remove(variantSelector);
			variantSelector = null;
		}
		
		// Reload with new variant
		reloadScriptsWithVariant(newVariant);
		
		// Recreate variant selector
		if (variantsList.length > 1)
		{
			variantSelector = new FlxText(FlxG.width - 320, 12, 300, '', 16);
			variantSelector.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, RIGHT, OUTLINE, FlxColor.BLACK);
			variantSelector.scrollFactor.set();
			updateVariantText();
			add(variantSelector);
		}
	}

	override function update(elapsed:Float) {
		// Variant selector mouse input
		if (variantSelector != null && FlxG.mouse.overlaps(variantSelector))
		{
			if (FlxG.mouse.justPressed)
				switchVariant(1);
			else if (FlxG.mouse.justPressedRight)
				switchVariant(-1);
		}
		
		var ret:Dynamic = callOnScripts('onUpdate', [elapsed]);
		if (ret == LuaUtils.Function_Stop) {
			super.update(elapsed);
			return;
		}

		if (controls.justPressed('debug_1')) {
			FlxG.mouse.visible = false;
			MusicBeatState.switchState(new MasterEditorMenu());
		}

		callOnScripts('onUpdatePost', [elapsed]);
		super.update(elapsed);
	}

	// Only state switching logic - scripts handle everything else
	public function onItemSelected(option:String) {
		// Ensure mods are reloaded before switching states
		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();

		switch (option) {
			case 'story_mode':
				MusicBeatState.switchState(new StoryMenuState());
			case 'freeplay':
				MusicBeatState.switchState(new FreeplayState());

			#if MODS_ALLOWED
			case 'mods':
				MusicBeatState.switchState(new ModsMenuState());
			#end

			#if ACHIEVEMENTS_ALLOWED
			case 'achievements':
				MusicBeatState.switchState(new AchievementsMenuState());
			#end

			case 'credits':
				MusicBeatState.switchState(new CreditsState());
			case 'options':
				MusicBeatState.switchState(new OptionsState());
				OptionsState.onPlayState = false;
				if (PlayState.SONG != null) {
					PlayState.SONG.arrowSkin = null;
					PlayState.SONG.splashSkin = null;
					PlayState.stageUI = 'normal';
				}
			case 'donate':
				CoolUtil.browserLoad('https://ninja-muffin24.itch.io/funkin');
			default:
				trace('Menu Item ${option} doesn\'t do anything');
		}
	}
}
