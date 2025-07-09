SUBJECTS_DIR="${SUBJECTS_DIR:-$HOME/freesurfer/subjects}"
SUPP_DIR="../Supplementary_Files"

for ID in $(seq -w 1 22); do
    SUBJECT="sub-${ID}"
    echo "=== Processing ${SUBJECT} ==="

    cd "${SUBJECT}" || { echo "Folder ${SUBJECT} not found!"; exit 1; }

    #Convert raw T1 from .mif to .nii.gz
    mrconvert T1_raw.mif T1_raw.nii.gz

    #Run FreeSurfer recon-all (may take hours)
    recon-all -s "$SUBJECT" -i T1_raw.nii.gz -all

    #Map HCP-MMP1 annotations from fsaverage
    mri_surf2surf --srcsubject fsaverage --trgsubject "$SUBJECT" --hemi lh \
      --sval-annot "$SUBJECTS_DIR/fsaverage/label/lh.glasser.annot" \
      --tval "$SUBJECTS_DIR/$SUBJECT/label/lh.hcpmmp1.annot"

    mri_surf2surf --srcsubject fsaverage --trgsubject "$SUBJECT" --hemi rh \
      --sval-annot "$SUBJECTS_DIR/fsaverage/label/rh.glasser.annot" \
      --tval "$SUBJECTS_DIR/$SUBJECT/label/rh.hcpmmp1.annot"

    #Map annotations to volume & convert to .mif
    mri_aparc2aseg --old-ribbon --s "$SUBJECT" --annot hcpmmp1 --o hcpmmp1.mgz

    mrconvert -datatype uint32 hcpmmp1.mgz hcpmmp1.mif

    #Relabel parcels to ordered integers
    labelconvert hcpmmp1.mif \
      "${SUPP_DIR}/hcpmmp1_original.txt" \
      "${SUPP_DIR}/hcpmmp1_ordered.txt" \
      hcpmmp1_parcels_nocoreg.mif

    #Coregister atlas-based parcellation to diffusion space
    mrtransform hcpmmp1_parcels_nocoreg.mif \
      -linear diff2struct_mrtrix.txt \
      -inverse -datatype uint32 \
      hcpmmp1_parcels_coreg.mif

    echo "=== Done with ${SUBJECT} ==="
    cd ..
done
