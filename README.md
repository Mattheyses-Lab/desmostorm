# DesmoSTORM

**DesmoSTORM** is a MATLAB-based application for viewing and analyzing reconstructed dSTORM images of desmosomal plaque proteins.

---

## Requirements

- MATLAB (R2025a or later)
- Image Processing Toolbox
- Curve Fitting Toolbox
- Signal Processing Toolbox

---

## Installation

1. Clone or download this repository.
2. In MATLAB, add the project root folder to the path. For example:

```matlab
addpath(genpath('path/to/DesmoSTORM'))
```

---

## Running the Application

From the MATLAB Command Window, run:

```matlab
app.GUI
```

This will launch the main DesmoSTORM graphical interface.

---

## Changing Settings

Inside the app, settings can be changed using the expandable panels along the left side of the window.

Any changes made will apply to the current run only, unless you click **File**&rarr;**Save settings** in the Menubar.

If you want to reset the settings, close the app and from the MATLAB Command Window, run:

```matlab
app.config.Settings.restore()
```

This will restore ALL settings to their default values.

---

## Notes

- This project is under active development; APIs and behavior may change.

---

## License

(To be added.)
