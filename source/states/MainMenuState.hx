package states;

import flixel.FlxObject;
import flixel.effects.FlxFlicker;
import flixel.ui.FlxButton;
import lime.app.Application;
import states.editors.MasterEditorMenu;
import options.OptionsState;

class MainMenuState extends MusicBeatState
{
	public static var fnafVersion:String = "1.1"; // This is also used for Discord RPC
	public static var psychEngineVersion:String = '1.0.4'; // This is also used for Discord RPC

	var spritePath:String = 'menus/mainMenu/';

	static var showOutdatedWarning:Bool = true;

	override function create()
	{
		FlxG.mouse.visible = true;
		super.create();

		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		persistentUpdate = persistentDraw = true;

		var bg:FlxSprite = new FlxSprite(0, 0).loadGraphic(Paths.image(spritePath + 'bg'));
		bg.frames = Paths.getSparrowAtlas(spritePath + 'bg');
		bg.animation.addByPrefix('play', 'idle', 18, true);

		bg.scale.set(0.666666, 0.666666);
		bg.updateHitbox();
		bg.animation.play('play');
		add(bg);

		var logothing:FlxSprite = new FlxSprite().loadGraphic(Paths.image(spritePath + 'fnaf3logo'));
		logothing.scrollFactor.set(0, 0);
		logothing.screenCenter();
		logothing.updateHitbox();
		logothing.scale.set(0.666666, 0.666666);
		add(logothing);

		var versionShit:FlxText = new FlxText(1000, FlxG.height - 44, 0, '', 16);
		versionShit.setFormat("stalker2.ttf", 16, FlxColor.WHITE, FlxTextAlign.RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		versionShit.scrollFactor.set();
		versionShit.text = 'Vs FNaF 3 v' + fnafVersion + '\nPsych Engine v' + psychEngineVersion;
		add(versionShit);

		#if ACHIEVEMENTS_ALLOWED
		// Unlocks "Freaky on a Friday Night" achievement if it's a Friday and between 18:00 PM and 23:59 PM
		var leDate = Date.now();
		if (leDate.getDay() == 5 && leDate.getHours() >= 18)
			Achievements.unlock('friday_night_play');

		#if MODS_ALLOWED
		Achievements.reloadList();
		#end
		#end

		#if CHECK_FOR_UPDATES
		if (showOutdatedWarning && ClientPrefs.data.checkForUpdates && substates.OutdatedSubState.updateVersion != psychEngineVersion)
		{
			persistentUpdate = false;
			showOutdatedWarning = false;
			openSubState(new substates.OutdatedSubState());
		}
		#end

		var newgame = new FlxButton(0, 0, " ", newgamestart);
		newgame.loadGraphic(Paths.image(spritePath + 'buttonStory'), true, 500, 55);
		newgame.screenCenter();
		newgame.x = -1;
		newgame.y = 380;
		add(newgame);

		var loadgame = new FlxButton(0, 0, " ", loadgamestart);
		loadgame.loadGraphic(Paths.image(spritePath + 'buttonFreeplay'), true, 500, 55);
		loadgame.screenCenter();
		loadgame.x = -1;
		loadgame.y = 460;
		add(loadgame);

		var credits = new FlxButton(0, 0, " ", creditsstart);
		credits.loadGraphic(Paths.image(spritePath + 'buttonCredits'), true, 500, 55);
		credits.screenCenter();
		credits.x = -1;
		credits.y = 540;
		add(credits);

		var extra = new FlxButton(0, 0, " ", extrastart);
		extra.loadGraphic(Paths.image(spritePath + 'buttonOptions'), true, 500, 55);
		extra.screenCenter();
		extra.x = -1;
		extra.y = 620;
		add(extra);
	}

	function newgamestart()
	{
		MusicBeatState.switchState(new StoryMenuState());
		FlxG.sound.play(Paths.sound('done'), 0.7);
	}

	function loadgamestart()
	{
		MusicBeatState.switchState(new FreeplayState());
		FlxG.sound.play(Paths.sound('done'), 0.7);
	}

	function creditsstart()
	{
		MusicBeatState.switchState(new CreditsState());
		FlxG.sound.play(Paths.sound('done'), 0.7);
	}

	function extrastart()
	{
		MusicBeatState.switchState(new options.OptionsState());
		FlxG.sound.play(Paths.sound('done'), 0.7);
	}

	var selectedSomethin:Bool = false;

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music.volume < 0.8)
			FlxG.sound.music.volume = Math.min(FlxG.sound.music.volume + 0.5 * elapsed, 0.8);

		#if desktop
		if (controls.justPressed('debug_1'))
		{
			selectedSomethin = true;
			FlxG.mouse.visible = false;
			MusicBeatState.switchState(new MasterEditorMenu());
		}
		#end

		super.update(elapsed);
	}
}
