import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.ActivityMonitor;
import Toybox.Activity;
import Toybox.Math;
import Toybox.Weather;
import Toybox.SensorHistory;
import Toybox.Application;

//
// Christmas Joy - an evergreen wreath around a snow globe.
//
//   - The wreath runs round the rim: leaves, berries, twelve ornaments and a
//     bow at six o'clock. The ornaments light up clockwise from the bow as the
//     chosen goal fills (step goal, Body Battery or battery), or stay lit.
//   - Inside, a snow globe: a cottage with a smoking chimney, pine trees and
//     drifts. Snow is scattered fresh at every redraw (once a minute, once a
//     second while the wrist is raised) and falls heavier when it is snowing
//     outside. After sunset the sky goes to night, stars come out and the
//     cottage windows glow.
//   - Text: a top line (Christmas countdown by default), the date, the time in
//     script, a spot each side of the time and three on the snow. Each of the
//     seven spots shows whatever the settings pick, or nothing.
//
// Everything is drawn with circles, ellipses, polygons, lines and bitmap fonts,
// on a 454x454 base scaled to the panel. preview/index.html draws the same face
// the same way (same coordinates, same random sequence), so the browser preview
// matches the watch.
//
class ChristmasJoyView extends WatchUi.WatchFace {

    // ---------------------------------------------------------------- geometry
    private var mWidth as Number = 454;
    private var mK as Float = 1.0;                // panel px per base px
    private const C = 227;                        // centre on the 454 base
    private const TAU = 6.2831853;
    private const DEG = 0.0174532925;

    private var mIsSleep as Boolean = false;
    private var mBurnIn as Boolean = false;

    // ------------------------------------------------------------------- fonts
    private var mFontTime as Graphics.FontType or Null = null;
    private var mFontLine as Graphics.FontType or Null = null;
    private var mFontDate as Graphics.FontType or Null = null;
    private var mFontData as Graphics.FontType or Null = null;
    private var mFontSmall as Graphics.FontType or Null = null;
    private var mLoadedTimeSize as Number = -1;

    // Vertical middle of each font's ink as a fraction of its line height,
    // printed by tools/gen_fonts.py. Text is centred on a y with these.
    private const MID_TIME    = 0.495;
    private const MID_TIME_LG = 0.500;
    private const MID_LINE    = 0.489;
    private const MID_DATE    = 0.500;
    private const MID_DATA    = 0.518;
    private const MID_SMALL   = 0.521;

    // ---------------------------------------------------------------- settings
    private var mTheme as Number = 0;        // 0 blush & gold, 1 classic, 2 frosted, 3 cozy plaid
    private var mTimeSize as Number = 0;     // 0 normal, 1 large (hides the side spots)
    private var mSky as Number = 0;          // 0 auto (sunset), 1 always day, 2 always night
    private var mShowDate as Boolean = true;
    private var mWreath as Number = 0;       // 0 step goal, 1 Body Battery, 2 battery, 3 always lit

    // What a spot can show. These ids are stored in the settings: never
    // renumber them, only append.
    private const M_NONE      = 0;
    private const M_COUNTDOWN = 1;
    private const M_SAYING    = 2;
    private const M_STEPS     = 3;
    private const M_HR        = 4;
    private const M_CALS      = 5;
    private const M_DIST      = 6;
    private const M_FLOORS    = 7;
    private const M_ACTIVE    = 8;
    private const M_GOAL      = 9;
    private const M_ENERGY    = 10;
    private const M_STRESS    = 11;
    private const M_BREATH    = 12;
    private const M_BATT      = 13;
    private const M_BATTDAYS  = 14;
    private const M_MSGS      = 15;
    private const M_ALARMS    = 16;
    private const M_ALT       = 17;
    private const M_WEATHER   = 18;
    private const M_LAST      = 18;

    // Spots: top line, left of time, right of time, snow left/middle/right.
    private const SLOT_KEYS = ["SlotTop", "SlotLeft", "SlotRight", "SlotSnow1", "SlotSnow2", "SlotSnow3"] as Array<String>;
    private var mSlots as Array<Number> = [M_COUNTDOWN, M_HR, M_WEATHER, M_STEPS, M_BATT, M_MSGS] as Array<Number>;

    private const SAYINGS = ["Merry & Bright", "Let it snow", "Fa la la la la", "Joy to the world", "Believe",
        "Peace on earth", "'Tis the season", "Warm & cozy", "Oh what fun", "Sleigh bells ring", "Holly jolly",
        "Baby, it's cold outside", "Home for the holidays", "Make it merry"] as Array<String>;

    // ----------------------------------------------------------------- palette
    // Sky palette (one for day, one for night), by index:
    private const P_SKY = 0;
    private const P_STRIPE = 1;     // plaid stripe (same as sky when not plaid)
    private const P_CROSS = 2;      // plaid crossing
    private const P_SNOWBACK = 3;
    private const P_SNOWFRONT = 4;
    private const P_FLAKE = 5;
    private const P_TIME = 6;
    private const P_DATE = 7;
    private const P_LINE = 8;
    private const P_DATA = 9;
    private const P_DATASNOW = 10;
    private const P_ICON = 11;
    private const P_STAR = 12;
    private const P_GLASS = 13;
    private const P_WINDOW = 14;

    // Theme colours that do not change with the sky, by index:
    private const T_G0 = 0;         // greens, darkest to lightest: 0..3
    private const T_ORN = 4;        // ornament colours: 4..7
    private const T_BERRY = 8;
    private const T_BOW = 9;
    private const T_BOWDARK = 10;
    private const T_KNOT = 11;
    private const T_ICONSNOW = 12;
    private const T_WALL = 13;
    private const T_TRIM = 14;
    private const T_ROOF = 15;
    private const T_DOOR = 16;
    private const T_PINE0 = 17;
    private const T_PINE1 = 18;
    private const T_TRUNK = 19;
    private const T_PLAID = 20;

    private var mDay as Array<Number> = [] as Array<Number>;
    private var mNight as Array<Number> = [] as Array<Number>;
    private var mT as Array<Number> = [] as Array<Number>;

    // ------------------------------------------------------------- run state
    private var mRng as Number = 1;
    private var mBg as Graphics.BufferedBitmapReference or Null = null;   // see background()
    private var mBgKey as Number = -1;
    private var mSunKey as Number = -1;
    private var mSunrise as Number = 7 * 60;   // minutes after midnight
    private var mSunset as Number = 17 * 60;

    // Weather icon kinds.
    private const WX_SUN = 0;
    private const WX_CLOUD = 1;
    private const WX_SNOW = 2;
    private const WX_RAIN = 3;

    // Icons.
    private const IC_NONE = 0;
    private const IC_HEART = 1;
    private const IC_STEPS = 2;
    private const IC_FLAME = 3;
    private const IC_PIN = 4;
    private const IC_STAIRS = 5;
    private const IC_TIMER = 6;
    private const IC_STAR = 7;
    private const IC_BOLT = 8;
    private const IC_STRESS = 9;
    private const IC_RESP = 10;
    private const IC_BATTERY = 11;
    private const IC_ENVELOPE = 12;
    private const IC_BELL = 13;
    private const IC_MOUNTAIN = 14;
    private const IC_GIFT = 15;
    private const IC_SUN = 16;
    private const IC_CLOUD = 17;
    private const IC_SNOW = 18;
    private const IC_RAIN = 19;

    function initialize() {
        WatchFace.initialize();
        loadSettings();
    }

    // ================================================================ settings

    function loadSettings() as Void {
        try {
            if (Application has :Properties) {
                mTheme = propNum("Theme", mTheme);
                mTimeSize = propNum("TimeSize", mTimeSize);
                mSky = propNum("Sky", mSky);
                mShowDate = propBool("ShowDate", mShowDate);
                mWreath = propNum("WreathLights", mWreath);
                for (var i = 0; i < SLOT_KEYS.size(); i++) {
                    var v = propNum(SLOT_KEYS[i], mSlots[i]);
                    if (v >= M_NONE && v <= M_LAST) { mSlots[i] = v; }
                }
            }
        } catch (e) {
            // keep defaults
        }
        if (mTheme < 0 || mTheme > 3) { mTheme = 0; }
        if (mTimeSize < 0 || mTimeSize > 1) { mTimeSize = 0; }
        if (mSky < 0 || mSky > 2) { mSky = 0; }
        if (mWreath < 0 || mWreath > 3) { mWreath = 0; }
        applyTheme();
        if (mFontLine != null) { applyTimeFont(); }
    }

