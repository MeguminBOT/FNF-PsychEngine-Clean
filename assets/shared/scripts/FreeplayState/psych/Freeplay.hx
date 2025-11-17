// Default Freeplay behavior script
// Handles song list, selection, difficulty switching, and preview playback
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.math.FlxMath;
import psychlua.HScript.CustomFlxColor as FlxColor;
import objects.Alphabet;
import objects.HealthIcon;
import objects.MusicPlayer;
import options.GameplayChangersSubstate;
import substates.ResetScoreSubState;
import backend.WeekData;
import backend.Highscore;
import backend.Song;
import backend.Difficulty;
import backend.Mods;
import backend.CoolUtil;
import backend.Language;
import Reflect;

// Selection state
var curSelected:Int = 0;
var lerpSelected:Float = 0;
var curDifficulty:Int = 0;
var holdTime:Float = 0;
var instPlaying:Int = -1;

// Score display
var lerpScore:Int = 0;
var lerpRating:Float = 0;
var intendedScore:Int = 0;
var intendedRating:Float = 0;

// Visual elements
var bg:FlxSprite;
var intendedColor:Int;
var grpSongs:FlxTypedGroup;
var iconArray:Array<HealthIcon> = [];
var scoreText:FlxText;
var scoreBG:FlxSprite;
var diffText:FlxText;
var missingTextBG:FlxSprite;
var missingText:FlxText;
var bottomBG:FlxSprite;
var bottomText:FlxText;
var player:MusicPlayer;

// Visibility culling
var drawDistance:Int = 4;
var lastVisibles:Array<Int> = [];

function onCreate() {
	trace('Freeplay.hx: Creating freeplay menu');

	// Background
	bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
	bg.antialiasing = ClientPrefs.data.antialiasing;
	bg.screenCenter();
	game.add(bg);

	// Song list group
	grpSongs = new FlxTypedGroup();
	game.add(grpSongs);

	// Create song text items and icons
	for (i in 0...songs.length) {
		var songText:Alphabet = new Alphabet(90, 320, songs[i].songName, true);
		songText.targetY = i;
		Reflect.callMethod(grpSongs, Reflect.field(grpSongs, 'add'), [songText]);

		songText.scaleX = Math.min(1, 980 / songText.width);
		songText.snapToPosition();

		// Start hidden for performance
		songText.visible = songText.active = songText.isMenuItem = false;

		Mods.currentModDirectory = songs[i].folder;
		var icon:HealthIcon = new HealthIcon(songs[i].songCharacter);
		icon.sprTracker = songText;
		icon.visible = icon.active = false;

		iconArray.push(icon);
		game.add(icon);
	}
	WeekData.setDirectoryFromWeek();

	// Score UI
	scoreText = new FlxText(FlxG.width * 0.7, 5, 0, '', 32);
	scoreText.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, FlxTextAlign.RIGHT);

	scoreBG = new FlxSprite(scoreText.x - 6, 0).makeGraphic(1, 66, 0xFF000000);
	scoreBG.alpha = 0.6;
	game.add(scoreBG);

	diffText = new FlxText(scoreText.x, scoreText.y + 36, 0, '', 24);
	diffText.font = scoreText.font;
	game.add(diffText);
	game.add(scoreText);

	// Missing chart error display
	missingTextBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
	missingTextBG.alpha = 0.6;
	missingTextBG.visible = false;
	game.add(missingTextBG);

	missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
	missingText.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
	missingText.scrollFactor.set();
	missingText.visible = false;
	game.add(missingText);

	// Bottom instructions
	bottomBG = new FlxSprite(0, FlxG.height - 26).makeGraphic(FlxG.width, 26, 0xFF000000);
	bottomBG.alpha = 0.6;
	game.add(bottomBG);

	var tipText = Language.getPhrase('freeplay_tip',
		'Press SPACE to listen to the Song / Press CTRL to open the Gameplay Changers Menu / Press RESET to Reset your Score and Accuracy.');
	bottomText = new FlxText(bottomBG.x, bottomBG.y + 4, FlxG.width, tipText, 16);
	bottomText.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, FlxTextAlign.CENTER);
	bottomText.scrollFactor.set();
	game.add(bottomText);

	// Music player
	player = new MusicPlayer(game);
	game.add(player);

	// Initialize
	if (curSelected >= songs.length)
		curSelected = 0;

	bg.color = songs[curSelected].color;
	intendedColor = bg.color;
	lerpSelected = curSelected;

	// Load difficulty for the initial song
	Mods.currentModDirectory = songs[curSelected].folder;
	PlayState.storyWeek = songs[curSelected].week;
	Difficulty.loadFromWeek();

	var lastDiff = Difficulty.defaultList.indexOf(lastDifficultyName);
	curDifficulty = Math.round(Math.max(0, lastDiff));

	// Initial score/rating
	intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);
	intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty);
	lerpScore = intendedScore;
	lerpRating = intendedRating;

	// Set initial difficulty text
	var displayDiff:String = Difficulty.getString(curDifficulty);
	if (Difficulty.list.length > 1)
		diffText.text = '< ' + displayDiff.toUpperCase() + ' >';
	else
		diffText.text = displayDiff.toUpperCase();

	positionHighscore();

	changeSelection(0, false);
	updateTexts(0); // Initial visibility update

	trace('Freeplay.hx: Created with ' + songs.length + ' songs');
}

