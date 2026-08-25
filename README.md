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
and display/analysis behavior. When a project has unsaved changes, an asterisk
appears in the window title. Closing the project, opening another project, or
exiting the GUI will prompt you to save or discard those changes.

## Image Viewer

The main Image Viewer shows the active image and provides channel display,
zooming, colorbar, and region-picking tools.

- Left/right arrow keys change the displayed channel.
- Meta+Shift+M toggles the merged composite display. On macOS, Meta is Command; on Windows, use the Windows key.
- The colormap selector applies to the currently displayed channel.
- The colorbar reflects the active channel and its current display limits.

To zoom, click the magnifying glass icon to enable zoom mode:

- Left-click zooms in.
- Right-click zooms out.
- Shift-click toggles cursor-follow zoom behavior.
- Scroll wheel or trackpad scroll also adjusts zoom.
- Esc restores the full image view.

## Region Picking And Labels

Use the Pick tool in the main image viewer to create and edit region boxes.
Click the Pick tool icon to activate it. While the Pick tool is active:

- Click empty image area to create a new region.
- Click and drag an existing box to move it.
- Click a box to make that region active in the GUI and Region Viewer.
- Alt/Option-click a box to deactivate the active box.
- Shift-click a box to add or remove it from the current selection; selected boxes remain shaded.
- Control-click a box to delete that region.

Region activation and selection are separate. The active region drives the
Region Viewer, summary table, ROI editor, and linescan plot. The selected
regions are the target for batch labeling with label hotkeys. There are
currently no batch deselection or batch delete mouse actions; those are planned
for a future context menu.

Labels are managed in the **Labels** accordion item. Each label can have a
name, ID, color, and hotkey. Pressing a label hotkey makes that label active
and applies it to the currently selected regions in the active image. New
regions are assigned the currently active label when they are placed, so choose
the active label before picking a batch of regions with the same class.

## Multi-Channel Display And Linescans

The main image viewer and Region Viewer support multi-channel images. Changing
the active channel in the image viewer updates channel-aware controls such as
the colormap selector and current-channel linescan display. Channel colormaps
and channel colors are stored with the project so they persist across save/load.

Intensity sliders are created dynamically from the maximum channel count in the
project and collapse to the channels present in the active image. Slider limits
come from each image channel's data range, while slider values come from the
saved or auto-scaled display range.

Linescan plots can show either the current channel or all channels for the
active region, depending on **Peaks Plot > Shown Plots**. Plot colors can follow
project channel colors or use a manual color from the Peaks Plot settings.

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

For a useful first classifier, include both positives and negatives. A project
with only positive labels can still train because DesmoSTORM adds random
background negatives, but those negatives are often too easy. The classifier may
show high training accuracy while still producing many false positives on
plaque-like fragments, neighboring structures, edge junk, or bad centers.

The most effective workflow is iterative hard-negative mining:

1. Label representative `object` regions.
2. Label obvious `background` regions, especially structures that look almost
   like real objects but should not be detected.
3. Train a classifier.
4. Run the classifier on images.
5. Mark correct proposals, adjust centers if needed, and label false positives
   as `background`.
6. Continue training with the reviewed proposals.

### Train A New Classifier

1. Open or create a project.
2. Load training images.
3. Pick and label representative `object` regions.
4. Pick and label representative `background` regions, including hard negatives
   that resemble plaques but should not be detected.
5. Select **Run > Train New Classifier...**.
6. Choose training parameters and wait for training to finish.

Dialog parameters:

- **Classifier name**: base name used when saving the classifier. Spaces are not allowed.
- **MaxEpochs**: number of passes through the training patch table. More epochs
  can help small datasets, but very high values can overfit.
- **InitialLearnRate**: optimizer learning rate. Larger values adapt faster;
  smaller values are more conservative.
- **IoUMax**: maximum allowed overlap for random negative patches. Lower values
  keep random negatives farther from user-labeled boxes.
- **ValidationFrequency**: number of training iterations between validation
  checks. This is measured in mini-batch iterations, not epochs. For small
  datasets, a value of `50` may validate only a few times.
- **MiniBatchSize**: number of patches per training batch. Larger batches can be
  faster on suitable hardware but require more memory.

Fresh training starts from pretrained `resnet18`, replaces the classification
head for the two labels, crops project regions at the configured box size, and
resizes patches to the network input size.

