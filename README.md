# DesmoSTORM

**DesmoSTORM** is a MATLAB-based application for viewing and analyzing reconstructed super-resolution images of desmosomal plaque proteins.

---

## Requirements

- MATLAB (R2025b or later)
- Image Processing Toolbox
- Curve Fitting Toolbox
- Signal Processing Toolbox
- Parallel Computing Toolbox
- Computer Vision Toolbox
- Deep Learning Toolbox
- Statistics and Machine Learning Toolbox

---

## Installation

Clone or download this repository.

In MATLAB, navigate to the project root folder using the file browser or the Command Window. For example:

```matlab
cd path/to/DesmoSTORM
```

From the project root folder, type the following into the MATLAB Command Window:

```matlab
app.setup();
```

After setup completes, you are ready to run the software.

---





## Running the Application

From the MATLAB Command Window, run:

```matlab
app.GUI;
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
