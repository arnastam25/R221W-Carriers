

# Paths
GROUP_DIR="../dwinormalise"
TEMPLATE_DIR="../template"
FIXEL_DIR="../Fixel"
LOG_FC_DIR="${TEMPLATE_DIR}/log_fc"
FDC_DIR="${TEMPLATE_DIR}/fdc"
MATRIX_DIR="${TEMPLATE_DIR}/matrix"

ROI_MASK="../ROIs_combined.mif"   # <-- your ROI mask in template space


#  Global intensity normalisation
cd "${GROUP_DIR}"
dwinormalise group dwi_input/ mask_input/ dwi_output/ fa_template.mif fa_template_wm_mask.mif
cd -

# Response functions
for subj in $(seq -w 1 22); do
    cd "${subj}"
    dwi2response tournier "dwi_denoised_unringed_preproc_unbiased.mif" "response.txt"
    cd ..
done

responsemean */response.txt group_average_response.txt

# Upsample DWIs
for subj in $(seq -w 1 22); do
    cd "${subj}"
    mrgrid "dwi_denoised_unringed_preproc_unbiased.mif" regrid -vox 1.25 "dwi_unbiased_normalised_upsampled.mif"
    dwi2mask "dwi_unbiased_normalised_upsampled.mif" "dwi_mask_upsampled.mif"
    cd ..
done

# FOD estimation
for subj in $(seq -w 1 22); do
    cd "${subj}"
    dwi2fod msmt_csd \
        "dwi_unbiased_normalised_upsampled.mif" ../group_average_response.txt "wmfod.mif" \
        -mask "dwi_mask_upsampled.mif"
    cd ..
done

# Build FOD template (no change)
population_template "${TEMPLATE_DIR}/fod_input" \
    -mask_dir "${TEMPLATE_DIR}/mask_input" \
    "${TEMPLATE_DIR}/wmfod_template.mif" -voxel_size 1.25

# Register FODs
for subj in $(seq -w 1 22); do
    cd "${subj}"
    mrregister "wmfod.mif" -mask1 "dwi_mask_upsampled.mif" \
        "${TEMPLATE_DIR}/wmfod_template.mif" \
        -nl_warp "subject2template_warp.mif" "template2subject_warp.mif"
    cd ..
done

# Template mask
for subj in $(seq -w 1 22); do
    cd "${subj}"
    mrtransform "dwi_mask_upsampled.mif" -warp "subject2template_warp.mif" \
        -interp nearest -datatype bit "dwi_mask_in_template_space.mif"
    cd ..
done
mrmath */dwi_mask_in_template_space.mif min "${FIXEL_DIR}/template/template_mask.mif" -datatype bit

# Template fixel mask
fod2fixel -mask "${ROI_MASK}" -fmls_peak_value 0.10 \
    "${FIXEL_DIR}/template/wmfod_template.mif" "${FIXEL_DIR}/template/fixel_mask"

# Warp FODs & compute FD in ROI only
for subj in $(seq -w 1 22); do
    cd "${subj}"

    mrtransform "wmfod.mif" -warp "subject2template_warp.mif" -reorient_fod no "fod_in_template_space_NOT_REORIENTED.mif"

    # restrict to ROI
    fod2fixel -mask "${ROI_MASK}" \
        "fod_in_template_space_NOT_REORIENTED.mif" "fixel_in_template_space_NOT_REORIENTED" -afd fd.mif

    fixelreorient "fixel_in_template_space_NOT_REORIENTED" "subject2template_warp.mif" "fixel_in_template_space"

    fixelcorrespondence "fixel_in_template_space/fd.mif" "${FIXEL_DIR}/template/fixel_mask" "${FIXEL_DIR}/template/fd_${subj}.mif"

    warp2metric "subject2template_warp.mif" -fc "${FIXEL_DIR}/template/fixel_mask" "${FIXEL_DIR}/template/fc_${subj}.mif"

    cd ..
done

# Compute log(FC) and FDC
mkdir -p "${LOG_FC_DIR}" "${FDC_DIR}"
cp "${FIXEL_DIR}/template/fixel_mask/index.mif" "${LOG_FC_DIR}"
cp "${FIXEL_DIR}/template/fixel_mask/directions.mif" "${LOG_FC_DIR}"
cp "${FIXEL_DIR}/template/fixel_mask/index.mif" "${FDC_DIR}"
cp "${FIXEL_DIR}/template/fixel_mask/directions.mif" "${FDC_DIR}"

for subj in $(seq -w 1 22); do
    mrcalc "${FIXEL_DIR}/template/fc_${subj}.mif" -log "${LOG_FC_DIR}/${subj}.mif"
    mrcalc "${FIXEL_DIR}/template/fd_${subj}.mif" "${FIXEL_DIR}/template/fc_${subj}.mif" -mult "${FDC_DIR}/${subj}.mif"
done

# Tractography & connectome restricted to ROI
cd "${TEMPLATE_DIR}"

# Tractography seeded and masked within ROI mask
tckgen -angle 22.5 -maxlen 250 -minlen 10 -power 1.0 wmfod_template.mif \
    -seed_image "${ROI_MASK}" \
    -mask "${ROI_MASK}" \
    -select 10000000 -cutoff 0.10 tracks_10_million_ROI.tck

# SIFT to reduce to 1M streamlines
tcksift tracks_10_million_ROI.tck wmfod_template.mif tracks_1_million_sift_ROI.tck -term_number 1000000

# Build fixel–fixel connectivity matrix only for ROI fixels
fixelconnectivity "${FIXEL_DIR}/template/fixel_mask" tracks_1_million_sift_ROI.tck "${MATRIX_DIR}"

cd -

# Smooth fixel data
fixelfilter fd smooth fd_smooth -matrix "${MATRIX_DIR}"
fixelfilter log_fc smooth log_fc_smooth -matrix "${MATRIX_DIR}"
fixelfilter fdc smooth fdc_smooth -matrix "${MATRIX_DIR}"

# Stats
fixelcfestats fd_smooth/ files.txt design_matrix.txt contrast_matrix.txt "${MATRIX_DIR}" stats_fd/
fixelcfestats log_fc_smooth/ files.txt design_matrix.txt contrast_matrix.txt "${MATRIX_DIR}" stats_log_fc/
fixelcfestats fdc_smooth/ files.txt design_matrix.txt contrast_matrix.txt "${MATRIX_DIR}" stats_fdc/

