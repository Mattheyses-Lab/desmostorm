# DesmoSTORM

**DesmoSTORM** is a MATLAB application for viewing and analyzing reconstructed
super-resolution images of desmosomal plaque proteins.

The app supports multi-channel image display, region picking, ROI-based
linescan analysis, classifier-assisted region detection, and export of
measurements, images, summary PDFs, and linescan plots.

## Quick Start

Clone or download this repository, open MATLAB, and navigate to the project
root folder:

```matlab
cd path/to/desmostorm
```

Then launch the app:

```matlab
desmostorm.launch
```

On a new install, `desmostorm.launch` performs required setup automatically.
It adds DesmoSTORM and bundled dependencies to the MATLAB path, configures
matlabx and Bio-Formats, performs UI calibration, creates or migrates app
settings, and opens the GUI.

After setup has completed successfully, `desmostorm.launch` should work from
the MATLAB Command Window in later sessions. If MATLAB cannot find the
package, navigate back to the project root and run the command again.

## Requirements

- MATLAB R2025b
- Image Processing Toolbox
- Curve Fitting Toolbox
- Signal Processing Toolbox
- Parallel Computing Toolbox
- Computer Vision Toolbox
- Deep Learning Toolbox
- Deep Learning Toolbox Model for ResNet-18 Network
- Statistics and Machine Learning Toolbox

## Basic Workflow

1. Launch the app with `desmostorm.launch`.
2. Create or open a project from the **File** menu.
3. Load reconstructed image files with **File > Load Images...**.
4. Pick regions in the main image viewer.
5. Adjust region boxes and linescan ROIs as needed.
6. Review measurements, linescan plots, and region summaries.
7. Save the project or export measurements, images, plots, and summary PDFs.

Projects store images, regions, labels, per-image display ranges, project-wide
channel display choices, and analysis results. App settings control defaults
and display/analysis behavior.

## Region Picking And Labels

Use the Pick tool in the main image viewer to create and edit region boxes.
Click the Pick tool icon, then click in the image to place a new box. While
the Pick tool is active, existing boxes can be dragged to new positions and
right-clicked to delete them.

Region activation and selection are separate. Left-clicking a box makes that
region active in the GUI and Region Viewer. Shift-clicking a box adds or
removes it from the current selection; selected boxes remain shaded.
Double-clicking a box clears the current selection.

Labels are managed in the **Labels** accordion item. Each label can have a
name, ID, color, and hotkey. Pressing a label hotkey makes that label active
and applies it to the currently selected regions in the active image. New
regions are assigned the currently active label when they are placed, so choose
the active label before picking a batch of regions with the same class.

## Classifier Training And Detection

DesmoSTORM includes an experimental patch-classifier workflow for proposing
regions automatically. This currently uses a binary ResNet-18 patch classifier,
so the MATLAB **Deep Learning Toolbox Model for ResNet-18 Network** support
package must be installed before training a new classifier.

### Training Data

Training uses regions in the current project. Regions labeled `object` with
`LabelSource="user"` are treated as positive examples, and regions labeled
`background` with `LabelSource="user"` are treated as user-supplied negative
examples. Classifier-created proposals remain `unlabeled` with
`LabelSource="classifier"` until the user reviews them, so unreviewed proposals
are ignored during training.

The training pipeline also samples random background patches from images that
contain positive examples. Random negatives are rejected if they overlap too
strongly with user-labeled regions.

### Train A New Classifier

1. Open or create a project.
2. Load training images.
3. Pick and label representative `object` and `background` regions.
4. Select **Run > Train New Classifier...**.
5. Choose training parameters and wait for training to finish.

Dialog parameters:

- **Classifier name**: base name used when saving the classifier. Spaces are not allowed.
- **MaxEpochs**: number of training epochs.
- **InitialLearnRate**: optimizer learning rate.
- **IoUMax**: maximum allowed overlap for random negative patches.
- **MiniBatchSize**: number of patches per training batch.

Fresh training starts from pretrained `resnet18`, replaces the classification
head for the two labels, crops project regions at the configured box size, and
resizes patches to the network input size.

### Retrain An Existing Classifier

1. Open a project containing newly reviewed `object` and `background` labels.
2. Select **Run > Continue Training Existing Classifier...**.
3. Choose an existing classifier `.mat` file.
4. Choose continued-training parameters.