    private function propNum(id as String, dflt as Number) as Number {
        var v = Application.Properties.getValue(id);
        if (v instanceof Lang.Number) { return v; }
        if (v instanceof Lang.Long) { return (v as Long).toNumber(); }
        if (v instanceof Lang.Float) { return (v as Float).toNumber(); }
        if (v instanceof Lang.Double) { return (v as Double).toNumber(); }
        if (v instanceof Lang.String) {
            var n = (v as String).toNumber();
            if (n != null) { return n; }
        }
        if (v instanceof Lang.Boolean) { return (v as Boolean) ? 1 : 0; }
        return dflt;
    }

    private function propBool(id as String, dflt as Boolean) as Boolean {
        var v = Application.Properties.getValue(id);
        if (v instanceof Lang.Boolean) { return v; }
        if (v instanceof Lang.Number) { return (v as Number) != 0; }
        return dflt;
    }

    // The colours of each theme. The same values as THEMES in preview/index.html.
    private function applyTheme() as Void {
        if (mTheme == 1) {          // Classic
            mDay   = [0xCFE2EE, 0xCFE2EE, 0xCFE2EE, 0xEEF5FA, 0xFFFFFF, 0xFFFFFF, 0xA01E32, 0x2C3E50, 0x2E6B45, 0x2C3E50, 0x2C3E50, 0xC8283C, 0xFFFFFF, 0xE2EDF5, 0xF4F8FB] as Array<Number>;
            mNight = [0x14223F, 0x14223F, 0x14223F, 0xAFC0D8, 0xD7E1EE, 0xFFFFFF, 0xF0C76A, 0xDCE6F0, 0xF3D58E, 0xDCE6F0, 0x1F3352, 0xF06A7A, 0xFFF1C4, 0x22355A, 0xFFD47A] as Array<Number>;
            mT     = [0x173F2A, 0x245C3B, 0x33784C, 0x4E9563, 0xC8283C, 0xD9A93F, 0xF5F1EA, 0x8E1B2C,
                      0xD62839, 0xC8283C, 0x8E1B2C, 0xD9A93F, 0xC8283C, 0xB8323F, 0xFFFFFF, 0x5B3B30, 0x2E6B45,
                      0x245C3B, 0x1B4A30, 0x5B3B30, 0] as Array<Number>;
        } else if (mTheme == 2) {   // Frosted
            mDay   = [0xD3E4F1, 0xD3E4F1, 0xD3E4F1, 0xF0F6FA, 0xFFFFFF, 0xFFFFFF, 0x2D5278, 0x3D5468, 0x4F769C, 0x3D5468, 0x3D5468, 0x4F86B8, 0xFFFFFF, 0xE6F1F8, 0xF4F8FB] as Array<Number>;
            mNight = [0x15233D, 0x15233D, 0x15233D, 0xA9BCD3, 0xD3DEEA, 0xFFFFFF, 0xDCEAF7, 0xBFD2E4, 0xA9D3EE, 0xBFD2E4, 0x22374F, 0x8CC8E8, 0xE9F4FF, 0x223556, 0xFFE3A3] as Array<Number>;
            mT     = [0x3E5A63, 0x56767F, 0x7495A0, 0xA6C2CA, 0xC9D3DD, 0x8CC8E8, 0xFFFFFF, 0xB9B0E3,
                      0x9FC6E6, 0xA9C3DC, 0x7593B2, 0xE4ECF3, 0x4F86B8, 0x9DB2C6, 0xFFFFFF, 0x5D7087, 0x4F86B8,
                      0x56767F, 0x3E5A63, 0x5D5A66, 0] as Array<Number>;
        } else if (mTheme == 3) {   // Cozy Plaid
            mDay   = [0xE7D2C0, 0xDDBFA8, 0xD0AF95, 0xFBF6EE, 0xFFFFFF, 0xFFFFFF, 0x8E2328, 0x5B3A2E, 0x2F6B44, 0x5B3A2E, 0x5B3A2E, 0xB3343A, 0xFFFFFF, 0xEFE2D6, 0xF6EFE6] as Array<Number>;
            mNight = [0x3A1F1F, 0x472727, 0x552E2E, 0xCDBFB8, 0xE9E0DA, 0xFFFFFF, 0xF2D7A6, 0xEBDAD0, 0xF2D7A6, 0xEBDAD0, 0x4A2A24, 0xE8787D, 0xFCE9C8, 0x4C2C2C, 0xFFD47A] as Array<Number>;
            mT     = [0x1F4A31, 0x2C6141, 0x3D7A52, 0x5A9468, 0xB3343A, 0xF2E6D4, 0xD9A93F, 0x2F6B44,
                      0xC23A40, 0xB3343A, 0x7E2227, 0xF2E6D4, 0xB3343A, 0x8B5E3C, 0xF2E6D4, 0x4E342A, 0xB3343A,
                      0x2C6141, 0x1F4A31, 0x4E342A, 1] as Array<Number>;
        } else {                    // Blush & Gold
            mDay   = [0xF3CBD3, 0xF3CBD3, 0xF3CBD3, 0xFBEFF2, 0xFFFFFF, 0xFFFFFF, 0x8E3553, 0x7C4A5A, 0x9E6A2C, 0x7C4A5A, 0x7C4A5A, 0xB5546E, 0xFFFFFF, 0xF9E0E6, 0xD9E6EE] as Array<Number>;
            mNight = [0x2C2142, 0x2C2142, 0x2C2142, 0xB9ADCB, 0xDCD3E6, 0xFFFFFF, 0xEDC77F, 0xE8D5DE, 0xF2D9A6, 0xE8D5DE, 0x4E3A66, 0xF0A3B6, 0xF6E7C1, 0x3E3258, 0xFFD47A] as Array<Number>;
            mT     = [0x45604D, 0x5F7F68, 0x7E9C83, 0xA3BDA6, 0xD8AE5E, 0xE58FA5, 0xFFF3E3, 0xC98A9B,
                      0xB5546E, 0xD9778F, 0xAE566F, 0xD8AE5E, 0xB5546E, 0xF6E6E0, 0xFFFFFF, 0x9C6B7A, 0xB5546E,
                      0x5F7F68, 0x4E6E58, 0x7A5A4A, 0] as Array<Number>;
        }
    }

    // Only the time font the setting asks for stays loaded.
    private function applyTimeFont() as Void {
        if (mLoadedTimeSize == mTimeSize && mFontTime != null) { return; }
        mFontTime = null;
        mFontTime = WatchUi.loadResource(mTimeSize == 1 ? Rez.Fonts.TimeFontLg : Rez.Fonts.TimeFont) as Graphics.FontType;
        mLoadedTimeSize = mTimeSize;
    }

    // =============================================================== lifecycle

    function onLayout(dc as Dc) as Void {
        mWidth = dc.getWidth();
        mK = mWidth.toFloat() / 454.0;
        var settings = System.getDeviceSettings();
        mBurnIn = (settings has :requiresBurnInProtection) && settings.requiresBurnInProtection;
        mFontLine = WatchUi.loadResource(Rez.Fonts.LineFont) as Graphics.FontType;
        mFontDate = WatchUi.loadResource(Rez.Fonts.DateFont) as Graphics.FontType;
        mFontData = WatchUi.loadResource(Rez.Fonts.DataFont) as Graphics.FontType;
        mFontSmall = WatchUi.loadResource(Rez.Fonts.SmallFont) as Graphics.FontType;
        applyTimeFont();
    }

    function onShow() as Void {
    }

    function onHide() as Void {
    }

    function onExitSleep() as Void {
        mIsSleep = false;
        WatchUi.requestUpdate();
    }

