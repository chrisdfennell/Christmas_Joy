import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Application entry point for the Christmas Joy watch face.
class ChristmasJoyApp extends Application.AppBase {

    private var mView as ChristmasJoyView or Null = null;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    // Re-read settings and repaint when they change in Garmin Connect.
    function onSettingsChanged() as Void {
        if (mView != null) {
            mView.loadSettings();
        }
        WatchUi.requestUpdate();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        mView = new ChristmasJoyView();
        return [ mView ];
    }
}

function getApp() as ChristmasJoyApp {
    return Application.getApp() as ChristmasJoyApp;
}