Suggested starting point:

- Use `MaxEpochs=5-15`.
- Use `InitialLearnRate=1e-4` to `3e-4`.
- Use a smaller `ValidationFrequency` when the dataset is small.
- Do not judge success by training accuracy alone. Proposal precision after
  review is usually more informative.

### Retrain An Existing Classifier

1. Open a project containing newly reviewed `object` and `background` labels.
2. Select **Run > Continue Training Existing Classifier...**.
3. Choose an existing classifier `.mat` file.
4. Choose continued-training parameters.

Continued training loads the previous classifier package, builds a new patch
table from the current project, merges it with the package's stored training
table, and saves the result as the next classifier version.

Use continued training after reviewing classifier proposals. This is where false
positives become valuable: label them as `background`, keep or correct true
objects, and retrain. For continued training, smaller updates are usually safer:

- Use `MaxEpochs=3-8`.
- Use `InitialLearnRate=1e-5` to `1e-4`.
- Keep validation frequent enough to see whether the new labels are helping.

Repeated continued training is useful, but it can become history-dependent if
each round adds only a few new examples. In that case, retrain the package from
scratch using the accumulated patch table.

### Retrain From Scratch

Use **Run > Retrain Existing Classifier From Scratch...** when you have a
classifier package with a good accumulated patch table but want to rebuild the
network cleanly. This workflow:

1. Loads the selected classifier package.
2. Uses the package's accumulated training patch table.
3. Initializes a fresh `resnet18` transfer-learning model.
4. Splits the accumulated table into training and validation sets.
5. Trains a new network without reusing the old network weights.
6. Saves the result as the next classifier version.
7. Materializes the training patches into the new version's patch folder.

This is a good cleanup step after several rounds of proposal review and
continued training. It keeps the curated examples but removes dependence on the
old optimization history. If the source package is not already materialized,
the original image files referenced by its patch table must still be available.

### Apply A Classifier

1. Open a project and load images.
2. Select **Run > Run classifier...**.
3. Choose a saved classifier `.mat` file.
4. Adjust proposal parameters.

Dialog parameters:

- **CandidateMode**: how candidate patch centers are generated.
  `grid` scans the full image on a regular grid. `ClusterCentroid` evaluates
  cluster centroids from detected puncta. `ClusterArea` samples centers inside
  cluster areas.
- **Stride**: spacing, in pixels, between sliding-window patch centers. Smaller values search more densely but run slower.
- **ScoreThreshold**: minimum positive-class score required to keep a proposal.
- **NmsIoU**: non-maximum suppression overlap threshold used to remove duplicate proposals.
- **BatchSize**: number of patches evaluated per classifier batch.

Running a classifier removes existing regions on each processed image and adds
new proposal regions with `LabelID="unlabeled"` and
`LabelSource="classifier"`. Review and relabel those proposals before using
them as training examples.

If false positives dominate, raise `ScoreThreshold`, add hard-negative
`background` labels, then continue training. If true objects are missed, lower
`ScoreThreshold`, use a denser candidate mode or smaller `Stride`, and add more
representative positive examples.

### Classifier Files

Classifier packages are saved in `assets/ml/` by default. Each package is a
MAT-file named like:

```text
classifier_<name>_v001.mat
```

The MAT-file contains a `ClassifierPackage` struct with the trained network,
box size, training options, proposal defaults, the merged patch table, positive
class name, creation time, optional source model, notes, and patch-store
metadata. Companion CSV files are saved alongside the classifier:

```text
patchTable_<name>_v001_project.csv
patchTable_<name>_v001_training.csv
```

The `project` table records patches from the current project. The `training`
table records the full table used to train that classifier version.

New classifier packages also write a patch folder next to the classifier:

```text
classifier_<name>_v001_patches/
```

That folder contains cropped training patch TIFFs plus `patch_manifest.csv`.
The package's training patch table includes `patchFilename`, so continued
training can read those materialized patches instead of requiring the original
training images. Applying a classifier only requires the classifier package and
the images you want to analyze.

Older classifier packages may only contain patch metadata that points back to
the original source images. To materialize patches for an existing package from
the MATLAB Command Window:

```matlab
desmostorm.ml.materializeClassifierPatches("assets/ml/classifier_name_v001.mat")
```

This updates the package with a patch store and writes the cropped training
patches next to the classifier file.

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
