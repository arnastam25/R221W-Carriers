# Paths
GROUP_DIR="../dwinormalise"
TEMPLATE_DIR="../template"
FIXEL_DIR="../Fixel"
LOG_FC_DIR="${TEMPLATE_DIR}/log_fc"
FDC_DIR="${TEMPLATE_DIR}/fdc"
MATRIX_DIR="${TEMPLATE_DIR}/matrix"

# Step 1–3: Per-subject preprocessing
for subj in $(seq -w 1 22); do
    echo "=== Processing subject ${subj} ==="
    cd "${subj}"

    # Convert to .mif
    mrconvert "AP_eddy_unwarped.nii.gz" -fslgrad bvecs bvals "dwi_denoised_unringed_preproc.mif"

    # Brain mask
    dwi2mask "dwi_denoised_unringed_preproc.mif" "dwi_temp_mask.mif"

    # Bias field correction
    dwibiascorrect ants "dwi_denoised_unringed_preproc.mif" "dwi_denoised_unringed_preproc_unbiased.mif"

    cd ..
done

# Step 4: Global intensity normalisation
cd "${GROUP_DIR}"
dwinormalise group dwi_input/ mask_input/ dwi_output/ fa_template.mif fa_template_wm_mask.mif
cd -

# Step 5: Compute response functions
for subj in $(seq -w 1 22); do
    cd "${subj}"
    dwi2response tournier "dwi_denoised_unringed_preproc_unbiased.mif" "response.txt"
    cd ..
done

# Compute group average response
responsemean */response.txt group_average_response.txt

# Step 6: Upsample DWIs and masks
for subj in $(seq -w 1 22); do
    cd "${subj}"
    mrgrid "dwi_denoised_unringed_preproc_unbiased.mif" regrid -vox 1.25 "dwi_unbiased_normalised_upsampled.mif"
    dwi2mask "dwi_unbiased_normalised_upsampled.mif" "dwi_mask_upsampled.mif"
    cd ..
done

# Step 7: FOD estimation
for subj in $(seq -w 1 22); do
    cd "${subj}"
    dwi2fod msmt_csd \
        "dwi_unbiased_normalised_upsampled.mif" ../group_average_response.txt "wmfod.mif" \
        -mask "dwi_mask_upsampled.mif"
    cd ..
done

# Step 8: Build FOD template
population_template "${TEMPLATE_DIR}/fod_input" \
    -mask_dir "${TEMPLATE_DIR}/mask_input" \
    "${TEMPLATE_DIR}/wmfod_template.mif" -voxel_size 1.25

# Step 9: Register FODs to template
for subj in $(seq -w 1 22); do
    cd "${subj}"
    mrregister "wmfod.mif" -mask1 "dwi_mask_upsampled.mif" \
        "${TEMPLATE_DIR}/wmfod_template.mif" \
        -nl_warp "subject2template_warp.mif" "template2subject_warp.mif"
    cd ..
done

# Step 10: Template mask
for subj in $(seq -w 1 22); do
    cd "${subj}"
    mrtransform "dwi_mask_upsampled.mif" -warp "subject2template_warp.mif" \
        -interp nearest -datatype bit "dwi_mask_in_template_space.mif"
    cd ..
done
mrmath */dwi_mask_in_template_space.mif min "${FIXEL_DIR}/template/template_mask.mif" -datatype bit

# Step 11: Template fixel mask
fod2fixel -mask "${FIXEL_DIR}/template/template_mask.mif" -fmls_peak_value 0.10 \
    "${FIXEL_DIR}/template/wmfod_template.mif" "${FIXEL_DIR}/template/fixel_mask"

# Step 12: Warp FODs & compute FD
for subj in $(seq -w 1 22); do
    cd "${subj}"
    mrtransform "wmfod.mif" -warp "subject2template_warp.mif" -reorient_fod no "fod_in_template_space_NOT_REORIENTED.mif"
    fod2fixel -mask "${FIXEL_DIR}/template/template_mask.mif" \
        "fod_in_template_space_NOT_REORIENTED.mif" "fixel_in_template_space_NOT_REORIENTED" -afd fd.mif
    fixelreorient "fixel_in_template_space_NOT_REORIENTED" "subject2template_warp.mif" "fixel_in_template_space"
    fixelcorrespondence "fixel_in_template_space/fd.mif" "${FIXEL_DIR}/template/fixel_mask" "${FIXEL_DIR}/template/fd_${subj}.mif"
    warp2metric "subject2template_warp.mif" -fc "${FIXEL_DIR}/template/fixel_mask" "${FIXEL_DIR}/template/fc_${subj}.mif"
    cd ..
done

# Step 13: Compute log(FC) and FDC
mkdir -p "${LOG_FC_DIR}" "${FDC_DIR}"
cp "${FIXEL_DIR}/template/fc/index.mif" "${LOG_FC_DIR}"
cp "${FIXEL_DIR}/template/fc/directions.mif" "${LOG_FC_DIR}"
cp "${FIXEL_DIR}/template/fc/index.mif" "${FDC_DIR}"
cp "${FIXEL_DIR}/template/fc/directions.mif" "${FDC_DIR}"

for subj in $(seq -w 1 22); do
    mrcalc "${FIXEL_DIR}/template/fc_${subj}.mif" -log "${LOG_FC_DIR}/${subj}.mif"
    mrcalc "${FIXEL_DIR}/template/fd_${subj}.mif" "${FIXEL_DIR}/template/fc_${subj}.mif" -mult "${FDC_DIR}/${subj}.mif"
done

# Step 14: Tractography
cd "${TEMPLATE_DIR}"
tckgen -angle 22.5 -maxlen 250 -minlen 10 -power 1.0 wmfod_template.mif \
    -seed_image template_mask.mif -mask template_mask.mif \
    -select 10000000 -cutoff 0.10 tracks_10_million.tck

tcksift tracks_10_million.tck wmfod_template.mif tracks_1_million_sift.tck -term_number 1000000

fixelconnectivity fixel_mask/ tracks_1_million_sift.tck matrix/

# Step 15: Smooth fixel data
fixelfilter fd smooth fd_smooth -matrix matrix/
fixelfilter log_fc smooth log_fc_smooth -matrix matrix/
fixelfilter fdc smooth fdc_smooth -matrix matrix/

# Step 16: Statistics
fixelcfestats fd_smooth/ files.txt design_matrix.txt contrast_matrix.txt matrix/ stats_fd/
fixelcfestats log_fc_smooth/ files.txt design_matrix.txt contrast_matrix.txt matrix/ stats_log_fc/
fixelcfestats fdc_smooth/ files.txt design_matrix.txt contrast_matrix.txt matrix/ stats_fdc/
