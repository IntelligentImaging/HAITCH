#!/bin/bash
set -euo pipefail

###############################################
# USER SETTINGS
###############################################
MAINPATH="/fileserver/davood-ds923/chd/data"
QC_DELETED="/fileserver/davood-ds923/chd/protocols/qc_dmri_deleted"

# Choose visit year here: 2023 or 2024
YEAR_FILTER="20"

# Target voxel size for NeSVoR regrid
# Set this to match your dMRI voxel size as needed
TARGET_VOX="2"

###############################################
# OUTPUT CSV
###############################################
OUTCSV="dmri_match_summaryDec10_${YEAR_FILTER}.csv"
echo "subject,visit,n_runs_used" > "$OUTCSV"

shopt -s nullglob

###############################################
# PASS 1 – APPLY NeSVoR TRANSFORMS ONTO DWI GRID
###############################################
echo "=== Applying NeSVoR transforms for YEAR=${YEAR_FILTER} ==="

for NESVOR_DIR in "$MAINPATH"/*/*/NeSVoR_output; do
    [[ -d "$NESVOR_DIR" ]] || continue

    BASE_DIR="$(dirname "$NESVOR_DIR")"        # /.../subject/visit
    VISIT="$(basename "$BASE_DIR")"           # e.g. 6146148_20240711

    # Filter by year
    [[ "$VISIT" == *"${YEAR_FILTER}"* ]] || continue

    TEMPLATE_RAW="${NESVOR_DIR}/volume.nii.gz"
    if [[ ! -f "$TEMPLATE_RAW" ]]; then
        echo "No volume.nii.gz in $NESVOR_DIR, skipping"
        continue
    fi

    # Regridded NeSVoR template with diffusion like voxels
    TEMPLATE="${NESVOR_DIR}/volume_dwiGrid_${TARGET_VOX}mm.mif"
    if [[ ! -f "$TEMPLATE" ]]; then
        echo ""
        echo ">> Visit: $VISIT"
        echo "   Creating NeSVoR dwiGrid template: $TEMPLATE (voxel=${TARGET_VOX} mm)"
        mrgrid "$TEMPLATE_RAW" regrid "$TEMPLATE" -voxel "$TARGET_VOX" -force
    else
        echo ""
        echo ">> Visit: $VISIT"
        echo "   Using existing NeSVoR dwiGrid template: $TEMPLATE"
    fi

    # Loop over transforms tfm_dMRI*.txt
    for TFM_TXT in "$NESVOR_DIR"/tfm_dMRI*.txt; do
        [[ -f "$TFM_TXT" ]] || continue

        BASE_TFM="$(basename "$TFM_TXT")"      # tfm_dMRI1.txt
        RUN="${BASE_TFM%.txt}"                 # tfm_dMRI1
        RUN="${RUN#tfm_}"                      # dMRI1

        DWI_IN="$BASE_DIR/$RUN/preprocessing/dwirc.mif"
        DWI_OUT="$BASE_DIR/$RUN/preprocessing/dwirc_neSVoR_dwiGrid.mif"

        
        if [[ ! -f "$DWI_IN" ]]; then
            echo "  Missing $DWI_IN, skip $RUN"
            continue
        fi

        MAT_AFF="$NESVOR_DIR/${RUN}.mat"
        MAT_RIG="$NESVOR_DIR/${RUN}_rigid.mat"

        echo "  - Processing $RUN"
        echo "      Transform txt: $TFM_TXT"

        # Convert txt to affine mat
        transformconvert "$TFM_TXT" itk_import "$MAT_AFF" -force

        # Extract rigid component
        transformcalc "$MAT_AFF" rigid "$MAT_RIG" -force

        # Apply rigid transform to dwirc.mif onto NeSVoR dwiGrid template
        mrtransform "$DWI_IN" "$DWI_OUT" \
            -template "$TEMPLATE" \
            -linear "$MAT_RIG" \
            -force
    done
done

###############################################
# PASS 2 – CONCATENATION WITHOUT SIZE CHECKING
###############################################
echo ""
echo "=== Running dwicat concatenation for YEAR=${YEAR_FILTER} ==="

