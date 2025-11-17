package objects;

import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import backend.Rating;

/**
	* Hit Error Bar - Displays timing accuracy for note hits
	* Similar to osu!'s HitError implementation
	* Performance-focused with object pooling and direct property updates
	* HORIZONTAL layout at bottom of screen
	* 
	* To add:
	* - Average timing indicator (floating average line)
	* - Vertical layout option

 */
class HitErrorBar extends FlxSpriteGroup {
	// Constants - HORIZONTAL
	static inline var BAR_WIDTH:Int = 400;
	static inline var BAR_HEIGHT:Int = 4;
	static inline var JUDGEMENT_LINE_HEIGHT:Int = 14;
	static inline var MAX_JUDGEMENT_LINES:Int = 100;
	static inline var CHEVRON_SIZE:Float = 8;

	static inline var FADE_IN_DURATION:Float = 0.1;
	static inline var FADE_OUT_DURATION:Float = 3.0;
	static inline var QUICK_FADE_OUT_DURATION:Float = 1.0;

	// Color bars for timing windows
	var earlyTimingBars:FlxSpriteGroup;
	var lateTimingBars:FlxSpriteGroup;
	var hitMarkersGroup:FlxSpriteGroup;

	// Timing data
	var maxHitWindow:Float = 180.0;
	var timingAverage:Float = 0.0;
	var hitWindows:Array<{result:String, length:Float, color:FlxColor}> = [];

	// Cached colors for quick lookup
	var sickColor:FlxColor;
	var goodColor:FlxColor;
	var badColor:FlxColor;

	// Pooling for judgement lines
	var hitMarkerPool:Array<JudgementLine> = [];
	var poolIndex:Int = 0;

	// Center marker
	var centerMarker:FlxSprite;

	public function new(?x:Float = 0, ?y:Float = 0) {
		super(x, y);

		initHitWindows();

		var colorBars:FlxSpriteGroup = new FlxSpriteGroup(0, CHEVRON_SIZE);

		earlyTimingBars = new FlxSpriteGroup(0, 0);
		lateTimingBars = new FlxSpriteGroup(0, 0);

		createColorBars();

		colorBars.add(earlyTimingBars);
		colorBars.add(lateTimingBars);

		hitMarkersGroup = new FlxSpriteGroup(0, 0);
		colorBars.add(hitMarkersGroup);

		var lastWindowLen:Int = hitWindows.length - 1;
		centerMarker = new FlxSprite(0, 0);
		centerMarker.makeGraphic(2, 8, FlxColor.WHITE);
		centerMarker.x = 199;
		centerMarker.y = 3;

		colorBars.add(centerMarker);

		var earlyLabel:FlxText = new FlxText(-35, 0, 0, "Early", 10);
		earlyLabel.alignment = CENTER;

		var lateLabel:FlxText = new FlxText(405, 0, 0, "Late", 10);
		lateLabel.alignment = CENTER;

		colorBars.add(earlyLabel);
		colorBars.add(lateLabel);

		add(colorBars);

		var i:Int = MAX_JUDGEMENT_LINES;
		while (--i >= 0)
			hitMarkerPool.push(new JudgementLine());
	}

	inline function initHitWindows():Void {
		var sickWindow:Float = ClientPrefs.data.sickWindow;
		var goodWindow:Float = ClientPrefs.data.goodWindow;
		var badWindow:Float = ClientPrefs.data.badWindow;

		maxHitWindow = badWindow;

		sickColor = FlxColor.CYAN;
		goodColor = FlxColor.LIME;
		badColor = FlxColor.ORANGE;

		hitWindows = [
			{result: "sick", length: sickWindow, color: sickColor},
			{result: "good", length: goodWindow, color: goodColor},
			{result: "bad", length: badWindow, color: badColor}
		];
	}

	function createColorBars():Void {
		var prevLength:Float = 0.0;
		var halfWidth:Float = 200.0;
		var barY:Float = 6.0;
		var windowsLen:Int = hitWindows.length;
		var maxWindow:Float = maxHitWindow;

		var i:Int = 0;
		while (i < windowsLen) {
			var window = hitWindows[i];
			var widthPercent:Float = (window.length / maxWindow) * 0.5;
			var segmentWidth:Float = widthPercent - prevLength;
			var segmentPixels:Int = Std.int(segmentWidth * 400);
			var prevPixels:Float = prevLength * 400;

			var barEarly:FlxSprite = new FlxSprite(halfWidth - prevPixels - segmentWidth * 400, barY);
			barEarly.makeGraphic(segmentPixels, BAR_HEIGHT, window.color);
			earlyTimingBars.add(barEarly);

			var barLate:FlxSprite = new FlxSprite(halfWidth + prevPixels, barY);
			barLate.makeGraphic(segmentPixels, BAR_HEIGHT, window.color);
			lateTimingBars.add(barLate);

			prevLength = widthPercent;
			i++;
		}
	}