function onUpdate(elapsed:Float) {
	// Volume fade in
	if (FlxG.sound.music.volume < 0.7)
		FlxG.sound.music.volume += 0.5 * elapsed;

	// Lerp score display
	lerpScore = Math.floor(FlxMath.lerp(intendedScore, lerpScore, Math.exp(-elapsed * 24)));
	lerpRating = FlxMath.lerp(intendedRating, lerpRating, Math.exp(-elapsed * 12));

	if (Math.abs(lerpScore - intendedScore) <= 10)
		lerpScore = intendedScore;
	if (Math.abs(lerpRating - intendedRating) <= 0.01)
		lerpRating = intendedRating;

	// Format rating text
	var ratingSplit:Array<String> = Std.string(CoolUtil.floorDecimal(lerpRating * 100, 2)).split('.');
	if (ratingSplit.length < 2)
		ratingSplit.push('');
	while (ratingSplit[1].length < 2)
		ratingSplit[1] += '0';

	var shiftMult:Int = FlxG.keys.pressed.SHIFT ? 3 : 1;

	if (!Reflect.field(player, 'playingMusic')) {
		scoreText.text = Language.getPhrase('personal_best', 'PERSONAL BEST: {1} ({2}%)', [lerpScore, ratingSplit.join('.')]);
		positionHighscore();

		// Song selection input
		if (songs.length > 1) {
			if (FlxG.keys.justPressed.HOME) {
				curSelected = 0;
				changeSelection(0, false);
				holdTime = 0;
			} else if (FlxG.keys.justPressed.END) {
				curSelected = songs.length - 1;
				changeSelection(0, false);
				holdTime = 0;
			}

			if (controls.UI_UP_P) {
				changeSelection(-shiftMult, true);
				holdTime = 0;
			}
			if (controls.UI_DOWN_P) {
				changeSelection(shiftMult, true);
				holdTime = 0;
			}

			// Hold to scroll
			if (controls.UI_DOWN || controls.UI_UP) {
				var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
				holdTime += elapsed;
				var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

				if (holdTime > 0.5 && checkNewHold - checkLastHold > 0)
					changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMult : shiftMult), true);
			}

			// Mouse wheel
			if (FlxG.mouse.wheel != 0) {
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.2);
				changeSelection(-shiftMult * FlxG.mouse.wheel, false);
			}
		}

		// Difficulty switching
		if (controls.UI_LEFT_P) {
			changeDiff(-1);
			updateSongLastDifficulty();
		} else if (controls.UI_RIGHT_P) {
			changeDiff(1);
			updateSongLastDifficulty();
		}
	}

	// Back button - stop preview if playing
	if (controls.BACK && Reflect.field(player, 'playingMusic')) {
		stopPreview();
		return;
	}

	// Gameplay changers
	if (FlxG.keys.justPressed.CONTROL && !Reflect.field(player, 'playingMusic')) {
		game.persistentUpdate = false;
		game.openSubState(new GameplayChangersSubstate());
	}
	// Preview playback
	else if (FlxG.keys.justPressed.SPACE) {
		if (instPlaying != curSelected && !Reflect.field(player, 'playingMusic')) {
			playPreview();
		} else if (instPlaying == curSelected && Reflect.field(player, 'playingMusic')) {
			player.pauseOrResume(!player.playing);
		}
	}
	// Enter song
	else if (controls.ACCEPT && !Reflect.field(player, 'playingMusic')) {
		enterSong();
	}
	// Reset score
	else if (controls.RESET && !Reflect.field(player, 'playingMusic')) {
		game.persistentUpdate = false;
		game.openSubState(new ResetScoreSubState(songs[curSelected].songName, curDifficulty, songs[curSelected].songCharacter));
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	updateTexts(elapsed);
}

function onCloseSubState() {
	changeSelection(0, false);
}

function changeSelection(change:Int, playSound:Bool) {
	if (Reflect.field(player, 'playingMusic'))
		return;

	curSelected += change;
	if (curSelected < 0)
		curSelected = songs.length - 1;
	if (curSelected >= songs.length)
		curSelected = 0;

	updateSongLastDifficulty();

	if (playSound)
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

	// Color tween
	var newColor:Int = songs[curSelected].color;
	if (newColor != intendedColor) {
		intendedColor = newColor;
		FlxTween.cancelTweensOf(bg);
		FlxTween.color(bg, 1, bg.color, intendedColor);
	}

	// Update alpha
	var members:Array<Dynamic> = Reflect.field(grpSongs, 'members');
	for (num in 0...members.length) {
		var item = members[num];
		var icon:HealthIcon = iconArray[num];
		item.alpha = 0.6;
		icon.alpha = 0.6;
		if (item.targetY == curSelected) {
			item.alpha = 1;
			icon.alpha = 1;
		}
	}

	// Load difficulty for selected song
	Mods.currentModDirectory = songs[curSelected].folder;
	PlayState.storyWeek = songs[curSelected].week;
	Difficulty.loadFromWeek();

	var savedDiff:String = songs[curSelected].lastDifficulty;
	var lastDiff:Int = Difficulty.list.indexOf(lastDifficultyName);
	if (savedDiff != null && Difficulty.list.contains(savedDiff))
		curDifficulty = Math.round(Math.max(0, Difficulty.list.indexOf(savedDiff)));
	else if (lastDiff > -1)
		curDifficulty = lastDiff;
	else if (Difficulty.list.contains(Difficulty.getDefault()))
		curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(Difficulty.getDefault())));
	else
		curDifficulty = 0;

	changeDiff(0);
	updateSongLastDifficulty();
}

