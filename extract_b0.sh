#!/bin/bash

for i in 1 2 3; do
    file=$(ls dMRI$i/*_dMRI$i.nii.gz | head -n 1)
    name=$(basename "$file" | sed "s/_dMRI$i\.nii\.gz//")

    echo "Detected name: $name"

    fslroi dMRI$i/${name}_dMRI$i.nii.gz dMRI$i/${name}_dMRI${i}_b0.nii.gz 0 1

    mkdir -p dMRI$i/manual_registration
done
