#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [-d] [-r]  -- [input protocol HAITCH directory]
    Incorrect input supplied

	-d	Remove preprocessing folder outputs:
		dwide.mif, dwigb.mif, dwirc.mif, etc (almost 500 MB for each run)
	-r	Single Run mode. Specify a single run directory instead of the project processing directory
EOF
}


die() {
    printf '%s\n' "$1" >&2
    exit 1
}
while :; do
    case $1 in
        -h|-\?|--help)
            show_help # help message
            exit
            ;;
	-r|--run)
	    let RUNMODE=1
	    ;;
        -d|--delete-pp)
	    let delprep=1
            ;;
        --) # end of optionals
            shift
            break
            ;;
        -)?*
            printf 'warning: unknown option (ignored: %s\m' "$1" >&2
            ;;
        *) # default case, no optionals
            break
    esac
    shift
done


if [[ $# -ne 1 || ! -d $1 ]] ; then
    show_help
    exit
fi 


prot=$1



if [[ $RUNMODE = 1 ]] ; then
	PATHSUBS=${prot}
else
	PATHSUBS=`find ${prot} -mindepth 3 -maxdepth 3 -type d -name \*_run_\*`
fi 

for OUTPATHSUB in "${PATHSUBS}" ; do
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


	if [[ $delprep = 1 ]] ; then
		rm -v ${PRPROCESSING_DIR}/*
	fi
	rm -v ${PRPROCESSING_DIR}/seg_tmp/*
	rm -v ${TENFOD_TRACT_DIR}/seg_tmp/*

	rm -v ${MOTIONCORREC_DIR}/spred{0,1,2,3,4}.nii.gz
	rm -v ${MOTIONCORREC_DIR}/spred?_GMM.nii.gz
	rm -v ${MOTIONCORREC_DIR}/working_updated?.nii.gz

	rm -v ${MOTIONCORREC_DIR}/registration_iter?/*
	rm -v ${SEGMENTATION_DIR}/*
	rm -v ${SEGMENTATION_DIR}/*/*

	rm -v ${SLICEWEIGHTS_DIR}/*

	rm -rfv ${TENFOD_TRACT_DIR}/seg_tmp

	rm -v ${OUTPATHSUB}/tmp/*
done
