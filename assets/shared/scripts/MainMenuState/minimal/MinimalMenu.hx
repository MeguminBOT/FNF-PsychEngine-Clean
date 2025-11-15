// Minimal MainMenu variant - Simple centered list
// Example of alternative menu script variant
// @preset:minimal
import flixel.text.FlxText;
import flixel.FlxSprite;
import flixel.util.FlxTimer;
import psychlua.HScript.CustomFlxColor as FlxColor;
import psychlua.HScript.CustomFlxTextBorderStyle as FlxTextBorderStyle;
import psychlua.HScript.CustomFlxTextAlign as FlxTextAlign;

var curSelected:Int = 0;
var selectedSomethin:Bool = false;
var menuItems:Array<FlxText> = [];
var options:Array<String> = ['Story Mode', 'Freeplay', 'Mods', 'Credits', 'Options'];
var optionKeys:Array<String> = ['story_mode', 'freeplay', 'mods', 'credits', 'options'];

function onCreate() {
	trace('MinimalMenu.hx: Creating minimal menu variant');

	// Simple black background
	var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
	game.add(bg);

	// Title
	var title = new FlxText(0, 100, FlxG.width, "FNF Psych Engine", 32);
	title.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
	title.scrollFactor.set();
	game.add(title);

	// Create simple text menu items
	for (i in 0...options.length) {
		var txt = new FlxText(0, 250 + (i * 60), FlxG.width, options[i], 24);
		txt.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		txt.scrollFactor.set();
		txt.ID = i;
		game.add(txt);
		menuItems.push(txt);
	}

	changeSelection(0);
}

function changeSelection(change:Int) {
	if (change != 0)
		FlxG.sound.play(Paths.sound('scrollMenu'));

	curSelected += change;
	if (curSelected < 0)
		curSelected = options.length - 1;
	if (curSelected >= options.length)
		curSelected = 0;

	// Update colors
	for (i in 0...menuItems.length) {
		menuItems[i].color = (i == curSelected) ? FlxColor.YELLOW : FlxColor.WHITE;
		menuItems[i].alpha = (i == curSelected) ? 1.0 : 0.6;
	}
}

function onUpdate(elapsed:Float) {
	if (selectedSomethin)
		return;

	if (controls.UI_UP_P)
		changeSelection(-1);
	if (controls.UI_DOWN_P)
		changeSelection(1);

	if (controls.ACCEPT) {
		selectedSomethin = true;
		FlxG.sound.play(Paths.sound('confirmMenu'));

		menuItems[curSelected].color = FlxColor.MAGENTA;

		// Small delay before switching
		new FlxTimer().start(0.3, function(tmr:FlxTimer) {
			game.onItemSelected(optionKeys[curSelected]);
		});
	}
}

function onDestroy() {
	// Clean up arrays
	menuItems = null;
	trace('MinimalMenu.hx: onDestroy - cleaned up');
}
