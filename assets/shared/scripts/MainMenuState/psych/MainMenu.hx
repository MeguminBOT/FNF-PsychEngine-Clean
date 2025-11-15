// Default Psych Engine Main Menu, but softcoded.
// @preset:minimal
import Reflect;
import flixel.effects.FlxFlicker;
import flixel.text.FlxText;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import psychlua.HScript.CustomFlxAxes as FlxAxes;
import backend.ClientPrefs;
import lime.app.Application;

// Script-local state management
var curSelected:Int = 0;
var curColumn:Int = 0; // 0 = center, 1 = left, 2 = right
var allowMouse:Bool = true;
var timeNotMoving:Float = 0;
var selectedSomethin:Bool = false;

// Visual elements - script creates and manages these
var bg:FlxSprite;
var magenta:FlxSprite;
var menuItems:FlxTypedGroup; // FlxTypedGroup<FlxSprite> created via createTypedGroup(FlxSprite)
var leftItem:FlxSprite;
var rightItem:FlxSprite;
var camFollow:FlxObject;

// Menu data
var optionShit:Array<Dynamic> = ['story_mode', 'freeplay', 'mods', 'credits'];
var leftOption:String = 'achievements';
var rightOption:String = 'options';

function onCreate() {
	trace('MainMenu.hx: onCreate called!');

	menuItems = createTypedGroup(FlxSprite);
	game.add(menuItems);

	camFollow = new FlxObject(0, 0, 1, 1);
	camFollow.x = FlxG.width / 2; // Center horizontally
	game.add(camFollow);

	// Create background
	var yScroll:Float = 0.25;
	bg = new FlxSprite(-80).loadGraphic(Paths.image('menuBG'));
	bg.antialiasing = ClientPrefs.data.antialiasing;
	bg.scrollFactor.set(0, yScroll);
	bg.setGraphicSize(Std.int(bg.width * 1.175));
	bg.updateHitbox();
	bg.screenCenter();
	game.insert(0, bg);

	// Create magenta flash
	magenta = new FlxSprite(-80).loadGraphic(Paths.image('menuDesat'));
	magenta.antialiasing = ClientPrefs.data.antialiasing;
	magenta.scrollFactor.set(0, yScroll);
	magenta.setGraphicSize(Std.int(magenta.width * 1.175));
	magenta.updateHitbox();
	magenta.screenCenter();
	magenta.visible = false;
	magenta.color = 0xFFfd719b;
	game.insert(1, magenta);

	// Create menu items
	for (num in 0...optionShit.length) {
		var option = optionShit[num];
		var item = createMenuItem(option, 0, (num * 140) + 90);
		item.y += (4 - optionShit.length) * 70;
		item.screenCenter(FlxAxes.X);
	}

	// Create left/right items
	if (leftOption != null)
		leftItem = createMenuItem(leftOption, 60, 490);
	if (rightOption != null) {
		rightItem = createMenuItem(rightOption, FlxG.width - 60, 490);
		rightItem.x -= rightItem.width;
	}

	// Initial selection - this positions camFollow
	changeItem(0);

	// Snap camera to camFollow position immediately (no lerp from origin)
	FlxG.camera.scroll.set(camFollow.x - FlxG.width / 2, camFollow.y - FlxG.height / 2);

	var len:Int = Reflect.field(menuItems, 'length');
	trace('MainMenu.hx: onCreate finished! menuItems.length = ' + len);
}

function createMenuItem(name:String, x:Float, y:Float):FlxSprite {
	var menuItem = new FlxSprite(x, y);
	menuItem.frames = Paths.getSparrowAtlas('mainmenu/menu_' + name);
	menuItem.animation.addByPrefix('idle', name + ' idle', 24, true);
	menuItem.animation.addByPrefix('selected', name + ' selected', 24, true);
	menuItem.animation.play('idle');
	menuItem.antialiasing = ClientPrefs.data.antialiasing;
	menuItem.scrollFactor.set(); // Keep menu items fixed on screen
	menuItem.updateHitbox();

	Reflect.callMethod(menuItems, Reflect.field(menuItems, 'add'), [menuItem]);
	return menuItem;
}

