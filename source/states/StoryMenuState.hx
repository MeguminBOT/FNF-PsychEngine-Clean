package states;

import backend.WeekData;
import backend.Highscore;
import backend.Song;

import flixel.group.FlxGroup;
import flixel.graphics.FlxGraphic;
import flixel.ui.FlxButton;

import objects.MenuItem;
import objects.MenuCharacter;

import options.GameplayChangersSubstate;
import substates.ResetScoreSubState;

import backend.StageData;

class StoryMenuState extends MusicBeatState
{
	private static var curWeek:Int = 0;
	public static var weekCompleted:Map<String, Bool> = new Map<String, Bool>();
	var loadedWeeks:Array<WeekData> = [];

	private static var lastDifficultyName:String = '';
	var curDifficulty:Int = 1;

	var spritePath:String = 'menus/storyMenu/';
	var bg:FlxSprite;
	var startButton:FlxButton;
	var normalButton:FlxButton;
	var easyButton:FlxButton;

	override function create()
	{
		FlxG.mouse.visible = true;

		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		persistentUpdate = persistentDraw = true;
		PlayState.isStoryMode = true;
		WeekData.reloadWeekFiles(true);

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		if(WeekData.weeksList.length < 1)
		{
			FlxTransitionableState.skipNextTransIn = true;
			persistentUpdate = false;
			MusicBeatState.switchState(new states.ErrorState("NO WEEKS ADDED FOR STORY MODE\n\nPress ACCEPT to go to the Week Editor Menu.\nPress BACK to return to Main Menu.",
				function() MusicBeatState.switchState(new states.editors.WeekEditorState()),
				function() MusicBeatState.switchState(new states.MainMenuState())));
			return;
		}

		if(curWeek >= WeekData.weeksList.length) curWeek = 0;

		var num:Int = 0;
		var itemTargetY:Float = 0;
		for (i in 0...WeekData.weeksList.length)
		{
			var weekFile:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			var isLocked:Bool = weekIsLocked(WeekData.weeksList[i]);
			if(!isLocked || !weekFile.hiddenUntilUnlocked)
			{
				loadedWeeks.push(weekFile);
				WeekData.setDirectoryFromWeek(weekFile);
				if (isLocked) {}
				num++;
			}
		}
		WeekData.setDirectoryFromWeek(loadedWeeks[0]);

		Difficulty.resetList();
		if(lastDifficultyName == '')
		{
			lastDifficultyName = Difficulty.getDefault();
		}
		curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(lastDifficultyName)));

		changeWeek();
		changeDifficulty();

		super.create();

		bg = new FlxSprite(-200, -200);
		bg.frames = Paths.getSparrowAtlas(spritePath + 'bg');
		bg.animation.addByPrefix('play', 'idle', 18, true);
		bg.setGraphicSize(Std.int(bg.width * 1.175));
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);
		bg.animation.play('play');
		bg.scale.set(0.666666, 0.666666);
		bg.updateHitbox();
		bg.x = 0;
		bg.y = 0;

		startButton = new FlxButton(0, 0, " ", selectDiff);
		startButton.screenCenter();
		add(startButton);
		startButton.loadGraphic(Paths.image(spritePath + 'start'), true, 169, 35);
		startButton.x = 535;
		startButton.y = 385;
	}

	override function closeSubState() {
		persistentUpdate = true;
		changeWeek();
		super.closeSubState();
	}

	override function update(elapsed:Float)
	{
		if (controls.BACK && !movedBack && !selectedWeek)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			movedBack = true;
			MusicBeatState.switchState(new MainMenuState());
		}

		super.update(elapsed);
	}

	var movedBack:Bool = false;
	var selectedWeek:Bool = false;
	var stopspamming:Bool = false;

	function selectDiff()
	{
		remove(startButton);

		normalButton = new FlxButton(0, 0, " ", startweek);
		normalButton.screenCenter();
		add(normalButton);
		normalButton.loadGraphic(Paths.image(spritePath + 'diffNormal'), true, 169, 35);
		normalButton.antialiasing = ClientPrefs.data.antialiasing;
		normalButton.x = 535;
		normalButton.y = 367;
		normalButton.onOver.callback = onNormalHighlight.bind();

		easyButton = new FlxButton(0, 0, " ", startweekEasy);
		easyButton.screenCenter();
		add(easyButton);
		easyButton.loadGraphic(Paths.image(spritePath + 'diffEasy'), true, 169, 35);
		easyButton.antialiasing = ClientPrefs.data.antialiasing;
		easyButton.x = 535;
		easyButton.y = 403;
		easyButton.onOver.callback = onEasyHighlight.bind();
	}

	function startweek()
	{
		persistentUpdate = false;

		if (!weekIsLocked(loadedWeeks[curWeek].fileName)) {
			if (stopspamming == false) {
				FlxG.sound.play(Paths.sound('confirmMenu'));
				stopspamming = true;
			}

			FlxG.mouse.visible = false;
			var songArray:Array<String> = [];
			var leWeek:Array<Dynamic> = loadedWeeks[curWeek].songs;
			for (i in 0...leWeek.length) {
				songArray.push(leWeek[i][0]);
			}

			PlayState.storyPlaylist = songArray;
			PlayState.isStoryMode = true;
			selectedWeek = true;

			var diffic = Difficulty.getFilePath(curDifficulty);
			if(diffic == null) diffic = '';
			
			#if debug
			trace('Difficulty: ' + diffic);
			#end

			PlayState.storyDifficulty = curDifficulty;
			PlayState.SONG = Song.loadFromJson(PlayState.storyPlaylist[0].toLowerCase() + diffic, PlayState.storyPlaylist[0].toLowerCase());
			PlayState.campaignMisses = 0;

			new FlxTimer().start(1, function(tmr:FlxTimer) {
				LoadingState.loadAndSwitchState(new PlayState(), true);
			});

		} else {
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}
	}

	function startweekEasy()
	{
		persistentUpdate = false;

		if (!weekIsLocked(loadedWeeks[curWeek].fileName)) {
			if (stopspamming == false) {
				FlxG.sound.play(Paths.sound('confirmMenu'));
				stopspamming = true;
			}

			FlxG.mouse.visible = false;
			var songArray:Array<String> = [];
			var leWeek:Array<Dynamic> = loadedWeeks[curWeek].songs;
			for (i in 0...leWeek.length) {
				songArray.push(leWeek[i][0]);
			}

			PlayState.storyPlaylist = songArray;
			PlayState.isStoryMode = true;
			selectedWeek = true;

			var diffic = Difficulty.getFilePath(curDifficulty);
			if(diffic == null) diffic = '';

			#if debug
			trace('Difficulty: ' + diffic);
			#end
	
			PlayState.storyDifficulty = curDifficulty;
			PlayState.SONG = Song.loadFromJson(PlayState.storyPlaylist[0].toLowerCase() + diffic, PlayState.storyPlaylist[0].toLowerCase());
			PlayState.campaignMisses = 0;

			new FlxTimer().start(1, function(tmr:FlxTimer) {
				LoadingState.loadAndSwitchState(new PlayState(), true);
			});

		} else {
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}
	}

	function onNormalHighlight() 
	{
		persistentUpdate = false;

		if (curDifficulty != 1) {
			curDifficulty = 1;
		}

		#if debug
		trace('Difficulty: ' + curDifficulty);
		#end
	}
	
	function onEasyHighlight() 
	{
		persistentUpdate = false;

		if (curDifficulty != 0) {
			curDifficulty = 0;
		}

		#if debug
		trace('Difficulty: ' + curDifficulty);
		#end
	}

	function changeDifficulty(change:Int = 0):Void
	{
		curDifficulty += change;

		if (curDifficulty < 0)
			curDifficulty = Difficulty.list.length-1;
		if (curDifficulty >= Difficulty.list.length)
			curDifficulty = 0;

		WeekData.setDirectoryFromWeek(loadedWeeks[curWeek]);

		var diff:String = Difficulty.getString(curDifficulty, false);
		lastDifficultyName = diff;
	}

	var lerpScore:Int = 49324858;
	var intendedScore:Int = 0;

	function changeWeek(change:Int = 0):Void
	{
		curWeek += change;

		if (curWeek >= loadedWeeks.length)
			curWeek = 0;
		if (curWeek < 0)
			curWeek = loadedWeeks.length - 1;

		var leWeek:WeekData = loadedWeeks[curWeek];
		WeekData.setDirectoryFromWeek(leWeek);

		var leName:String = Language.getPhrase('storyname_${leWeek.fileName}', leWeek.storyName);

		var unlocked:Bool = !weekIsLocked(leWeek.fileName);

		PlayState.storyWeek = curWeek;

		Difficulty.loadFromWeek();

		if(Difficulty.list.contains(Difficulty.getDefault()))
			curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(Difficulty.getDefault())));
		else
			curDifficulty = 0;

		var newPos:Int = Difficulty.list.indexOf(lastDifficultyName);
		//trace('Pos of ' + lastDifficultyName + ' is ' + newPos);
		if(newPos > -1)
		{
			curDifficulty = newPos;
		}
	}

	function weekIsLocked(name:String):Bool {
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return (!leWeek.startUnlocked && leWeek.weekBefore.length > 0 && (!weekCompleted.exists(leWeek.weekBefore) || !weekCompleted.get(leWeek.weekBefore)));
	}
}