    function onEnterSleep() as Void {
        mIsSleep = true;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
        var clock = System.getClockTime();
        if (mIsSleep && mBurnIn) {
            drawAlwaysOn(dc, clock);
            return;
        }

        var today = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var night = isNight(clock, today);
        var p = night ? mNight : mDay;
        var wx = getWeather();

        // Snow is scattered fresh each minute, and each second while awake.
        var epochMin = Time.now().value() / 60;
        var seed = epochMin * 100 + (mIsSleep ? 0 : clock.sec);

        var timeStr = timeString(clock);
        var large = (mTimeSize == 1);
        var side = !large && (mSlots[1] != M_NONE || mSlots[2] != M_NONE);
        var boxes = layoutBoxes(dc, timeStr, large, side);

        var bg = background(p, night);
        if (bg != null) {
            dc.drawBitmap(0, 0, bg);
        } else {
            drawStatic(dc, p, night);
        }
        drawOrnaments(dc, p);
        drawSnow(dc, p, boxes, seed, wx != null && (wx[1] as Number) == WX_SNOW);
        drawText(dc, p, today, timeStr, large, side, wx);
    }

    // ================================================================ helpers

    // Base (454) coordinate -> panel pixel.
    private function px(v as Numeric) as Number {
        var f = v * mK;
        return (f < 0) ? (f - 0.5).toNumber() : (f + 0.5).toNumber();
    }

    private function pr(v as Numeric) as Number {
        var r = px(v);
        return r < 1 ? 1 : r;
    }

    // The same pseudo-random sequence as rng() in the preview.
    private function seedRng(s as Number) as Void {
        mRng = s & 0x7FFFFFFF;
    }

    private function rnd() as Float {
        mRng = (mRng * 1103515245 + 12345) & 0x7FFFFFFF;
        return ((mRng >> 16) & 0x7FFF).toFloat() / 32768.0;
    }

    private function mix(a as Number, b as Number, t as Float) as Number {
        var ar = (a >> 16) & 0xFF;
        var ag = (a >> 8) & 0xFF;
        var ab = a & 0xFF;
        var br = (b >> 16) & 0xFF;
        var bg = (b >> 8) & 0xFF;
        var bb = b & 0xFF;
        var r = (ar + (br - ar) * t + 0.5).toNumber();
        var g = (ag + (bg - ag) * t + 0.5).toNumber();
        var bl = (ab + (bb - ab) * t + 0.5).toNumber();
        return (r << 16) | (g << 8) | bl;
    }

    private function fc(dc as Dc, x as Numeric, y as Numeric, r as Numeric, c as Number) as Void {
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(px(x), px(y), pr(r));
    }

    private function fe(dc as Dc, x as Numeric, y as Numeric, rx as Numeric, ry as Numeric, c as Number) as Void {
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.fillEllipse(px(x), px(y), pr(rx), pr(ry));
    }

    private function fr(dc as Dc, x as Numeric, y as Numeric, w as Numeric, h as Numeric, c as Number) as Void {
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        var x0 = px(x);
        var y0 = px(y);
        dc.fillRectangle(x0, y0, px(x + w) - x0, px(y + h) - y0);
    }

    // Filled polygon from a flat list of base coordinates [x0, y0, x1, y1, ...].
    private function fp(dc as Dc, flat as Array<Numeric>, c as Number) as Void {
        var n = flat.size() / 2;
        var pts = new [n];
        for (var i = 0; i < n; i++) {
            pts[i] = [px(flat[i * 2]), px(flat[i * 2 + 1])];
        }
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(pts as Array<[Numeric, Numeric]>);
    }

    private function ln(dc as Dc, x1 as Numeric, y1 as Numeric, x2 as Numeric, y2 as Numeric, c as Number, w as Numeric) as Void {
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(pr(w));
        dc.drawLine(px(x1), px(y1), px(x2), px(y2));
    }

    // Open polyline through a flat list of base coordinates.
    private function pl(dc as Dc, flat as Array<Numeric>, c as Number, w as Numeric) as Void {
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(pr(w));
        var n = flat.size() / 2;
        for (var i = 1; i < n; i++) {
            dc.drawLine(px(flat[i * 2 - 2]), px(flat[i * 2 - 1]), px(flat[i * 2]), px(flat[i * 2 + 1]));
        }
    }

    private function ring(dc as Dc, x as Numeric, y as Numeric, r as Numeric, c as Number, w as Numeric) as Void {
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(pr(w));
        dc.drawCircle(px(x), px(y), pr(r));
    }

    // Width of text in base px.
    private function textW(dc as Dc, text as String, font as Graphics.FontType or Null) as Float {
        if (font == null) { return 0.0; }
        return dc.getTextWidthInPixels(text, font).toFloat() / mK;
    }

    // Draw text with its ink centred on base y = yMid.
    private function textMid(dc as Dc, text as String, x as Numeric, yMid as Numeric,
                             font as Graphics.FontType or Null, mid as Float, color as Number,
                             justify as Graphics.TextJustification) as Void {
        if (font == null) { return; }
        var y = px(yMid) - (dc.getFontHeight(font) * mid + 0.5).toNumber();
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(px(x), y, font, text, justify);
    }

    private function twinkle(dc as Dc, x as Numeric, y as Numeric, s as Numeric, c as Number) as Void {
        var k = s * 0.28;
        fp(dc, [x, y - s, x + k, y - k, x + s, y, x + k, y + k, x, y + s, x - k, y + k, x - s, y, x - k, y - k] as Array<Numeric>, c);
    }

    private function timeString(clock as System.ClockTime) as String {
        var hour = clock.hour;
        if (!System.getDeviceSettings().is24Hour) {
            hour = hour % 12;
            if (hour == 0) { hour = 12; }
            return hour.toString() + ":" + clock.min.format("%02d");
        }
        return hour.format("%02d") + ":" + clock.min.format("%02d");
    }

    // ============================================================ the sky

    // Night is after sunset and before sunrise (from the watch's weather
    // location when it has one, otherwise 7 am to 5 pm), unless the Sky
    // setting pins it to day or night.
    private function isNight(clock as System.ClockTime, today as Gregorian.Info) as Boolean {
        if (mSky == 1) { return false; }
        if (mSky == 2) { return true; }
        updateSunTimes(clock, today);
        var m = clock.hour * 60 + clock.min;
        return m < mSunrise || m >= mSunset;
    }

    private function updateSunTimes(clock as System.ClockTime, today as Gregorian.Info) as Void {
        var key = (today.day as Number) * 100 + clock.hour;
        if (key == mSunKey) { return; }
        mSunKey = key;
        try {
            if ((Toybox has :Weather) && (Weather has :getSunrise) && (Weather has :getSunset)) {
                var cc = Weather.getCurrentConditions();
                var loc = (cc != null) ? cc.observationLocationPosition : null;
                if (loc != null) {
                    var now = Time.now();
                    var sr = Weather.getSunrise(loc, now);
                    var ss = Weather.getSunset(loc, now);
                    if (sr != null && ss != null) {
                        var a = Gregorian.info(sr, Time.FORMAT_SHORT);
                        var b = Gregorian.info(ss, Time.FORMAT_SHORT);
                        mSunrise = (a.hour as Number) * 60 + (a.min as Number);
                        mSunset = (b.hour as Number) * 60 + (b.min as Number);
                    }
                }
            }
        } catch (e) {
            // keep the last (or default) times
        }
    }

    private function drawSky(dc as Dc, p as Array<Number>, night as Boolean) as Void {
        dc.setColor(p[P_SKY], p[P_SKY]);
        dc.clear();
        if (mT[T_PLAID] == 1) {
            for (var x = -6; x < 454; x += 58) { fr(dc, x, 0, 24, 454, p[P_STRIPE]); }
            for (var y = -6; y < 454; y += 58) { fr(dc, 0, y, 454, 24, p[P_STRIPE]); }
            for (var x = -6; x < 454; x += 58) {
                for (var y = -6; y < 454; y += 58) { fr(dc, x, y, 24, 24, p[P_CROSS]); }
            }
        }
        if (night) {
            seedRng(99);
            for (var i = 0; i < 34; i++) {
                var a = rnd() * TAU;
                var d = Math.sqrt(rnd()) * 186;
                var x = C + Math.cos(a) * d;
                var y = C + Math.sin(a) * d;
                if (y > 280) { continue; }
                fc(dc, x, y, 0.8 + rnd() * 0.9, p[P_STAR]);
            }
            twinkle(dc, 132, 140, 6, p[P_STAR]);
            twinkle(dc, 330, 112, 5, p[P_STAR]);
            twinkle(dc, 176, 252, 4.5, p[P_STAR]);
            twinkle(dc, 300, 240, 5.5, p[P_STAR]);
        }
    }