function onUpdate(elapsed:Float) {
	// Music volume fade
	if (FlxG.sound.music.volume < 0.8)
		FlxG.sound.music.volume = Math.min(FlxG.sound.music.volume + 0.5 * elapsed, 0.8);

	// Mouse visibility handling
	if (allowMouse && ((FlxG.mouse.deltaScreenX != 0 && FlxG.mouse.deltaScreenY != 0) || FlxG.mouse.justPressed)) {
		FlxG.mouse.visible = true;
		timeNotMoving = 0;
	} else {
		timeNotMoving += elapsed;
		if (timeNotMoving > 3)
			FlxG.mouse.visible = false;
	}

	if (selectedSomethin)
		return;

	// Input handling - UP/DOWN only in center column
	if (controls.UI_UP_P)
		changeItem(-1);
	if (controls.UI_DOWN_P)
		changeItem(1);

	// Column switching - match original behavior exactly
	if (curColumn == 0) { // CENTER
		if (controls.UI_LEFT_P && leftOption != null) {
			curColumn = 1; // LEFT
			changeItem(0);
		} else if (controls.UI_RIGHT_P && rightOption != null) {
			curColumn = 2; // RIGHT
			changeItem(0);
		}
	} else if (curColumn == 1) { // LEFT
		if (controls.UI_RIGHT_P) {
			curColumn = 0; // CENTER
			changeItem(0);
		}
	} else if (curColumn == 2) { // RIGHT
		if (controls.UI_LEFT_P) {
			curColumn = 0; // CENTER
			changeItem(0);
		}
	}

	if (controls.ACCEPT)
		selectItem();
}

function selectItem() {
	var option = getCurrentOption();

	// Handle selection visuals
	selectedSomethin = true;
	FlxG.sound.play(Paths.sound('confirmMenu'));

	if (ClientPrefs.data.flashing)
		FlxFlicker.flicker(magenta, 1.1, 0.15, false);

	var item:FlxSprite = getSelectedItem();
	if (item != null) {
		FlxFlicker.flicker(item, 1, 0.06, false, false, function(flick) {
			game.onItemSelected(option);
		});

		// Fade out non-selected items
		var members:Array<Dynamic> = Reflect.field(menuItems, 'members');
		for (i in 0...members.length) {
			var memb:FlxSprite = members[i];
			if (memb == item)
				continue;
			FlxTween.tween(memb, {alpha: 0}, 0.4, {ease: FlxEase.quadOut});
		}
	}
}

function changeItem(change:Int) {
	// Only change vertical selection if we're in center column AND change is not 0
	if (curColumn == 0 && change != 0) {
		curSelected += change;
		if (curSelected < 0)
			curSelected = optionShit.length - 1;
		if (curSelected >= optionShit.length)
			curSelected = 0;
	}

	// Play sound only if actually changing
	if (change != 0)
		FlxG.sound.play(Paths.sound('scrollMenu'));

	// Update animations for ALL center items
	var members:Array<Dynamic> = Reflect.field(menuItems, 'members');
	for (i in 0...members.length) {
		var item:FlxSprite = members[i];
		item.animation.play('idle');
		item.centerOffsets();
	}

	// Get selected item based on current column
	var selectedItem:FlxSprite = getSelectedItem();
	if (selectedItem != null) {
		selectedItem.animation.play('selected');
		selectedItem.centerOffsets();
		// Only update Y position - camera shouldn't follow X
		camFollow.y = selectedItem.getGraphicMidpoint().y;
	}

	// Camera follow
	FlxG.camera.follow(camFollow, null, 0.15);
}

function getSelectedItem():FlxSprite {
	if (curColumn == 1 && leftItem != null)
		return leftItem;
	if (curColumn == 2 && rightItem != null)
		return rightItem;
	var members:Array<Dynamic> = Reflect.field(menuItems, 'members');
	return members[curSelected];
}

function getCurrentOption():String {
	if (curColumn == 1 && leftItem != null)
		return leftOption;
	if (curColumn == 2 && rightItem != null)
		return rightOption;
	return optionShit[curSelected];
}

function onDestroy() {
	// Cancel any active tweens
	FlxTween.cancelTweensOf(bg);
	FlxTween.cancelTweensOf(magenta);
	
	// Cancel tweens on menu items
	var members:Array<Dynamic> = Reflect.field(menuItems, 'members');
	for (i in 0...members.length) {
		var memb:FlxSprite = members[i];
		if (memb != null)
			FlxTween.cancelTweensOf(memb);
	}
	
	// Clean up references
	if (leftItem != null)
		FlxTween.cancelTweensOf(leftItem);
	if (rightItem != null)
		FlxTween.cancelTweensOf(rightItem);
	
	trace('MainMenu.hx: onDestroy - cleaned up tweens and references');
}
