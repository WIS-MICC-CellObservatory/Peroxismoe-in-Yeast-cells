# Peroxismoein-Yeast-cells
This Fiji macro script is designed to process microscopy images of yeast cells and their peroxisomes. It performs segmentation, calculates ECI-1 protein intensities inside and outside the organelles, and outputs statistical measurements.
## Features

- Segments yeast cells using Cellpose.
- Segments peroxisomes using Stardist.
- Computes mean and total intensity of ECI-1 protein signal within and outside the peroxisomes.
- Outputs results as a CSV file and saves processed ROI sets.

## Requirements

- Fiji with the following plugins:
  - [Stardist](https://github.com/stardist/stardist)
  - [Cellpose](https://cellpose.readthedocs.io/en/latest/)
- An Anaconda environment with Cellpose installed.
- Microscopy image files (e.g., `.tif`) with the following channels:
  - Brightfield (Yeast)
  - Confocal mCherry (Peroxisomes)
  - Confocal GFP (Protein signal)

## Input Parameters

The macro accepts the following user-defined inputs:

| Parameter                          | Description                                                                                       |
|------------------------------------|---------------------------------------------------------------------------------------------------|
| **Yeast image path**               | Path to the brightfield image of yeast cells.                                                    |
| **Peroxisome image path**          | Path to the mCherry fluorescence image for peroxisome segmentation.                              |
| **Protein image path**             | Path to the GFP fluorescence image for ECI-1 protein analysis.                                   |
| **Output directory**               | Directory to save results, including CSV tables and ROI sets.                                    |
| **Peroxisome mean intensity threshold** | Minimum intensity for peroxisome ROIs.                                                         |
| **Protein intensity threshold**    | Minimum intensity for ECI-1 protein signal.                                                      |
| **Yeast cell diameter**            | Diameter (in pixels) for yeast cell segmentation.                                                |
| **Cellpose environment path**      | Path to the Anaconda environment containing Cellpose.                                            |

## Output

The script generates:

1. **CSV File**: A table containing the following measurements:
   - Mean and total ECI-1 intensities inside peroxisomes.
   - Mean and total ECI-1 intensities outside peroxisomes.
   - Peroxisome area ratio.
   - Peroxisome intensity ratio.

2. **ROI Set**: A `.zip` file containing the segmented ROIs for yeast cells and peroxisomes.

## Usage

1. Install the required plugins and set up the Cellpose environment.
2. Open Fiji and run the macro.
3. Fill in the input parameters as prompted.
4. The script processes the images and saves the results in the specified output directory.

## Code Overview

The macro consists of the following main steps:

1. **Image Segmentation**:
   - Yeast cells are segmented using Cellpose.
   - Peroxisomes are segmented using Stardist.
2. **ROI Filtering and Combination**:
   - Low-intensity peroxisome ROIs are removed.
   - Remaining peroxisome ROIs are combined into a single ROI.
3. **Protein Intensity Analysis**:
   - ECI-1 signal is quantified within and outside peroxisomes.
4. **Data Output**:
   - Statistical results are saved as a CSV file.
   - ROI sets are saved for further analysis.

## Example Command Line

Here’s an example of setting up the script:

```plaintext
#@ File (label="Yeast image path",value="path/to/yeast_image.tif")
#@ File (label="Peroxisome image path",value="path/to/peroxisome_image.tif")
#@ File (label="Protein image path",value="path/to/protein_image.tif")
#@ File (label="Output directory", style="directory") 
#@ Integer (label="Peroxisome mean intensity threshold",value="200")
#@ Integer (label="Protein intensity threshold",value="400")
#@ Integer (label="Yeast cell diameter (pixels)",value="40")
#@ File (label="Cellpose, Environment",value="path/to/anaconda/envs/cellpose", style="directory")
