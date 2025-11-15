// Minimal Freeplay - Lightweight performance-focused version
// No sprite graphics, text-only UI, no animations
import objects.Alphabet;
import objects.HealthIcon;
import objects.MusicPlayer;
import options.GameplayChangersSubstate;
import substates.ResetScoreSubState;

var curSelected:Int = 0;
var curDifficulty:Int = 0;
var intendedScore:Int = 0;
var intendedRating:Float = 0;

// UI elements - text only
var bg:FlxSprite;
var intendedColor:Int;
var songListText:FlxText;
var scoreText:FlxText;
var diffText:FlxText;
var instructionsText:FlxText;
var player:MusicPlayer;
var instPlaying:Int = -1;

function onCreate() {
	trace('Freeplay.hx (minimal): Creating lightweight freeplay menu');

	// Simple colored background
	bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF1a1a2e);
	game.add(bg);

	// Song list as single text object (performance)
	songListText = new FlxText(50, 100, FlxG.width - 100, '', 20);
	songListText.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, FlxTextAlign.LEFT);
	game.add(songListText);

	// Score display
	scoreText = new FlxText(50, 50, FlxG.width - 100, '', 24);
	scoreText.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, FlxTextAlign.LEFT);
	game.add(scoreText);

	// Difficulty display
	diffText = new FlxText(50, FlxG.height - 80, FlxG.width - 100, '', 20);
	diffText.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, FlxTextAlign.LEFT);
	game.add(diffText);

	// Instructions
	instructionsText = new FlxText(50, FlxG.height - 50, FlxG.width - 100,
		'UP/DOWN: Select | LEFT/RIGHT: Difficulty | ENTER: Play | SPACE: Preview | ESC: Back', 16);
	instructionsText.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.GRAY, FlxTextAlign.LEFT);
	game.add(instructionsText);

	// Music player
	player = new MusicPlayer(game);
	game.add(player);

	// Initialize
	if (curSelected >= songs.length)
		curSelected = 0;

	bg.color = songs[curSelected].color;
	intendedColor = bg.color;

	var lastDiff = Difficulty.defaultList.indexOf(lastDifficultyName);
	curDifficulty = Math.round(Math.max(0, lastDiff));

	updateDisplay();

	trace('Freeplay.hx (minimal): Created with ' + songs.length + ' songs');
}

function onUpdate(elapsed:Float) {
	// Direct color update (no tween for performance)
	var targetColor:Int = songs[curSelected].color;
	if (bg.color != targetColor)
		bg.color = targetColor;

	if (!player.playingMusic) {
		// Song selection
		if (controls.UI_UP_P) {
			changeSelection(-1, true);
		}
		if (controls.UI_DOWN_P) {
			changeSelection(1, true);
		}

		// Page navigation
		if (FlxG.keys.justPressed.HOME) {
			curSelected = 0;
			updateDisplay();
		}
		if (FlxG.keys.justPressed.END) {
			curSelected = songs.length - 1;
			updateDisplay();
		}

		// Difficulty switching
		if (controls.UI_LEFT_P) {
			changeDiff(-1);
		}
		if (controls.UI_RIGHT_P) {
			changeDiff(1);
		}
	}

	// Back button - stop preview if playing
	if (controls.BACK && player.playingMusic) {
		stopPreview();
		return;
	}

	// Gameplay changers
	if (FlxG.keys.justPressed.CONTROL && !player.playingMusic) {
		game.persistentUpdate = false;
		game.openSubState(new GameplayChangersSubstate());
	}
	// Preview
	else if (FlxG.keys.justPressed.SPACE) {
		if (instPlaying != curSelected && !player.playingMusic) {
			playPreview();
		} else if (instPlaying == curSelected && player.playingMusic) {
			player.pauseOrResume(!player.playing);
		}
	}
	// Enter song
	else if (controls.ACCEPT && !player.playingMusic) {
		enterSong();
	}
	// Reset score
	else if (controls.RESET && !player.playingMusic) {
		game.persistentUpdate = false;
		game.openSubState(new ResetScoreSubState(songs[curSelected].songName, curDifficulty, songs[curSelected].songCharacter));
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}
}

function onCloseSubState() {
	updateDisplay();
}

function changeSelection(change:Int, playSound:Bool = true) {
	if (player.playingMusic)
		return;

	curSelected += change;
	if (curSelected < 0)
		curSelected = songs.length - 1;
	if (curSelected >= songs.length)
		curSelected = 0;

	if (playSound)
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

	// Load difficulty
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
	if (player.playingMusic)
		return;

	curDifficulty += change;
	if (curDifficulty < 0)
		curDifficulty = Difficulty.list.length - 1;
	if (curDifficulty >= Difficulty.list.length)
		curDifficulty = 0;

	intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);
	intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty);

	lastDifficultyName = Difficulty.getString(curDifficulty, false);
	updateDisplay();
	updateSongLastDifficulty();
}

function updateSongLastDifficulty() {
	songs[curSelected].lastDifficulty = Difficulty.getString(curDifficulty, false);
}

function updateDisplay() {
	// Build song list text (show 15 songs at a time)
	var listStr:String = '';
	var startIdx = Math.floor(Math.max(0, curSelected - 7));
	var endIdx = Math.floor(Math.min(songs.length, startIdx + 15));

	for (i in startIdx...endIdx) {
		if (i == curSelected)
			listStr += '> ';
		else
			listStr += '  ';
		listStr += songs[i].songName + '\n';
	}
	songListText.text = listStr;

	// Score
	var ratingSplit:Array<String> = Std.string(CoolUtil.floorDecimal(intendedRating * 100, 2)).split('.');
	if (ratingSplit.length < 2)
		ratingSplit.push('');
	while (ratingSplit[1].length < 2)
		ratingSplit[1] += '0';

	scoreText.text = 'SCORE: ' + intendedScore + ' (' + ratingSplit.join('.') + '%)';

	// Difficulty
	var displayDiff:String = Difficulty.getString(curDifficulty);
	if (Difficulty.list.length > 1)
		diffText.text = 'DIFFICULTY: < ' + displayDiff.toUpperCase() + ' >';
	else
		diffText.text = 'DIFFICULTY: ' + displayDiff.toUpperCase();
}

function playPreview() {
	game.destroyFreeplayVocals();
	FlxG.sound.music.volume = 0;

	Mods.currentModDirectory = songs[curSelected].folder;
	var poop:String = Highscore.formatSong(songs[curSelected].songName.toLowerCase(), curDifficulty);
	Song.loadFromJson(poop, songs[curSelected].songName.toLowerCase());

	FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 0.8);
	FlxG.sound.music.pause();
	instPlaying = curSelected;

	player.playingMusic = true;
	player.curTime = 0;
	player.switchPlayMusic();
	player.pauseOrResume(true);
}

function stopPreview() {
	FlxG.sound.music.stop();
	game.destroyFreeplayVocals();
	FlxG.sound.music.volume = 0;
	instPlaying = -1;

	player.playingMusic = false;
	player.switchPlayMusic();

	FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
	FlxTween.tween(FlxG.sound.music, {volume: 1}, 1);
}

function enterSong() {
	game.switchToPlayState(songs[curSelected].songName, curDifficulty);
}

function getCurrentDifficulty() {
	return curDifficulty;
}
