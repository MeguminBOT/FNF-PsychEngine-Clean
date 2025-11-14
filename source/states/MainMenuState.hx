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


class MainMenuState extends ScriptableState
{
	public static var psychEngineVersion:String = '1.0.4'; // This is also used for Discord RPC
	static var showOutdatedWarning:Bool = true;

	override function create()
	{
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

		// Set script folder and load
		scriptFolder = 'MainMenuState';
		loadScripts();
		callOnScripts('onCreate');
		callOnScripts('onCreatePost');
	}

	override function update(elapsed:Float)
	{
		var ret:Dynamic = callOnScripts('onUpdate', [elapsed]);
		if (ret == LuaUtils.Function_Stop)
		{
			super.update(elapsed);
			return;
		}

		callOnScripts('onUpdatePost', [elapsed]);
		super.update(elapsed);
	}

	// Only state switching logic - scripts handle everything else
	public function onItemSelected(option:String)
	{
		switch (option)
		{
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
				if (PlayState.SONG != null)
				{
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