for SUBJECT in "$MAINPATH"/*; do
    [[ -d "$SUBJECT" ]] || continue
    SUBJ_ID="$(basename "$SUBJECT")"         # e.g. 6146148

    for VISIT_DIR in "$SUBJECT"/*; do
        [[ -d "$VISIT_DIR" ]] || continue
        VIS="$(basename "$VISIT_DIR")"       # e.g. 6146148_20240711

        # Filter by year
        [[ "$VIS" == *"${YEAR_FILTER}"* ]] || continue

        # FILES=()
        # TOTAL_RUNS=0

        # # Collect all registered dwirc_neSVoR_dwiGrid.mif for this visit
        # for MIF in "$VISIT_DIR"/dMRI*/preprocessing/dwirc_neSVoR_dwiGrid.mif; do

        #     [[ -f "$MIF" ]] || continue

        #     NSIZE4=$(mrinfo -size "$MIF" -quiet | awk '{print $4}')

        #     # Skip if 4th dimension is 186 # normally, it should be because it has second echo, but I need more code here to check the bval and bvec to get the number of TE
        #     if [[ "$NSIZE4" == 186 ]]; then
        #         echo "Skipping $MIF (4th dimension = 186)"
        #         continue
        #     fi

        #     TOTAL_RUNS=$((TOTAL_RUNS + 1))

        #     MOD="$(basename "$(dirname "$(dirname "$MIF")")")"   # dMRI1, dMRI2, ...

        #     # QC deleted PNG name: <subject>_<visit>_<dMRIx>_vol0.png
        #     PNG="${QC_DELETED}/${SUBJ_ID}_${VIS}_${MOD}_vol0.png"
        #     if [[ -f "$PNG" ]]; then
        #         echo "Skipping QC deleted: ${SUBJ_ID}/${VIS}/${MOD}"
        #         continue
        #     fi

        #     FILES+=("$MIF")
        # done

        FILES=()
        TOTAL_RUNS=0

        # First pass: check if any run has 186 volumes
        HAS_186=0
        for MIF in "$VISIT_DIR"/dMRI*/preprocessing/dwirc_neSVoR_dwiGrid.mif; do
            [[ -f "$MIF" ]] || continue
            NSIZE4=$(mrinfo -size "$MIF" -quiet | awk '{print $4}')
            if [[ "$NSIZE4" == 186 ]]; then
                HAS_186=1
                break
            fi
        done

        # Second pass: collect files
        for MIF in "$VISIT_DIR"/dMRI*/preprocessing/dwirc_neSVoR_dwiGrid.mif; do
            [[ -f "$MIF" ]] || continue

            NSIZE4=$(mrinfo -size "$MIF" -quiet | awk '{print $4}')

            # If any 186 exists in this visit: select ONLY 186
            if (( HAS_186 == 1 )) && [[ "$NSIZE4" != 186 ]]; then
                continue
            fi

            TOTAL_RUNS=$((TOTAL_RUNS + 1))

            MOD="$(basename "$(dirname "$(dirname "$MIF")")")"   # dMRI1, dMRI2, ...

            PNG="${QC_DELETED}/${SUBJ_ID}_${VIS}_${MOD}_vol0.png"
            if [[ -f "$PNG" ]]; then
                echo "Skipping QC deleted: ${SUBJ_ID}/${VIS}/${MOD}"
                continue
            fi

            FILES+=("$MIF")
        done



        NUM_FILES=${#FILES[@]}
        if (( NUM_FILES == 0 )); then
            continue
        fi

        echo "${SUBJ_ID},${VIS},${NUM_FILES}" >> "$OUTCSV"

        DMRI_DIR="${VISIT_DIR}/dMRI567"
        CONCAT_DIR="${DMRI_DIR}/preprocessing"
        mkdir -p "$CONCAT_DIR"

        OUT_MIF="${CONCAT_DIR}/dwirc.mif"
        NESVOR_DIR="${VISIT_DIR}/NeSVoR_output"

        ###########################################
        # Single run – no concat
        ###########################################
        if (( NUM_FILES == 1 )); then
            SINGLE="${FILES[0]}"
            echo ""
            echo ">>> Visit ${VIS}: only one usable run"
            echo "    Source: $SINGLE"
            echo "    Output: $OUT_MIF"

            mrconvert "$SINGLE" "$OUT_MIF" -force

            mrconvert "$OUT_MIF" \
                "${DMRI_DIR}/${VIS}_dMRI567.nii.gz" \
                -stride -1,2,3,4 \
                -export_grad_fsl "${DMRI_DIR}/${VIS}_dMRI567.bvec" "${DMRI_DIR}/${VIS}_dMRI567.bval" \
                -export_grad_mrtrix "${DMRI_DIR}/${VIS}_dMRI567_grad5cls_mrtrix.txt" \
                -force

            awk '{print $1, $2, $3, $4}' \
                "${DMRI_DIR}/${VIS}_dMRI567_grad5cls_mrtrix.txt" \
                > "${DMRI_DIR}/${VIS}_dMRI567.txt"

            # Copy the corresponding tfm_dMRIx.txt to dMRI567
            if [[ -d "$NESVOR_DIR" ]]; then
                RUN_MOD="$(basename "$(dirname "$(dirname "$SINGLE")")")"   # dMRIx
                TFM_SRC="${NESVOR_DIR}/tfm_${RUN_MOD}.txt"
                if [[ -f "$TFM_SRC" ]]; then
                    cp -f "$TFM_SRC" "${DMRI_DIR}/"
                else
                    echo "  Warning: no transform file $TFM_SRC for single run"
                fi
            fi

            continue
        fi

        ###########################################
        # Multiple runs – dwicat
        ###########################################
        echo ""
        echo ">>> Concatenating visit: ${VIS}"
        echo "    Runs used: ${NUM_FILES}"

        # Optional mask search stays as before
        MASK=""
        for f in "${FILES[@]}"; do
            cand="${f/preprocessing\/dwirc_neSVoR_dwiGrid.mif/segmentation/union_mask.nii.gz}"
            if [[ -f "$cand" ]]; then
                MASK="$cand"
                break
            fi
        done
        [[ -n "$MASK" ]] && echo "    Using mask: ${MASK}"

        if [[ -n "$MASK" ]]; then
            set +e
            dwicat -mask "$MASK" "${FILES[@]}" "$OUT_MIF" -force
            rc=$?
            set -e
            if [[ $rc -ne 0 ]]; then
                echo "Masked dwicat failed (status=$rc), retrying without mask"
                dwicat "${FILES[@]}" "$OUT_MIF" -force
            fi
        else
            dwicat "${FILES[@]}" "$OUT_MIF" -force
        fi

        mrconvert "$OUT_MIF" \
            "${DMRI_DIR}/${VIS}_dMRI567.nii.gz" \
            -stride -1,2,3,4 \
            -export_grad_fsl "${DMRI_DIR}/${VIS}_dMRI567.bvec" "${DMRI_DIR}/${VIS}_dMRI567.bval" \
            -export_grad_mrtrix "${DMRI_DIR}/${VIS}_dMRI567_grad5cls_mrtrix.txt" \
            -force

        awk '{print $1, $2, $3, $4}' \
            "${DMRI_DIR}/${VIS}_dMRI567_grad5cls_mrtrix.txt" \
            > "${DMRI_DIR}/${VIS}_dMRI567.txt"

        # Copy only the transforms for runs that were concatenated
        if [[ -d "$NESVOR_DIR" ]]; then
            for f in "${FILES[@]}"; do
                RUN_MOD="$(basename "$(dirname "$(dirname "$f")")")"   # dMRIx
                TFM_SRC="${NESVOR_DIR}/tfm_${RUN_MOD}.txt"
                if [[ -f "$TFM_SRC" ]]; then
                    cp -f "$TFM_SRC" "${DMRI_DIR}/"
                else
                    echo "  Warning: no transform file $TFM_SRC for concatenated run"
                fi
            done
        fi

    done
done

echo ""
echo "=== DONE ==="
echo "Summary saved to: $OUTCSV"