    // ============================================================ the scene

    private function pine(dc as Dc, x as Numeric, base as Numeric, h as Numeric, p as Array<Number>) as Void {
        var w = h * 0.62;
        var trunkH = h * 0.12;
        fr(dc, x - h * 0.05, base - trunkH, h * 0.1, trunkH + 2, mT[T_TRUNK]);
        for (var i = 0; i < 3; i++) {
            var top = base - trunkH - h * (0.38 + i * 0.3);
            var bot = base - trunkH - h * (i * 0.27);
            var ww = w * (1 - i * 0.24) / 2;
            var dh = bot - top;
            fp(dc, [x, top, x + ww, bot, x - ww, bot] as Array<Numeric>, (i % 2 == 1) ? mT[T_PINE1] : mT[T_PINE0]);
            fp(dc, [x, top, x + ww * 0.38, top + dh * 0.38, x + ww * 0.1, top + dh * 0.32,
                    x - ww * 0.14, top + dh * 0.42, x - ww * 0.38, top + dh * 0.38] as Array<Numeric>, p[P_SNOWFRONT]);
        }
    }

    private function drawScene(dc as Dc, p as Array<Number>, night as Boolean) as Void {
        // back hills
        fc(dc, 120, 560, 270, p[P_SNOWBACK]);
        fc(dc, 380, 590, 290, mix(p[P_SNOWBACK], p[P_SNOWFRONT], 0.35));
        pine(dc, 100, 318, 80, p);
        pine(dc, 356, 324, 66, p);
        pine(dc, 394, 320, 40, p);
        pine(dc, 66, 330, 36, p);

        // the cottage
        fr(dc, 243, 244, 10, 20, mT[T_ROOF]);                       // chimney
        fr(dc, 241, 240, 14, 6, p[P_SNOWFRONT]);                    // snow on it
        fr(dc, 197, 270, 60, 42, mT[T_WALL]);
        fp(dc, [227, 242, 189, 276, 265, 276] as Array<Numeric>, mT[T_ROOF]);
        fp(dc, [227, 234, 182, 273, 189, 280, 227, 246, 265, 280, 272, 273] as Array<Numeric>, p[P_SNOWFRONT]);
        var wins = [203, 239] as Array<Number>;
        for (var i = 0; i < 2; i++) {
            var wx = wins[i];
            if (night) { fr(dc, wx - 3, 279, 18, 18, mix(mT[T_WALL], p[P_WINDOW], 0.45)); }
            fr(dc, wx, 282, 12, 12, p[P_WINDOW]);
            ln(dc, wx + 6, 282, wx + 6, 294, mT[T_TRIM], 1.6);
            ln(dc, wx, 288, wx + 12, 288, mT[T_TRIM], 1.6);
        }
        fr(dc, 221, 292, 12, 20, mT[T_DOOR]);
        fc(dc, 230, 303, 1.3, p[P_SNOWFRONT]);
        fe(dc, 227, 314, 50, 8, p[P_SNOWBACK]);

        // chimney smoke
        var smoke = mix(p[P_SKY], 0xFFFFFF, 0.5);
        fc(dc, 250, 234, 2.8, smoke);
        fc(dc, 254, 227, 3.4, smoke);
        fc(dc, 251, 219, 4, smoke);

        // front drift
        fe(dc, 227, 420, 262, 88, p[P_SNOWFRONT]);
        fe(dc, 110, 336, 28, 6, p[P_SNOWFRONT]);
        fe(dc, 352, 340, 34, 7, p[P_SNOWFRONT]);
    }

    // Where the text goes, as boxes the snow keeps out of: [x1, y1, x2, y2, ...].
    private function layoutBoxes(dc as Dc, timeStr as String, large as Boolean, side as Boolean) as Array<Numeric> {
        var b = [] as Array<Numeric>;
        var tw = textW(dc, timeStr, mFontTime);
        var th = (large ? 124 : 90) * 0.72;
        b.addAll([C - tw / 2 - 8, 172 - th / 2 - 8, C + tw / 2 + 8, 172 + th / 2 + 10] as Array<Numeric>);
        if (mSlots[0] != M_NONE) { b.addAll([92, 64, 362, 102] as Array<Numeric>); }
        if (mShowDate) { b.addAll([108, 104, 346, 128] as Array<Numeric>); }
        if (side) {
            if (mSlots[1] != M_NONE) { b.addAll([42, 140, 106, 206] as Array<Numeric>); }
            if (mSlots[2] != M_NONE) { b.addAll([348, 140, 412, 206] as Array<Numeric>); }
        }
        if (mSlots[3] != M_NONE || mSlots[4] != M_NONE || mSlots[5] != M_NONE) { b.addAll([96, 350, 358, 382] as Array<Numeric>); }
        return b;
    }

    private function drawSnow(dc as Dc, p as Array<Number>, boxes as Array<Numeric>, seed as Number, snowing as Boolean) as Void {
        seedRng(seed * 7919 + 13);
        var n = snowing ? 78 : 34;
        var nb = boxes.size() / 4;
        var placed = 0;
        var tries = 0;
        while (placed < n && tries < n * 12) {
            tries++;
            var a = rnd() * TAU;
            var d = Math.sqrt(rnd()) * 190;
            var x = C + Math.cos(a) * d;
            var y = C + Math.sin(a) * d;
            var hit = false;
            for (var i = 0; i < nb; i++) {
                if (x > boxes[i * 4] && x < boxes[i * 4 + 2] && y > boxes[i * 4 + 1] && y < boxes[i * 4 + 3]) {
                    hit = true;
                    break;
                }
            }
            if (hit) { continue; }
            placed++;
            if (rnd() < 0.16) {
                var s = 3.5 + rnd() * 2.5;
                for (var k = 0; k < 3; k++) {
                    var t = k * Math.PI / 3;
                    var cx = Math.cos(t) * s;
                    var cy = Math.sin(t) * s;
                    ln(dc, x - cx, y - cy, x + cx, y + cy, p[P_FLAKE], 1.3);
                }
            } else {
                fc(dc, x, y, 1.2 + rnd() * (snowing ? 1.8 : 1.3), p[P_FLAKE]);
            }
        }
    }

