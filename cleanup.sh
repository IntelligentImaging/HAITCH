#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [input protocol HAITCH directory]
    Incorrect input supplied
EOF
}

if [[ $# -ne 1 || ! -d $1 ]] ; then
    show_help
    exit
fi 


prot=$1
for OUTPATHSUB in ${prot}/*/*/*run* ; do
	echo cleaning big files from $OUTPATHSUB

	# Step folder locations
	PRPROCESSING_DIR=${OUTPATHSUB}/preprocessing
	SEGMENTATION_DIR=${OUTPATHSUB}/segmentation
	SEGM_POST_DC_DIR=${OUTPATHSUB}/segmentation/PostDC
	DISTORTIONCO_DIR=${OUTPATHSUB}/distortion
	MOTIONCORREC_DIR=${OUTPATHSUB}/motion
	REGISTRATION_DIR=${OUTPATHSUB}/registrationtoT2w
	T2WXFM_FILES_DIR=${OUTPATHSUB}/T2WXFM
	SLICEWEIGHTS_DIR=${OUTPATHSUB}/sliceweights
	TENFOD_TRACT_DIR=${OUTPATHSUB}/fod_tracts
	OUTPUT_FILES_DIR=${OUTPATHSUB}/output
	QUAL_CONTROL_DIR=${OUTPATHSUB}/qualitycontrol
	RESULTS_SATS_DIR=${OUTPATHSUB}/results


	rm -v ${PRPROCESSING_DIR}/dwiLowBval.mif
	rm -v ${PRPROCESSING_DIR}/dwidenoise_residuals.mif
	rm -v ${PRPROCESSING_DIR}/dwitmp.mif
	rm -v ${PRPROCESSING_DIR}/spred.mif
	rm -v ${PRPROCESSING_DIR}/spred_xfm.mif
	rm -v ${PRPROCESSING_DIR}/spred_xfm_sk_pervolume.mif

	tmpspreds=`find ${MOTIONCORREC_DIR} -maxdepth 1 -name spred\?.nii.gz | sort | head -n -1`
	for f in $tmpspreds ; do rm -v $f ; done
	tmpworking=`find ${MOTIONCORREC_DIR} -maxdepth 1 -name working_updated\?.nii.gz | sort | head -n -1`
	for f in $tmpworking ; do rm -v $f ; done

	rm -v ${MOTIONCORREC_DIR}/registration_iter?/*.nii.gz
	rm -v ${SEGMENTATION_DIR}/working_TE*_v?.nii.gz ${SEGMENTATION_DIR}/working_TE*_v??.nii.gz

	tmpweights=`find ${SLICEWEIGHTS_DIR} -maxdepth 1 -name fvoxelweights_shore_\?.nii.gz | sort | head -n -1`
	for f in $tmpweights ; do rm -v $f ; done

	rm -rfv ${TENFOD_TRACT_DIR}/seg_tmp


done
