#!/bin/bash -e

##########################################################################
##                                                                      ##
##  Part of Fetal and Neonatal Development Imaging Toolbox (FEDI)       ##
##                                                                      ##
##                                                                      ##
##  Author:    Haykel Snoussi, PhD (dr.haykel.snoussi@gmail.com)        ##
##             IMAGINE Group | Computational Radiology Laboratory       ##
##             Boston Children's Hospital | Harvard Medical School      ##
##                                                                      ##
##########################################################################
# ./dMRI_conversion.sh

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [project directory]
    This script starts the FEDI pipeline. Supply the project directory.
    data, protocols, and scripts directories specified in script.

    -i LIST.txt Specify an input text list of input data folder run paths (data/sub-x/sx/dwi/runx)
    -l			Ignore any existing locks		

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
        -i|--inputs)
            if [[ -f "$2" ]] ; then
                INLIST=$2 # Specify input scan list
                shift
            else
                die 'error: input scan list not found'
            fi
            ;;
		-l|--ignore-locks)
	    	let NOLOCKS=1
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

if [ $# -ne 1 ]; then
    show_help
    exit
fi

if [ ! -d $1 ] ; then
	die "error: $1 is not a directory"
fi

# Set project-specific variables
PROTOCOL="HAITCH"
PROJDIR=`readlink -f $1`

INPATH="${PROJDIR}/data" # path of data
OUTPATH="${PROJDIR}/protocols" # path of output
export DMRISCRIPTS=`dirname ${0}` # path of scripts

# Set Defaults for optionals
if [[ ! $NOLOCKS = 1 ]] ; then let NOLOCKS=0 ; fi

# MODALITY=dwi # ie, "*" , "dwi", "dwiHARDI" or "dwiME" # HARDI only (at least 2 bvalues, we can go by any number of directions) or dMRI_ME


# Assign all run directories to processing list, or use the supplied input text file
# INPATH is the "data" folder with converted data
if [[ ! -n $INLIST ]] ; then
  echo "Locating runs"
	#ALLRUNS=`find ${INPATH} -mindepth 4 -maxdepth 4 -type d -name run\*`
	readarray -d '' ALLRUNS < <(find ${INPATH} -mindepth 4 -maxdepth 4 -type d -name run\* -print0) # searches for the run (dwi data) directories and puts them into an array
else
	#ALLRUNS=$(cat $INLIST)
	while IFS=',' read -ra array ; do
		ALLRUNS+=("${array[0]}") # Uses the input csv to make an array of all runs to process
		T2_RECON_METHOD_ar+=("${array[1]}") # Array of which T2w reconstruction to use as the registration target
		REGSTRAT_ar+=("${array[2]}") # Array of which registration program to use
	done < $INLIST
fi

let xcount=0
for RUNDIR in ${ALLRUNS[@]} ; do
	# Match t2 recon and registration methods to current csv row
	export T2W_RECON_METHOD=${T2_RECON_METHOD_ar[$xcount]}
	export REGSTRAT=${REGSTRAT_ar[$xcount]}
	((xcount++)) # increment array

	if [ -d $RUNDIR ] ; then

		# Set the scan data paths and identifiers
		NOTRAILSLASH=${RUNDIR%/}
		RUNNUMBER=${NOTRAILSLASH##*/}
		MODALITYDIR=${RUNDIR%/*}
		MODALITY=${MODALITYDIR##*/}
		SESSIONDIR=${MODALITYDIR%/*}
		SESSION=${SESSIONDIR##*/}
		SUBJECTDIR=${SESSIONDIR%/*}
		SUBJECTID=${SUBJECTDIR##*/}

		case $MODALITY in
			dwi|dwiHARDI|dwiME) # dwi|dwiHARDI|dwiME (only processing diffusion)
				if [[ -e $RUNDIR/lock && ! $NOLOCKS = 1 ]] ; then

				  echo "====================================================="
				  echo "@ $SUBJECTID $RUNDIR Locked (lock in data folder)"
				  echo "@ $RUNDIR/lock"
				  echo "====================================================="

				else

					echo -e "\n\n\n"
					echo "====================================================="
					echo "====================================================="

					echo "Protocol   : $PROTOCOL"
					echo "SubjectID  : $SUBJECTID"
					echo "Session    : $SESSION"
					echo "Modality   : $MODALITY"
					echo "Run Number : $RUNNUMBER"
					echo ""

					# Creation of configuration file
					OUTPATHSUB="${OUTPATH}/${PROTOCOL}/${SUBJECTID}/${SESSION}/${MODALITY}_${RUNNUMBER}"
					mkdir -p ${OUTPATHSUB}
					FULLSUBJECTID="${SUBJECTID}_${SESSION}_${MODALITY}_${RUNNUMBER}"
					CONFIG_FILE="${OUTPATHSUB}/${PROTOCOL}_local-config_${FULLSUBJECTID}.sh"

					# Create config file
					bash ${DMRISCRIPTS}/dMRI_HAITCH_local-config.sh -d "$PROJDIR" -p "$PROTOCOL" -i "$SUBJECTID" -s "$SESSION" -m $MODALITY -r "$RUNNUMBER" -l "$NOLOCKS" -o "$CONFIG_FILE"

					# Processing data
					bash ${DMRISCRIPTS}/dMRI_HAITCH.sh "${CONFIG_FILE}"

					echo "====================================================="
					echo "====================================================="
				fi
				;;
			*)
				echo "$RUNDIR is not a diffusion data directory"
				;;
		esac

	else
		echo "$RUNDIR is not a directory"
		if [[ -n $INLIST ]] ; then echo "are the paths in $INLIST correct?" ; fi	
	fi
done
