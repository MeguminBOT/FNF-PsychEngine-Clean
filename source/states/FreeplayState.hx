package states;

import backend.ScriptableState;
import backend.WeekData;
import backend.Highscore;
import backend.Song;
import haxe.Json;
import objects.HealthIcon;
import objects.MusicPlayer;
import options.GameplayChangersSubstate;
import substates.ResetScoreSubState;
#if LUA_ALLOWED
import psychlua.*;
#else
import psychlua.LuaUtils;
import psychlua.HScript;
#end

/**
 * Scriptable Freeplay State - Scripts handle all UI and logic
 * Provides helper methods for song selection and playback
 */
class FreeplayState extends ScriptableState {
	// Song data - accessible by scripts
	public var songs:Array<SongMetadata> = [];

	public static var curSelected:Int = 0;
	public static var lastDifficultyName:String = '';

	// Vocals for preview playback
	public static var vocals:FlxSound = null;
	public static var opponentVocals:FlxSound = null;

	// Variant selector
	var variantSelector:FlxText;
	var variantsList:Array<String> = [];
	var currentVariantIndex:Int = 0;

	static var savedVariant:String = 'psych';

	override function create() {
		super.create();

		persistentUpdate = persistentDraw = true;
		FlxG.camera.bgColor = FlxColor.BLACK;

		PlayState.isStoryMode = false;
		WeekData.reloadWeekFiles(false);

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("In the Menus", null);
		#end

		// Check if we have weeks
		if (WeekData.weeksList.length < 1) {
			FlxTransitionableState.skipNextTransIn = true;
			persistentUpdate = false;
			MusicBeatState.switchState(new states.ErrorState("NO WEEKS ADDED FOR FREEPLAY\n\nPress ACCEPT to go to the Week Editor Menu.\nPress BACK to return to Main Menu.",
				function() MusicBeatState.switchState(new states.editors.WeekEditorState()), function() MusicBeatState.switchState(new MainMenuState())));
			return;
		}

		// Build song list from weeks
		for (i in 0...WeekData.weeksList.length) {
			if (weekIsLocked(WeekData.weeksList[i]))
				continue;

			var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			WeekData.setDirectoryFromWeek(leWeek);

			for (song in leWeek.songs) {
				var colors:Array<Int> = song[2];
				if (colors == null || colors.length < 3)
					colors = [146, 113, 253];

				addSong(song[0], i, song[1], FlxColor.fromRGB(colors[0], colors[1], colors[2]));
			}
		}
		WeekData.setDirectoryFromWeek();
		Mods.loadTopMod();

		// Set script folder and detect variants
		scriptFolder = 'FreeplayState';
		variantsList = getScriptVariants();

		// Ensure we have at least one variant
		if (variantsList.length == 0)
			variantsList.push('psych'); // Default fallback

		// Load saved variant or first available
		if (variantsList.contains(savedVariant)) {
			currentVariantIndex = variantsList.indexOf(savedVariant);
			scriptSubfolder = savedVariant;
		} else if (variantsList.length > 0) {
			scriptSubfolder = variantsList[0];
			savedVariant = variantsList[0];
		}

		loadScripts();

		// Call script onCreate
		callOnScripts('onCreate');
		callOnScripts('onCreatePost');

		// Create variant selector UI if multiple variants exist
		if (variantsList.length > 1) {
			variantSelector = new FlxText(FlxG.width - 320, 12, 300, '', 16);
			variantSelector.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, RIGHT, OUTLINE, FlxColor.BLACK);
			variantSelector.scrollFactor.set();
			updateVariantText();
			add(variantSelector);
		}
	}

	function updateVariantText() {
		if (variantSelector != null && variantsList.length > 0) {
			var current = variantsList[currentVariantIndex];
			variantSelector.text = '< ${current} >';
		}
	}

	function switchVariant(direction:Int) {
		if (variantsList.length <= 1)
			return;

		currentVariantIndex += direction;
		if (currentVariantIndex < 0)
			currentVariantIndex = variantsList.length - 1;
		if (currentVariantIndex >= variantsList.length)
			currentVariantIndex = 0;

		var newVariant = variantsList[currentVariantIndex];
		savedVariant = newVariant;

		trace('FreeplayState: Switching to variant: ' + newVariant + ' (index ' + currentVariantIndex + ')');

		FlxG.sound.play(Paths.sound('scrollMenu'));
		updateVariantText();

		// Remove variant selector before reload (will be recreated after)
		if (variantSelector != null) {
			remove(variantSelector);
			variantSelector = null;
		}

		// Reload with new variant
		reloadScriptsWithVariant(newVariant);

		// Recreate variant selector
		if (variantsList.length > 1) {
			variantSelector = new FlxText(FlxG.width - 320, 12, 300, '', 16);
			variantSelector.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, RIGHT, OUTLINE, FlxColor.BLACK);
			variantSelector.scrollFactor.set();
			updateVariantText();
			add(variantSelector);
		}
	}

	override function update(elapsed:Float) {
		if (WeekData.weeksList.length < 1)
			return;

		// Variant selector mouse input
		if (variantSelector != null && FlxG.mouse.overlaps(variantSelector)) {
			if (FlxG.mouse.justPressed)
				switchVariant(1);
			else if (FlxG.mouse.justPressedRight)
				switchVariant(-1);
		}
		// Variant cycling with F1/F2
		if (variantsList.length > 1) {
			if (FlxG.keys.justPressed.F1)
				switchVariant(-1);
			else if (FlxG.keys.justPressed.F2)
				switchVariant(1);
		}

		var ret:Dynamic = callOnScripts('onUpdate', [elapsed]);
		if (ret == LuaUtils.Function_Stop) {
			super.update(elapsed);
			return;
		}

		if (controls.BACK) {
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MusicBeatState.switchState(new MainMenuState());
			return;
		}

		super.update(elapsed);
		callOnScripts('onUpdatePost', [elapsed]);
	}

	override function closeSubState() {
		callOnScripts('onCloseSubState');
		persistentUpdate = true;
		super.closeSubState();
	}

	// Helper methods for scripts
	public function addSong(songName:String, weekNum:Int, songCharacter:String, color:Int) {
		songs.push(new SongMetadata(songName, weekNum, songCharacter, color));
	}

	public function weekIsLocked(name:String):Bool {
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return (!leWeek.startUnlocked
			&& leWeek.weekBefore.length > 0
			&& (!StoryMenuState.weekCompleted.exists(leWeek.weekBefore) || !StoryMenuState.weekCompleted.get(leWeek.weekBefore)));
	}

	public static function destroyFreeplayVocals() {
		if (vocals != null) {
			vocals.stop();
			vocals.destroy();
		}
		vocals = null;

		if (opponentVocals != null) {
			opponentVocals.stop();
			opponentVocals.destroy();
		}
		opponentVocals = null;
	}

	public function getVocalFromCharacter(char:String):String {
		try {
			var path:String = Paths.getPath('characters/$char.json', TEXT);
			#if MODS_ALLOWED
			var character:Dynamic = Json.parse(File.getContent(path));
			#else
			var character:Dynamic = Json.parse(Assets.getText(path));
			#end
			return character.vocals_file;
		} catch (e:Dynamic) {}
		return null;
	}

	public function switchToPlayState() {
		persistentUpdate = false;

		var curDiff = callOnScripts('getCurrentDifficulty');
		if (curDiff == null)
			curDiff = 0;

		var songLowercase:String = Paths.formatToSongPath(songs[curSelected].songName);
		var poop:String = Highscore.formatSong(songLowercase, curDiff);

		try {
			Song.loadFromJson(poop, songLowercase);
			LoadingState.loadAndSwitchState(new PlayState());
		} catch (e:Dynamic) {
			trace('ERROR! $e');
			FlxG.sound.play(Paths.sound('cancelMenu'));
			return;
		}

		FlxG.sound.music.volume = 0;
		FreeplayState.destroyFreeplayVocals();
	}

	override function destroy() {
		super.destroy();
		FreeplayState.destroyFreeplayVocals();
	}

	override function exposeToScripts() {
		super.exposeToScripts();

		#if HSCRIPT_ALLOWED
		for (script in hscriptArray) {
			// State-specific data only
			script.set('songs', songs);
			script.set('curSelected', curSelected);
			script.set('lastDifficultyName', lastDifficultyName);
		}
		#end
	}
}

class SongMetadata {
	public var songName:String = "";
	public var week:Int = 0;
	public var songCharacter:String = "";
	public var color:Int = -7179779;
	public var folder:String = "";
	public var lastDifficulty:String = null;

	public function new(song:String, week:Int, songCharacter:String, color:Int) {
		this.songName = song;
		this.week = week;
		this.songCharacter = songCharacter;
		this.color = color;
		this.folder = Mods.currentModDirectory;
		if (this.folder == null)
			this.folder = '';
	}
}