function changeDiff(change:Int) {
	if (Reflect.field(player, 'playingMusic'))
		return;

	curDifficulty += change;
	if (curDifficulty < 0)
		curDifficulty = Difficulty.list.length - 1;
	if (curDifficulty >= Difficulty.list.length)
		curDifficulty = 0;

	intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);
	intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty);

	lastDifficultyName = Difficulty.getString(curDifficulty, false);
	var displayDiff:String = Difficulty.getString(curDifficulty);
	if (Difficulty.list.length > 1)
		diffText.text = '< ' + displayDiff.toUpperCase() + ' >';
	else
		diffText.text = displayDiff.toUpperCase();

	positionHighscore();
	missingText.visible = false;
	missingTextBG.visible = false;
}

function updateSongLastDifficulty() {
	songs[curSelected].lastDifficulty = Difficulty.getString(curDifficulty, false);
}

function positionHighscore() {
	scoreText.x = FlxG.width - scoreText.width - 6;
	scoreBG.scale.x = FlxG.width - scoreText.x + 6;
	scoreBG.x = FlxG.width - (scoreBG.scale.x / 2);
	diffText.x = Std.int(scoreBG.x + (scoreBG.width / 2));
	diffText.x -= diffText.width / 2;
}

function updateTexts(elapsed:Float) {
	lerpSelected = FlxMath.lerp(curSelected, lerpSelected, Math.exp(-elapsed * 9.6));

	// Hide previously visible items
	for (i in lastVisibles) {
		var members:Array<Dynamic> = Reflect.field(grpSongs, 'members');
		members[i].visible = members[i].active = false;
		iconArray[i].visible = iconArray[i].active = false;
	}
	lastVisibles = [];

	// Show items in range
	var min:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected - drawDistance)));
	var max:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected + drawDistance)));
	var members:Array<Dynamic> = Reflect.field(grpSongs, 'members');

	for (i in min...max) {
		var item = members[i];
		item.visible = item.active = true;
		item.x = ((item.targetY - lerpSelected) * item.distancePerItem.x) + item.startPosition.x;
		item.y = ((item.targetY - lerpSelected) * 1.3 * item.distancePerItem.y) + item.startPosition.y;

		var icon:HealthIcon = iconArray[i];
		icon.visible = icon.active = true;
		lastVisibles.push(i);
	}
}

function playPreview() {
	game.destroyFreeplayVocals();
	FlxG.sound.music.volume = 0;

	Mods.currentModDirectory = songs[curSelected].folder;
	var poop:String = Highscore.formatSong(songs[curSelected].songName.toLowerCase(), curDifficulty);
	Song.loadFromJson(poop, songs[curSelected].songName.toLowerCase());

	// Load vocals if needed
	if (PlayState.SONG.needsVoices) {
		// Implementation simplified - full vocal loading would be here
		trace('Loading vocals for preview...');
	}

	FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 0.8);
	FlxG.sound.music.pause();
	instPlaying = curSelected;

	Reflect.setField(player, 'playingMusic', true);
	player.curTime = 0;
	player.switchPlayMusic();
	player.pauseOrResume(true);
}

function stopPreview() {
	FlxG.sound.music.stop();
	game.destroyFreeplayVocals();
	FlxG.sound.music.volume = 0;
	instPlaying = -1;

	Reflect.setField(player, 'playingMusic', false);
	player.switchPlayMusic();

	FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
	FlxTween.tween(FlxG.sound.music, {volume: 1}, 1);
}

function enterSong() {
	// Ensure mod directory is set for selected song
	Mods.currentModDirectory = songs[curSelected].folder;
	PlayState.storyWeek = songs[curSelected].week;
	
	game.persistentUpdate = false;
	game.switchToPlayState();
}

function getCurrentSelection() {
	return curSelected;
}

function getCurrentDifficulty() {
	return curDifficulty;
}

function onDestroy() {
	// Stop and clean up preview music if playing
	if (Reflect.field(player, 'playingMusic')) {
		stopPreview();
	}
	
	// Cancel any active tweens
	FlxTween.cancelTweensOf(bg);
	
	// Cancel icon tweens
	for (icon in iconArray) {
		if (icon != null)
			FlxTween.cancelTweensOf(icon);
	}
	
	// Clean up references
	iconArray = null;
	lastVisibles = null;
	
	trace('Freeplay.hx: onDestroy - cleaned up music player, tweens, and references');
}