    // A glint on the glass of the globe, upper left.
    private function drawGlass(dc as Dc, p as Array<Number>) as Void {
        dc.setColor(p[P_GLASS], Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(pr(5));
        dc.drawArc(px(C), px(C), px(186), Graphics.ARC_CLOCKWISE, 154, 134);
        dc.setPenWidth(pr(3));
        dc.drawArc(px(C), px(C), px(186), Graphics.ARC_CLOCKWISE, 129, 124);
    }

    // ============================================================ the wreath

    private function wreathProgress() as Float {
        var v = null as Number or Null;
        if (mWreath == 0) { v = getStepGoalPct(); }
        else if (mWreath == 1) { v = getBodyBattery(); }
        else if (mWreath == 2) { v = getBattery(); }
        if (v == null) { return 1.0; }
        var f = (v as Number).toFloat() / 100.0;
        return f > 1.0 ? 1.0 : (f < 0.0 ? 0.0 : f);
    }

    // The evergreen part of the wreath: leaves, needles, berries and the bow.
    // It never changes within a theme, so it goes into the cached background.
    //
    // This is the heaviest drawing in the face (280 leaves), so the leaf and
    // needle loops work in panel pixels directly instead of through fp()/ln():
    // the watch has a per-redraw instruction budget (the watchdog).
    private function drawWreathBase(dc as Dc) as Void {
        ring(dc, C, C, 213, mT[T_G0], 36);

        var k = mK;
        var half = Math.PI / 2;
        seedRng(7);
        for (var i = 0; i < 280; i++) {
            var a = rnd() * TAU;
            var rad = 195 + rnd() * 33;
            var cx = (C + Math.cos(a) * rad) * k;
            var cy = (C + Math.sin(a) * rad) * k;
            var dir = a + half + (rnd() - 0.5) * 1.5;
            var l = (13 + rnd() * 7) * 0.5 * k;
            var w = (4.5 + rnd() * 2.2) * 0.5 * k;
            var ux = Math.cos(dir);
            var uy = Math.sin(dir);
            dc.setColor(mT[T_G0 + 1 + (rnd() * 3).toNumber()], Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[cx + ux * l, cy + uy * l], [cx - uy * w, cy + ux * w],
                            [cx - ux * l, cy - uy * l], [cx + uy * w, cy - ux * w]] as Array<[Numeric, Numeric]>);
        }
        dc.setColor(mT[T_G0 + 3], Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(pr(1.6));
        for (var i = 0; i < 90; i++) {
            var a = rnd() * TAU;
            var rad = 197 + rnd() * 28;
            var cx = (C + Math.cos(a) * rad) * k;
            var cy = (C + Math.sin(a) * rad) * k;
            var dir = a + half + (rnd() - 0.5) * 1.2;
            var dx = Math.cos(dir) * 4 * k;
            var dy = Math.sin(dir) * 4 * k;
            dc.drawLine(cx - dx, cy - dy, cx + dx, cy + dy);
        }

        // berries, in threes
        var berryHi = mix(mT[T_BERRY], 0xFFFFFF, 0.6);
        var bdx = [-3, 3, 0] as Array<Numeric>;
        var bdy = [-1, -2, 3.5] as Array<Numeric>;
        for (var i = 0; i < 16; i++) {
            var a = (i / 16.0) * TAU + 0.21;
            var deg = a / DEG;
            if (deg >= 360) { deg -= 360; }
            var off = deg - 90;
            if (off < 0) { off = -off; }
            if (off < 26) { continue; }     // the bow sits there
            var rad = 204 + (i % 3) * 6;
            var cx = C + Math.cos(a) * rad;
            var cy = C + Math.sin(a) * rad;
            for (var j = 0; j < 3; j++) {
                fc(dc, cx + bdx[j], cy + bdy[j], 3.2, mT[T_BERRY]);
                fc(dc, cx + bdx[j] - 1, cy + bdy[j] - 1, 1, berryHi);
            }
        }

        // the bow at six o'clock
        var bx = 227;
        var by = 422;
        fp(dc, [bx - 5, by + 3, bx - 23, by + 31, bx - 14, by + 27, bx - 9, by + 35, bx + 1, by + 6] as Array<Numeric>, mT[T_BOWDARK]);
        fp(dc, [bx + 5, by + 3, bx + 23, by + 31, bx + 14, by + 27, bx + 9, by + 35, bx - 1, by + 6] as Array<Numeric>, mT[T_BOWDARK]);
        fp(dc, [bx - 4, by, bx - 30, by - 17, bx - 39, by - 6, bx - 34, by + 9, bx - 4, by + 4] as Array<Numeric>, mT[T_BOW]);
        fp(dc, [bx + 4, by, bx + 30, by - 17, bx + 39, by - 6, bx + 34, by + 9, bx + 4, by + 4] as Array<Numeric>, mT[T_BOW]);
        fp(dc, [bx - 6, by + 1, bx - 24, by - 9, bx - 27, by + 3] as Array<Numeric>, mT[T_BOWDARK]);
        fp(dc, [bx + 6, by + 1, bx + 24, by - 9, bx + 27, by + 3] as Array<Numeric>, mT[T_BOWDARK]);
        dc.setColor(mT[T_KNOT], Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(px(bx - 6.5), px(by - 7), pr(13), pr(14), pr(4));
    }

    // The twelve ornaments, drawn every redraw because they track progress:
    // they light up clockwise from the bow as the goal fills.
    private function drawOrnaments(dc as Dc, p as Array<Number>) as Void {
        var count = 12;
        var lit = (mWreath == 3) ? count : (wreathProgress() * count + 0.5).toNumber();
        var cap = mix(mT[T_KNOT], 0xFFFFFF, 0.15);
        for (var i = 0; i < count; i++) {
            var a = (112 + i * (316.0 / (count - 1))) * DEG;
            var ux = Math.cos(a);
            var uy = Math.sin(a);
            var x = C + ux * 211;
            var y = C + uy * 211;
            var col = mT[T_ORN + (i % 4)];
            var rr = 9.5;
            var ox = x + ux * (rr - 1);
            var oy = y + uy * (rr - 1);
            var tx = -uy * 3;
            var ty = ux * 3;
            fp(dc, [ox + tx, oy + ty, ox + tx + ux * 5, oy + ty + uy * 5,
                    ox - tx + ux * 5, oy - ty + uy * 5, ox - tx, oy - ty] as Array<Numeric>, cap);
            if (i < lit) {
                fc(dc, x, y, rr, col);
                fc(dc, x - 3, y - 3.2, 2.6, mix(col, 0xFFFFFF, 0.75));
                if (i == lit - 1 && lit < count) { twinkle(dc, x + 10, y - 11, 6, p[P_STAR]); }
            } else {
                fc(dc, x, y, rr, mix(col, mT[T_G0], 0.4));
            }
        }
    }

    // ===================================================== cached background

    // Sky, scene, glass and the evergreen wreath, drawn once into an offscreen
    // bitmap and reused until the theme or day/night changes. Returns null when
    // the watch can't spare the bitmap; the caller then draws it all directly.
    private function background(p as Array<Number>, night as Boolean) as Graphics.BufferedBitmap or Null {
        var key = mTheme * 2 + (night ? 1 : 0);
        var ref = mBg;
        if (ref != null && mBgKey == key) {
            var b = ref.get();
            if (b != null) { return b as Graphics.BufferedBitmap; }
        }
        mBg = null;
        if (!(Graphics has :createBufferedBitmap)) { return null; }
        try {
            var nref = Graphics.createBufferedBitmap({:width => mWidth, :height => mWidth});
            var bmp = nref.get();
            if (bmp == null) { return null; }
            var bdc = (bmp as Graphics.BufferedBitmap).getDc();
            if (bdc has :setAntiAlias) { bdc.setAntiAlias(true); }
            drawStatic(bdc, p, night);
            mBg = nref;
            mBgKey = key;
            return bmp as Graphics.BufferedBitmap;
        } catch (e) {
            return null;
        }
    }

    private function drawStatic(dc as Dc, p as Array<Number>, night as Boolean) as Void {
        drawSky(dc, p, night);
        drawScene(dc, p, night);
        drawGlass(dc, p);
        drawWreathBase(dc);
        dc.setPenWidth(1);
    }

    // ============================================================== the text

    private function drawText(dc as Dc, p as Array<Number>, today as Gregorian.Info, timeStr as String,
                              large as Boolean, side as Boolean, wx as Array or Null) as Void {
        // top line, in script; anything too long for the arc falls back to print
        if (mSlots[0] != M_NONE) {
            var t = lineText(mSlots[0], today, wx);
            if (t != null) {
                if (textW(dc, t, mFontLine) <= 252) {
                    textMid(dc, t, C, 84, mFontLine, MID_LINE, p[P_LINE], Graphics.TEXT_JUSTIFY_CENTER);
                } else {
                    textMid(dc, t, C, 84, mFontData, MID_DATA, p[P_LINE], Graphics.TEXT_JUSTIFY_CENTER);
                }
            }
        }

        if (mShowDate) {
            var days = ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"] as Array<String>;
            var months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"] as Array<String>;
            var dot = "  " + (0xB7).toChar().toString() + "  ";
            var d = days[(today.day_of_week as Number) - 1] + dot + months[(today.month as Number) - 1] + " " + (today.day as Number).toString();
            textMid(dc, d, C, 117, mFontDate, MID_DATE, p[P_DATE], Graphics.TEXT_JUSTIFY_CENTER);
        }

        textMid(dc, timeStr, C, 172, mFontTime, large ? MID_TIME_LG : MID_TIME, p[P_TIME], Graphics.TEXT_JUSTIFY_CENTER);

        if (side) {
            var xs = [74, 380] as Array<Number>;
            for (var i = 0; i < 2; i++) {
                var id = mSlots[1 + i];
                var v = (id == M_SAYING) ? null : smallValue(id, today, wx);
                if (v == null) { continue; }
                icon(dc, metricIcon(id, wx), xs[i], 157, 24, p[P_ICON], p[P_SKY]);
                if (textW(dc, v, mFontData) <= 62) {
                    textMid(dc, v, xs[i], 190, mFontData, MID_DATA, p[P_DATA], Graphics.TEXT_JUSTIFY_CENTER);
                } else {
                    textMid(dc, v, xs[i], 190, mFontSmall, MID_SMALL, p[P_DATA], Graphics.TEXT_JUSTIFY_CENTER);
                }
            }
        }

        // the three spots on the snow drift: icon + value, centred as a group
        var bxs = [141, 227, 313] as Array<Number>;
        for (var i = 0; i < 3; i++) {
            var id = mSlots[3 + i];
            var v = (id == M_SAYING) ? null : smallValue(id, today, wx);
            if (v == null) { continue; }
            var total = 18 + 5 + textW(dc, v, mFontSmall);
            var left = bxs[i] - total / 2;
            icon(dc, metricIcon(id, wx), left + 9, 366, 18, mT[T_ICONSNOW], p[P_SNOWFRONT]);
            textMid(dc, v, left + 23, 366, mFontSmall, MID_SMALL, p[P_DATASNOW], Graphics.TEXT_JUSTIFY_LEFT);
        }
        dc.setPenWidth(1);
    }

    // ========================================================== always-on

    // Burn-in-safe sleep page: black, just the time and a small star in dim
    // gold, nudged a little each minute.
    private function drawAlwaysOn(dc as Dc, clock as System.ClockTime) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var m = clock.min;
        var dx = ((m % 5) - 2) * 3;
        var dy = (((m / 5) % 5) - 2) * 3;
        var col = mix(mNight[P_TIME], 0x000000, 0.45);
        twinkle(dc, C + dx, 118 + dy, 7, col);
        textMid(dc, timeString(clock), C + dx, 190 + dy, mFontTime, mTimeSize == 1 ? MID_TIME_LG : MID_TIME,
                col, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ========================================================== the season

    private function dayOfYear(y as Number, m as Number, d as Number) as Number {
        var cum = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334] as Array<Number>;
        var n = cum[m - 1] + d;
        var leap = (y % 4 == 0 && y % 100 != 0) || (y % 400 == 0);
        if (leap && m > 2) { n += 1; }
        return n;
    }

    // 0 = counting down, 1 = Christmas Eve, 2 = Christmas Day, 3 = holidays, 4 = New Year.
    private function seasonKind(today as Gregorian.Info) as Number {
        var m = today.month as Number;
        var d = today.day as Number;
        if (m == 12 && d == 25) { return 2; }
        if (m == 12 && d == 24) { return 1; }
        if (m == 12 && d >= 26 && d <= 30) { return 3; }
        if ((m == 12 && d == 31) || (m == 1 && d <= 6)) { return 4; }
        return 0;
    }

    private function sleepsToChristmas(today as Gregorian.Info) as Number {
        var y = today.year as Number;
        return dayOfYear(y, 12, 25) - dayOfYear(y, today.month as Number, today.day as Number);
    }

    // ============================================================ the spots

    // What a small spot shows (a short value), or null when this watch has no
    // value for it - the spot is then left empty.
    private function smallValue(id as Number, today as Gregorian.Info, wx as Array or Null) as String or Null {
        if (id == M_NONE) { return null; }
        if (id == M_COUNTDOWN) {
            var k = seasonKind(today);
            if (k == 0 || k == 1) { return sleepsToChristmas(today).toString(); }
            return (k == 2) ? "Today" : "Joy";
        }
        if (id == M_STEPS) { return fmtNum(getSteps()); }
        if (id == M_HR) {
            var hr = getHeartRate();
            return (hr == null) ? "--" : hr.toString();
        }
        if (id == M_CALS) { return fmtNum(getCalories()); }
        if (id == M_DIST) { return getDistanceStr(false); }
        if (id == M_FLOORS) { return numStr(getFloors(), ""); }
        if (id == M_ACTIVE) { return numStr(getActiveMinutes(), ""); }
        if (id == M_GOAL) { return numStr(getStepGoalPct(), "%"); }
        if (id == M_ENERGY) { return numStr(getBodyBattery(), ""); }
        if (id == M_STRESS) { return numStr(getStress(), ""); }
        if (id == M_BREATH) { return numStr(getRespiration(), ""); }
        if (id == M_BATT) { return getBattery().toString() + "%"; }
        if (id == M_BATTDAYS) { return numStr(getBatteryDays(), "d"); }
        if (id == M_MSGS) {
            var n = System.getDeviceSettings().notificationCount;
            return (n == null) ? "0" : n.toString();
        }
        if (id == M_ALARMS) { return numStr(getAlarms(), ""); }
        if (id == M_ALT) { return getAltitudeStr(false); }
        if (id == M_WEATHER) {
            return (wx == null) ? null : (wx[0] as Number).toString() + (0xB0).toChar().toString();
        }
        return null;
    }

    // What the top line says for each kind of spot.
    private function lineText(id as Number, today as Gregorian.Info, wx as Array or Null) as String or Null {
        if (id == M_COUNTDOWN) {
            var k = seasonKind(today);
            if (k == 1) { return "It's Christmas Eve!"; }
            if (k == 2) { return "Merry Christmas!"; }
            if (k == 3) { return "Happy Holidays"; }
            if (k == 4) { return "Happy New Year!"; }
            var n = sleepsToChristmas(today);
            return (n == 1) ? "1 sleep 'til Christmas" : n.toString() + " sleeps 'til Christmas";
        }
        if (id == M_SAYING) {
            var doy = dayOfYear(today.year as Number, today.month as Number, today.day as Number) - 1;
            return SAYINGS[doy % SAYINGS.size()];
        }
        if (id == M_STEPS) { return fmtNum(getSteps()) + " steps"; }
        if (id == M_HR) {
            var hr = getHeartRate();
            return (hr == null) ? null : hr.toString() + " beats a minute";
        }
        if (id == M_CALS) { return fmtNum(getCalories()) + " calories"; }
        if (id == M_DIST) {
            var d = getDistanceStr(true);
            return (d == null) ? null : d + " today";
        }
        if (id == M_FLOORS) { return numStr(getFloors(), " floors climbed"); }
        if (id == M_ACTIVE) { return numStr(getActiveMinutes(), " active minutes"); }
        if (id == M_GOAL) { return numStr(getStepGoalPct(), "% of my steps"); }
        if (id == M_ENERGY) {
            var bb = getBodyBattery();
            return (bb == null) ? null : "Energy " + bb.toString();
        }
        if (id == M_STRESS) {
            var st = getStress();
            return (st == null) ? null : "Stress " + st.toString();
        }
        if (id == M_BREATH) { return numStr(getRespiration(), " breaths a minute"); }
        if (id == M_BATT) { return "Battery " + getBattery().toString() + "%"; }
        if (id == M_BATTDAYS) { return numStr(getBatteryDays(), " days of battery"); }
        if (id == M_MSGS) {
            var n = System.getDeviceSettings().notificationCount;
            if (n == null || n == 0) { return "No new messages"; }
            return (n == 1) ? "1 new message" : n.toString() + " new messages";
        }
        if (id == M_ALARMS) {
            var al = getAlarms();
            if (al == null) { return null; }
            return (al == 1) ? "1 alarm set" : al.toString() + " alarms set";
        }
        if (id == M_ALT) {
            var alt = getAltitudeStr(true);
            return (alt == null) ? null : alt + " up";
        }
        if (id == M_WEATHER) {
            if (wx == null) { return null; }
            var words = ["clear", "cloudy", "snowy", "rainy"] as Array<String>;
            return (wx[0] as Number).toString() + (0xB0).toChar().toString() + " and " + words[wx[1] as Number];
        }
        return null;
    }

    private function metricIcon(id as Number, wx as Array or Null) as Number {
        if (id == M_COUNTDOWN) { return IC_GIFT; }
        if (id == M_STEPS) { return IC_STEPS; }
        if (id == M_HR) { return IC_HEART; }
        if (id == M_CALS) { return IC_FLAME; }
        if (id == M_DIST) { return IC_PIN; }
        if (id == M_FLOORS) { return IC_STAIRS; }
        if (id == M_ACTIVE) { return IC_TIMER; }
        if (id == M_GOAL) { return IC_STAR; }
        if (id == M_ENERGY) { return IC_BOLT; }
        if (id == M_STRESS) { return IC_STRESS; }
        if (id == M_BREATH) { return IC_RESP; }
        if (id == M_BATT || id == M_BATTDAYS) { return IC_BATTERY; }
        if (id == M_MSGS) { return IC_ENVELOPE; }
        if (id == M_ALARMS) { return IC_BELL; }
        if (id == M_ALT) { return IC_MOUNTAIN; }
        if (id == M_WEATHER) {
            var k = (wx == null) ? WX_CLOUD : (wx[1] as Number);
            if (k == WX_SUN) { return IC_SUN; }
            if (k == WX_SNOW) { return IC_SNOW; }
            if (k == WX_RAIN) { return IC_RAIN; }
            return IC_CLOUD;
        }
        return IC_NONE;
    }

    // ================================================================ icons

    // Small icons drawn with shapes in a unit box of size s centred on (x, y);
    // bg is the colour behind them, used for cut-outs. Same as icon() in the preview.
    private function icon(dc as Dc, type as Number, x as Numeric, y as Numeric, s as Numeric, c as Number, bg as Number) as Void {
        if (type == IC_HEART) {
            fc(dc, x - 0.22 * s, y - 0.12 * s, 0.26 * s, c);
            fc(dc, x + 0.22 * s, y - 0.12 * s, 0.26 * s, c);
            fp(dc, u(x, y, s, [-0.47, -0.02, 0.47, -0.02, 0, 0.46] as Array<Numeric>), c);
        } else if (type == IC_STEPS) {
            fe(dc, x - 0.2 * s, y, 0.14 * s, 0.24 * s, c);
            fe(dc, x - 0.2 * s, y + 0.36 * s, 0.1 * s, 0.09 * s, c);
            fe(dc, x + 0.2 * s, y - 0.2 * s, 0.14 * s, 0.24 * s, c);
            fe(dc, x + 0.2 * s, y + 0.16 * s, 0.1 * s, 0.09 * s, c);
        } else if (type == IC_FLAME) {
            fp(dc, u(x, y, s, [0, -0.5, 0.18, -0.22, 0.36, 0.06, 0.32, 0.3, 0.14, 0.47, -0.14, 0.47, -0.32, 0.3, -0.36, 0.06, -0.2, -0.14, -0.08, 0.02] as Array<Numeric>), c);
            fp(dc, u(x, y, s, [0.02, 0.02, 0.14, 0.22, 0.1, 0.4, -0.1, 0.4, -0.14, 0.22] as Array<Numeric>), bg);
        } else if (type == IC_PIN) {
            fc(dc, x, y - 0.12 * s, 0.32 * s, c);
            fp(dc, u(x, y, s, [-0.29, -0.02, 0.29, -0.02, 0, 0.5] as Array<Numeric>), c);
            fc(dc, x, y - 0.12 * s, 0.12 * s, bg);
        } else if (type == IC_STAIRS) {
            fp(dc, u(x, y, s, [-0.5, 0.45, -0.5, 0.2, -0.22, 0.2, -0.22, -0.05, 0.06, -0.05, 0.06, -0.3, 0.45, -0.3, 0.45, 0.45] as Array<Numeric>), c);
        } else if (type == IC_TIMER) {
            ring(dc, x, y + 0.06 * s, 0.36 * s, c, 0.12 * s);
            fr(dc, x - 0.1 * s, y - 0.5 * s, 0.2 * s, 0.12 * s, c);
            ln(dc, x, y + 0.06 * s, x, y - 0.16 * s, c, 0.1 * s);
            ln(dc, x, y + 0.06 * s, x + 0.15 * s, y + 0.12 * s, c, 0.1 * s);
        } else if (type == IC_STAR) {
            var pts = new [20];
            for (var i = 0; i < 10; i++) {
                var r = (i % 2 == 1) ? 0.22 : 0.5;
                var t = -Math.PI / 2 + i * Math.PI / 5;
                pts[i * 2] = x + Math.cos(t) * r * s;
                pts[i * 2 + 1] = y + (Math.sin(t) * r + 0.04) * s;
            }
            fp(dc, pts as Array<Numeric>, c);
        } else if (type == IC_BOLT) {
            fp(dc, u(x, y, s, [0.12, -0.5, -0.3, 0.08, -0.02, 0.08, -0.12, 0.5, 0.32, -0.1, 0.04, -0.1] as Array<Numeric>), c);
        } else if (type == IC_STRESS) {
            pl(dc, u(x, y, s, [-0.5, 0.02, -0.3, 0.02, -0.17, -0.34, 0.02, 0.36, 0.16, -0.18, 0.28, 0.02, 0.5, 0.02] as Array<Numeric>), c, 0.11 * s);
        } else if (type == IC_RESP) {
            pl(dc, u(x, y, s, [-0.45, -0.22, 0.2, -0.22, 0.32, -0.32] as Array<Numeric>), c, 0.1 * s);
            pl(dc, u(x, y, s, [-0.45, 0, 0.38, 0] as Array<Numeric>), c, 0.1 * s);
            pl(dc, u(x, y, s, [-0.45, 0.22, 0.12, 0.22, 0.24, 0.32] as Array<Numeric>), c, 0.1 * s);
        } else if (type == IC_BATTERY) {
            dc.setColor(c, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(pr(0.1 * s));
            var x0 = px(x - 0.45 * s);
            var y0 = px(y - 0.25 * s);
            dc.drawRectangle(x0, y0, px(x + 0.37 * s) - x0, px(y + 0.25 * s) - y0);
            fr(dc, x + 0.38 * s, y - 0.1 * s, 0.1 * s, 0.2 * s, c);
            var lvl = getBattery().toFloat() / 100.0;
            if (lvl < 0.08) { lvl = 0.08; }
            fr(dc, x - 0.36 * s, y - 0.16 * s, 0.64 * s * lvl, 0.32 * s, c);
        } else if (type == IC_ENVELOPE) {
            fr(dc, x - 0.46 * s, y - 0.3 * s, 0.92 * s, 0.6 * s, c);
            pl(dc, u(x, y, s, [-0.4, -0.24, 0, 0.06, 0.4, -0.24] as Array<Numeric>), bg, 0.08 * s);
        } else if (type == IC_BELL) {
            fc(dc, x, y - 0.08 * s, 0.3 * s, c);
            fr(dc, x - 0.3 * s, y - 0.08 * s, 0.6 * s, 0.3 * s, c);
            fr(dc, x - 0.42 * s, y + 0.18 * s, 0.84 * s, 0.1 * s, c);
            fc(dc, x, y + 0.38 * s, 0.09 * s, c);
        } else if (type == IC_MOUNTAIN) {
            fp(dc, u(x, y, s, [-0.5, 0.4, -0.1, -0.36, 0.16, 0.08, 0.28, -0.06, 0.5, 0.4] as Array<Numeric>), c);
            fp(dc, u(x, y, s, [-0.1, -0.36, -0.22, -0.14, 0.02, -0.14] as Array<Numeric>), bg);
        } else if (type == IC_GIFT) {
            fr(dc, x - 0.4 * s, y - 0.08 * s, 0.8 * s, 0.55 * s, c);
            fr(dc, x - 0.47 * s, y - 0.26 * s, 0.94 * s, 0.16 * s, c);
            fr(dc, x - 0.06 * s, y - 0.26 * s, 0.12 * s, 0.73 * s, bg);
            fp(dc, u(x, y, s, [0, -0.28, -0.3, -0.5, -0.22, -0.28] as Array<Numeric>), c);
            fp(dc, u(x, y, s, [0, -0.28, 0.3, -0.5, 0.22, -0.28] as Array<Numeric>), c);
        } else if (type == IC_SUN) {
            fc(dc, x, y, 0.22 * s, c);
            for (var i = 0; i < 8; i++) {
                var t = i * Math.PI / 4;
                ln(dc, x + Math.cos(t) * 0.33 * s, y + Math.sin(t) * 0.33 * s,
                       x + Math.cos(t) * 0.48 * s, y + Math.sin(t) * 0.48 * s, c, 0.09 * s);
            }
        } else if (type == IC_CLOUD) {
            fc(dc, x - 0.2 * s, y + 0.08 * s, 0.2 * s, c);
            fc(dc, x + 0.06 * s, y - 0.06 * s, 0.27 * s, c);
            fc(dc, x + 0.27 * s, y + 0.1 * s, 0.18 * s, c);
            fr(dc, x - 0.2 * s, y + 0.08 * s, 0.47 * s, 0.2 * s, c);
        } else if (type == IC_RAIN) {
            fc(dc, x - 0.2 * s, y - 0.06 * s, 0.18 * s, c);
            fc(dc, x + 0.04 * s, y - 0.18 * s, 0.24 * s, c);
            fc(dc, x + 0.25 * s, y - 0.04 * s, 0.16 * s, c);
            fr(dc, x - 0.2 * s, y - 0.06 * s, 0.45 * s, 0.18 * s, c);
            var us = [-0.2, 0.02, 0.24] as Array<Numeric>;
            for (var i = 0; i < 3; i++) {
                ln(dc, x + us[i] * s, y + 0.26 * s, x + (us[i] - 0.07) * s, y + 0.46 * s, c, 0.08 * s);
            }
        } else if (type == IC_SNOW) {
            for (var i = 0; i < 3; i++) {
                var t = i * Math.PI / 3 + Math.PI / 2;
                var cx = Math.cos(t) * 0.46 * s;
                var cy = Math.sin(t) * 0.46 * s;
                ln(dc, x - cx, y - cy, x + cx, y + cy, c, 0.09 * s);
            }
        }
    }

    // Unit-box coordinates [u0, v0, u1, v1, ...] -> base coordinates around (x, y).
    private function u(x as Numeric, y as Numeric, s as Numeric, uv as Array<Numeric>) as Array<Numeric> {
        var out = new [uv.size()];
        for (var i = 0; i < uv.size(); i += 2) {
            out[i] = x + uv[i] * s;
            out[i + 1] = y + uv[i + 1] * s;
        }
        return out as Array<Numeric>;
    }

    // ================================================================= data

    private function numStr(v as Number or Null, suffix as String) as String or Null {
        return (v == null) ? null : v.toString() + suffix;
    }

    // 8432 -> "8,432"
    private function fmtNum(n as Number) as String {
        if (n < 1000) { return n.toString(); }
        if (n < 1000000) { return (n / 1000).toString() + "," + (n % 1000).format("%03d"); }
        return (n / 1000000).toString() + "," + ((n / 1000) % 1000).format("%03d") + "," + (n % 1000).format("%03d");
    }

    private function getSteps() as Number {
        var info = ActivityMonitor.getInfo();
        if (info != null && info.steps != null) { return info.steps as Number; }
        return 0;
    }

    private function getCalories() as Number {
        var info = ActivityMonitor.getInfo();
        if (info != null && (info has :calories) && info.calories != null) { return info.calories as Number; }
        return 0;
    }

    // Distance today in the watch's units: "3.2" in a small spot, "3.2 miles"
    // on the top line. ActivityMonitor reports centimetres.
    private function getDistanceStr(words as Boolean) as String or Null {
        var info = ActivityMonitor.getInfo();
        if (info == null || !(info has :distance) || info.distance == null) { return null; }
        var cm = (info.distance as Number).toFloat();
        var settings = System.getDeviceSettings();
        var metric = !(settings has :distanceUnits) || settings.distanceUnits == System.UNIT_METRIC;
        var v = metric ? cm / 100000.0 : cm / 160934.0;
        var s = v.format("%.1f");
        if (!words) { return s; }
        return s + (metric ? " km" : " miles");
    }

    private function getFloors() as Number or Null {
        var info = ActivityMonitor.getInfo();
        if (info != null && (info has :floorsClimbed) && info.floorsClimbed != null) { return info.floorsClimbed as Number; }
        return null;
    }

    private function getActiveMinutes() as Number or Null {
        var info = ActivityMonitor.getInfo();
        if (info != null && (info has :activeMinutesDay) && info.activeMinutesDay != null) {
            var am = info.activeMinutesDay as ActivityMonitor.ActiveMinutes;
            if (am.total != null) { return am.total as Number; }
        }
        return null;
    }

    private function getStepGoalPct() as Number or Null {
        var info = ActivityMonitor.getInfo();
        if (info == null || info.steps == null || !(info has :stepGoal) || info.stepGoal == null) { return null; }
        var goal = info.stepGoal as Number;
        if (goal <= 0) { return null; }
        return ((info.steps as Number) * 100) / goal;
    }

    private function getBodyBattery() as Number or Null {
        if ((Toybox has :SensorHistory) && (SensorHistory has :getBodyBatteryHistory)) {
            try {
                var it = SensorHistory.getBodyBatteryHistory({:period => 1, :order => SensorHistory.ORDER_NEWEST_FIRST});
                if (it != null) {
                    var sample = it.next();
                    if (sample != null && sample.data != null) { return (sample.data as Float).toNumber(); }
                }
            } catch (e) {
                // fall through
            }
        }
        return null;
    }

    private function getStress() as Number or Null {
        var info = ActivityMonitor.getInfo();
        if (info != null && (info has :stressScore) && info.stressScore != null) { return info.stressScore as Number; }
        return null;
    }

    private function getRespiration() as Number or Null {
        var info = ActivityMonitor.getInfo();
        if (info != null && (info has :respirationRate) && info.respirationRate != null) { return info.respirationRate as Number; }
        return null;
    }

    private function getBattery() as Number {
        var stats = System.getSystemStats();
        if (stats != null && stats.battery != null) { return (stats.battery + 0.5).toNumber(); }
        return 0;
    }

    private function getBatteryDays() as Number or Null {
        var stats = System.getSystemStats();
        if (stats != null && (stats has :batteryInDays) && stats.batteryInDays != null) { return (stats.batteryInDays as Float).toNumber(); }
        return null;
    }

    private function getAlarms() as Number or Null {
        var settings = System.getDeviceSettings();
        if (settings != null && (settings has :alarmCount) && settings.alarmCount != null) { return settings.alarmCount as Number; }
        return null;
    }

    // Altitude in the watch's units: "812" in a small spot, "812 feet" on the top line.
    private function getAltitudeStr(words as Boolean) as String or Null {
        var info = Activity.getActivityInfo();
        if (info == null || !(info has :altitude) || info.altitude == null) { return null; }
        var m = info.altitude as Float;
        var settings = System.getDeviceSettings();
        var metric = !(settings has :elevationUnits) || settings.elevationUnits == System.UNIT_METRIC;
        var s = fmtNum((metric ? m : m * 3.28084).toNumber());
        if (!words) { return s; }
        return s + (metric ? " metres" : " feet");
    }

    private function getHeartRate() as Number or Null {
        var info = Activity.getActivityInfo();
        if (info != null && info.currentHeartRate != null) { return info.currentHeartRate; }
        if (ActivityMonitor has :getHeartRateHistory) {
            var it = ActivityMonitor.getHeartRateHistory(1, true);
            if (it != null) {
                var sample = it.next();
                if (sample != null && sample.heartRate != null && sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                    return sample.heartRate;
                }
            }
        }
        return null;
    }

    // Current weather as [temperature in the watch's units, WX_* kind], or null.
    private function getWeather() as Array or Null {
        try {
            if (Toybox has :Weather) {
                var cc = Weather.getCurrentConditions();
                if (cc != null && cc.temperature != null) {
                    var temp = cc.temperature as Numeric;
                    var settings = System.getDeviceSettings();
                    if ((settings has :temperatureUnits) && (settings.temperatureUnits != System.UNIT_METRIC)) {
                        temp = temp * 9.0 / 5.0 + 32.0;
                    }
                    var cond = (cc.condition != null) ? cc.condition as Number : -1;
                    var kind = WX_CLOUD;
                    if (cond == 4 || cond == 7 || cond == 16 || cond == 17 || cond == 18 || cond == 19 ||
                        cond == 21 || cond == 34 || cond == 43 || cond == 44 || cond == 46 || cond == 47 ||
                        cond == 48 || cond == 49 || cond == 50 || cond == 51) {
                        kind = WX_SNOW;
                    } else if (cond == 3 || cond == 6 || cond == 11 || cond == 12 || cond == 13 || cond == 14 ||
                               cond == 15 || cond == 24 || cond == 25 || cond == 26 || cond == 27 || cond == 28 ||
                               cond == 31 || cond == 32 || cond == 36 || cond == 41 || cond == 42 || cond == 45) {
                        kind = WX_RAIN;
                    } else if (cond == 0 || cond == 1 || cond == 22 || cond == 23 || cond == 40) {
                        kind = WX_SUN;
                    }
                    return [Math.round(temp.toFloat()).toNumber(), kind];
                }
            }
        } catch (e) {
            // fall through
        }
        return null;
    }
}
