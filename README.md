# Christmas Joy

A Garmin Connect IQ watch face: an evergreen wreath around a snow globe.

- **The wreath** runs round the rim with berries, twelve ornaments and a bow at six o'clock. The ornaments light up one by one, clockwise from the bow, as the day's step goal fills. They can follow Body Battery or the watch battery instead, or stay lit.
- **The snow globe** holds a cottage with a smoking chimney, pine trees and snow drifts. Snow is scattered fresh each minute, and every second while the wrist is raised. More of it falls when it is really snowing outside. After sunset the sky turns to night, the stars come out and the cottage windows glow.
- **The text**: a countdown across the top ("26 sleeps 'til Christmas", then "It's Christmas Eve!", "Merry Christmas!", "Happy New Year!"), the date, and the time in script.
- **Seven spots to fill**: the top line, one spot each side of the time, three on the snow, and what the wreath tracks. Each spot can show steps, heart rate, calories, distance, floors, active minutes, step goal, Body Battery, stress, respiration, battery, battery days, notifications, alarms, altitude, weather, the Christmas countdown or a saying of the day, or nothing.
- **Four themes**: Blush & Gold (the default), Classic, Frosted and Cozy Plaid.
- **Always-On**: a black screen with the time and a small star in dim gold, nudged each minute to protect the screen.

Round AMOLED watches only, Connect IQ 4.0 and up (Forerunner 165/265/570/965/970, fenix 8, epix 2, Venu 2/3/4, vivoactive 5/6 and others; see [manifest.xml](manifest.xml)).

## Preview in a browser

Open [preview/index.html](preview/index.html). It draws the face with the same shapes, coordinates, fonts and random sequence as the watch code, with controls for the theme, the date and time, day and night, the weather, every spot, and sample readings.

## Build

Needs the [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) (with the device files downloaded in the SDK Manager) and a JDK. Put both paths in `build_config.json`:

```json
{ "JavaHome": "C:\\Program Files\\...\\jdk-21", "SdkDir": "C:\\Users\\...\\ConnectIQ\\Sdks\\connectiq-sdk-win-..." }
```

```powershell
.\build.ps1                    # build for fr970 (454x454), her watch
.\build.ps1 -Device fr265 -Run # build for another watch and open it in the simulator
.\build.ps1 -Export            # package bin\ChristmasJoy.iq for the Connect IQ store
```

The build signs with `developer_key.der` (not in git).

## Fonts

`tools/gen_fonts.py` bakes the bitmap fonts for each screen size (454, 416, 390 and 360 pixels) from the TrueType files in `fonts-src/`: Dancing Script for the time, Great Vibes for the top line and Quicksand for the date and data. All three are under the SIL Open Font License (`fonts-src/OFL-*.txt`). Run it again after changing a font or a size:

```powershell
python tools/gen_fonts.py
```

It prints each font's ink-middle ratio, which the view uses (`MID_*` in [source/ChristmasJoyView.mc](source/ChristmasJoyView.mc)) to centre text.

## Screenshots and store images

With the face running in the simulator (`run_simulator.bat`, or `.\build.ps1 -Run`):

```powershell
.\savescreenshot.ps1 -Name screen_day     # assets\screen_day.png
.\savescreenshot.ps1 -Name screen_night   # assets\screen_night.png
python tools/gen_assets.py                # icon, cover and banner from those captures
```

`gen_assets.py` writes `assets/app_icon_24bit.png` and `app_icon_64color.png` (128 x 128), `cover_image.png`/`.jpg` (500 x 500) and `hero_image.png` (1440 x 720, the day and night faces side by side). To capture the other sky, change the Sky setting in the simulator (File > Edit Persistent Storage).

## Releases

GitHub Actions run two workflows:

- **CI** ([ci.yml](.github/workflows/ci.yml)), on every push and pull request to `main`: checks the required files, that every XML file parses, that every screen size has its full font set, that the jungle only names watches in the manifest, and that the Python tools compile.
- **Release** ([release.yml](.github/workflows/release.yml)), on a version tag: builds `ChristmasJoy.iq` for the store plus a side-loadable `.prg` for each screen size, and attaches them to a GitHub Release. It needs the developer key as the repository secret `GARMIN_DEVELOPER_KEY` (base64; the steps are at the top of the file).

```powershell
git tag v1.0.0
git push origin v1.0.0
```

## Layout

The whole face is laid out on a 454 x 454 grid and scaled to the screen. If you change a position, colour or shape, change it in both `source/ChristmasJoyView.mc` and `preview/index.html` so the preview keeps matching the watch.