	inline function timingOffsetToBarPosition(offset:Float):Float {
		return ((offset / maxHitWindow) + 1) * 0.5;
	}

	/**
	 * Record a note hit with timing offset
	 * @param timeOffset Timing offset in milliseconds (negative = early, positive = late)
	 */
	public function addHit(timeOffset:Float, hitResult:String):Void {
		var maxWindow:Float = maxHitWindow;
		var clampedOffset:Float = FlxMath.bound(timeOffset, -maxWindow, maxWindow);

		timingAverage = timingAverage * 0.9 + clampedOffset * 0.1;
		if (timingAverage < -maxWindow)
			timingAverage = -maxWindow;
		else if (timingAverage > maxWindow)
			timingAverage = maxWindow;

		var barPositionNormalized:Float = ((clampedOffset / maxWindow) + 1) * 0.5;

		var hitMarkerColor:FlxColor = getColorForResult(hitResult);

		// Speed up fade-out if near pool limit (osu! approach)
		if (hitMarkersGroup.length > MAX_JUDGEMENT_LINES) {
			var old = hitMarkersGroup.members[0];
			if (old != null && old.alive) {
				FlxTween.cancelTweensOf(old);
				FlxTween.tween(old, {alpha: 0, "scale.y": 0}, QUICK_FADE_OUT_DURATION, {
					ease: FlxEase.quadIn,
					onComplete: function(_) {
						old.kill();
						hitMarkersGroup.remove(old, true);
					}
				});
			}
		}

		var pool:Array<JudgementLine> = hitMarkerPool;
		var idx:Int = poolIndex;
		var line:JudgementLine = pool[idx];
		poolIndex = (idx + 1) % MAX_JUDGEMENT_LINES;

		FlxTween.cancelTweensOf(line);

		if (line.alpha > 0) {
			line.kill();
			hitMarkersGroup.remove(line, true);
		}

		line.revive();
		line.x = barPositionNormalized * 400 - 1;
		line.y = 0;
		line.color = hitMarkerColor;
		line.alpha = 0;
		line.scale.y = 0;
		hitMarkersGroup.add(line);

		FlxTween.tween(line, {alpha: 0.5, "scale.y": 1}, FADE_IN_DURATION, {
			ease: FlxEase.expoOut,
			onComplete: function(_) {
				FlxTween.tween(line, {alpha: 0, "scale.y": 0}, FADE_OUT_DURATION, {
					ease: FlxEase.quadIn,
					onComplete: function(_) {
						line.kill();
						hitMarkersGroup.remove(line, true);
					}
				});
			}
		});
	}

	inline function getColorForResult(result:String):FlxColor {
		if (result == "sick")
			return sickColor;
		if (result == "good")
			return goodColor;
		if (result == "bad")
			return badColor;
		return FlxColor.WHITE;
	}

	/**
	 * Clear all judgement lines (called on seek/restart)
	 */
	public function clearHitData():Void {
		var members = hitMarkersGroup.members;
		var len:Int = members.length;
		var i:Int = 0;
		while (i < len) {
			var line = members[i];
			if (line != null && line.alive) {
				FlxTween.cancelTweensOf(line);
				line.kill();
			}
			i++;
		}
		hitMarkersGroup.clear();

		timingAverage = 0;
	}

	override function destroy():Void {
		var pool:Array<JudgementLine> = hitMarkerPool;
		if (pool != null) {
			var i:Int = pool.length;
			while (--i >= 0) {
				var line = pool[i];
				if (line != null)
					line.destroy();
			}
		}
		hitMarkerPool = null;
		hitWindows = null;
		super.destroy();
	}
}

/**
 * Poolable judgement line sprite
 * Represents a single note hit on the timing bar
 * HORIZONTAL - thin vertical lines that show timing
 */
class JudgementLine extends FlxSprite {
	static inline var LINE_WIDTH:Float = 2.0;
	static inline var LINE_HEIGHT:Int = 16;

	public function new() {
		super();
		makeGraphic(Std.int(LINE_WIDTH), LINE_HEIGHT, FlxColor.WHITE);
		blend = ADD;
		x = 0;
	}

	public inline function resetLine():Void {
		alpha = 0;
		scale.y = 0;
	}
}
