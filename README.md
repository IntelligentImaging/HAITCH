# HAITCH
Source code for distortion and motion correction in multi-shell fetal diffusion MRI.

## Requirements
* This pipeline relies heavily on MRtrix, tested with version=3.0.4
* Tested with Python=3.13.2
* ANTs, for registration (optionally: FSL/FLIRT as an alternate registration strategy)
* At least one of Docker or Apptainer, for segmentation
* This pipeline relies on the binary dwisliceoutliergmm found in: https://github.com/dchristiaens/shard-recon. Add the location of this binary to your PATH.
* libpng15: https://github.com/pnggroup/libpng/tree/libpng15#

If you use this code, you agree to cite the following publication:

Snoussi, H., Karimi, D., Afacan, O., Utkur, M. Gholipour, A., 2025. Haitch: A framework for distortion and motion correction in fetal multi-shell diffusion-weighted mri. Forthcoming, Imaging Neuroscience, MIT Press. ArXiv, pp.arXiv-2406.

[https://pubmed.ncbi.nlm.nih.gov/38979484/ ](https://doi.org/10.1162/imag_a_00490)

This research was supported by NIH grants R01NS106030, R01EB031849, R01EB032366, R01HD109395, R01HD110772, R01NS128281, and R01NS121657; in part by the Office of the Director of the NIH under award number S10OD025111; and in part by the National Science Foundation (NSF) under grant number 212306.
