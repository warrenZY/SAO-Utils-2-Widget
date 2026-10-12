# Widget Info Directory

This directory stores additional metadata for widgets that will be included in GitHub Releases.

## Structure

```
widget-info/
  <widget-directory-name>/
	workshop-link.txt    # Steam Workshop link (optional)
	preview.png          # Preview image (optional, for future use)
```

## Usage

### workshop-link.txt

Create a file named `workshop-link.txt` in the widget's info directory containing the Steam Workshop URL. This link will be automatically added to the Release Notes.

Example:
```
https://steamcommunity.com/sharedfiles/filedetails/?id=3812628205
```

## Notes

- The directory name must match the widget directory name (e.g., `com.warrenzy.widget.countdown`)
- All files in this directory are optional
- This directory will NOT be scanned as a widget directory by the release workflow
