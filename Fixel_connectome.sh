
TEMPLATE_DIR=../Fixel/template
CONNECTIVITY_MATRIX=${TEMPLATE_DIR}/matrix.mtx
TEMPLATE_MASK=${TEMPLATE_DIR}/template_mask.mif
TEMPLATE_FOD=${TEMPLATE_DIR}/wmfod_template.mif
FIXEL_MASK_DIR=${TEMPLATE_DIR}/fixel_mask


for subj in $(seq -w 1 22); do
    echo "Processing subject ${subj}…"
    cd "${subj}"

    # input: subject’s fixels and ROI mask
    FOD_IN_TEMPLATE=fod_in_template_space_NOT_REORIENTED.mif
    FIXEL_DIR_IN_TEMPLATE=fixel_in_template_space_NOT_REORIENTED
    ROI_MASK=ROIs_combined.mif

    # output directories
    OUT_DIR=individual_fixel_analysis
    mkdir -p ${OUT_DIR}

    # fixel mask for this subject
    SUBJECT_FIXEL_MASK=${OUT_DIR}/fixel_mask_subject

    # segment FOD in ROI only
    echo "  ➝ Segmenting FOD within ROI"
    fod2fixel -mask ${ROI_MASK} ${FOD_IN_TEMPLATE} ${SUBJECT_FIXEL_MASK} -afd afd.mif

    # reorient fixels
    echo "  ➝ Reorienting fixels"
    fixelreorient ${SUBJECT_FIXEL_MASK} subject2template_warp.mif ${OUT_DIR}/fixel_mask_subject_reoriented

    # extract fixel metric
    echo "  ➝ Extracting FD"
    cp ${OUT_DIR}/fixel_mask_subject_reoriented/afd.mif ${OUT_DIR}/fd.mif

    # statistics
    echo "  ➝ Computing mean FD"
    fixelstats ${OUT_DIR}/fixel_mask_subject_reoriented fd.mif mean > ${OUT_DIR}/fd_mean.txt

    # connectome: fixel–fixel connectivity in ROI
    echo "  ➝ Generating connectome"
    fixelconnectivity ${OUT_DIR}/fixel_mask_subject_reoriented ${TEMPLATE_DIR}/tracks_1_million_sift.tck ${OUT_DIR}/connectivity.mtx

    echo "Subject ${subj} done"
    cd ..
done