Continued training loads the previous classifier package, builds a new patch
table from the current project, merges it with the package's stored training
table, and saves the result as the next classifier version.

### Apply A Classifier

1. Open a project and load images.
2. Select **Run > Run classifier...**.
3. Choose a saved classifier `.mat` file.
4. Adjust proposal parameters.

Dialog parameters:

- **Stride**: spacing, in pixels, between sliding-window patch centers. Smaller values search more densely but run slower.
- **ScoreThreshold**: minimum positive-class score required to keep a proposal.
- **NmsIoU**: non-maximum suppression overlap threshold used to remove duplicate proposals.
- **BatchSize**: number of patches evaluated per classifier batch.

Running a classifier removes existing regions on each processed image and adds
new proposal regions with `LabelID="unlabeled"` and
`LabelSource="classifier"`. Review and relabel those proposals before using
them as training examples.

### Classifier Files

Classifier packages are saved in `assets/ml/` by default. Each package is a
MAT-file named like:

```text
classifier_<name>_v001.mat
```

The MAT-file contains a `ClassifierPackage` struct with the trained network,
box size, training options, proposal defaults, the merged patch table, positive
class name, creation time, optional source model, and notes. Companion CSV
files are saved alongside the classifier:

```text
patchTable_<name>_v001_project.csv
patchTable_<name>_v001_training.csv
```

The `project` table records patches from the current project. The `training`
table records the full table used to train that classifier version.

## Setup Details

Manual setup is normally not required. The first call to `desmostorm.launch`
runs setup when the stored setup version is older than the required setup
version.

Setup currently:

- Adds the project root to the MATLAB path.
- Adds bundled `external/matlabx` to the MATLAB path.
- Runs `matlabx.setup.run()`.
- Configures the bundled Bio-Formats installation.
- Runs matlabx UI calibration.
- Creates or migrates DesmoSTORM settings.

If setup needs to be rerun manually:

```matlab
desmostorm.setup.run()
```

## Settings

Settings in the left-side accordion panels apply to the current app session.
Use **File > Save Settings** to save them as app defaults.

Common panels:

- **Images**: loaded images and active image selection.
- **Regions**: picked regions for the active image.
- **Analysis**: region box size, linescan normalization, peak detection, and pixel size.
- **Channel Display**: channel color mode and per-channel colors.
- **Colormap**: colormap for the active image channel.
- **Image Display**: intensity auto-scaling and per-channel display limits.
- **Peaks Plot**: linescan plot visibility, colors, annotations, and line widths.
- **Linescan ROI**: ROI overlay, rotation annotation, and label appearance.
- **Labels**: region label definitions and active label selection.

To reset saved app settings:

```matlab
desmostorm.config.Settings.restore()
```

This overwrites the saved settings file with defaults.

## Preferences

Preferences are sparse persistent command-line options stored with MATLAB's
preferences system. They are separate from project files and app settings.

Print stored preferences:

```matlab
desmostorm.Preferences.print()
```

List known preference names:

```matlab
desmostorm.Preferences.names()
```

Describe known preferences, dynamic defaults, effective values, and whether
each preference has been explicitly stored:

```matlab
desmostorm.Preferences.describe()
```

Developer mode can be toggled while the app is running:

```matlab
desmostorm.runtime.enableDeveloperMode()
desmostorm.runtime.disableDeveloperMode()
```

Developer mode currently adjusts logging defaults. Explicit `Logging*`
preferences override developer-mode defaults.

## Files And Folders

- `user/`: default location for user settings and user-facing outputs.
- `logs/`: GUI session log files.
- `data/`: local/generated data; contents are ignored by Git.
- `assets/`: local assets and demo images; generated contents are ignored by Git.
- `external/`: bundled third-party dependencies. Do not edit this folder unless updating the dependency itself.

The generated contents of `user/`, `logs/`, `data/`, and `assets/` are ignored by Git.

## Troubleshooting

If MATLAB cannot find `desmostorm.launch`, navigate to the project root and
run it from there.

If image loading fails because of Bio-Formats or Java classpath issues, rerun:

```matlab
desmostorm.setup.run()
```

If the GUI behaves unexpectedly after settings changes, try resetting saved
settings:

```matlab
desmostorm.config.Settings.restore()
```

Session logs are written under `logs/`. Developer mode increases log detail.

## Notes

This project is under active development; APIs, file formats, and behavior may
change.

## License

To be added.
