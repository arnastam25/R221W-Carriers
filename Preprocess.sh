for subj in $(seq -w 1 22); do
    echo "=== Processing subject ${subj} ==="

    cd "${subj}" || { echo "Folder ${subj} not found, skipping."; continue; }

    # Convert DWI to .mif
    mrconvert *.nii.gz -fslgrad bvecs bvals dwi.mif

    # DWI Denoising
    dwidenoise dwi.mif out.mif -noise noise.mif

    # DWI Gibbs correction (de-ringing)
    mrdegibbs out.mif gibbs_cor.mif

    # Convert corrected image back to NIfTI
    mrconvert gibbs_cor.mif de_ringed.nii.gz

    # B0 Extraction
    fslroi de_ringed.nii.gz b0.nii.gz 0 1

    # Top-up
    topup --imain=b0_all.nii.gz --datain=acqparams.txt --config=b02b0.cnf --out=my_output

    applytopup --imain=de_ringed.nii.gz --inindex=1 \
        --datain=acqparams.txt --topup=my_output --method=jac --out=AP_Cor

    # DWI Distortion Correction (Eddy corrected)
    fslroi AP_Cor.nii.gz AP_1stVol 0 1
    bet AP_1stVol.nii.gz AP_brain -m -f 0.2

    # Create index.txt
    rm -f index.txt
    nvols=$(fslval AP_Cor dim4)
    for ((i=1; i<=nvols; i++)); do echo "1"; done > index.txt

    eddy --imain=AP_Cor.nii.gz --mask=AP_brain_mask.nii.gz \
        --index=index.txt --acqp=acqparams.txt --bvecs=bvecs --bvals=bvals \
        --fwhm=0 --flm=quadratic --out=AP_eddy_unwarped --data_is_shelled

    cd ..

    echo "=== Done with subject ${subj} ==="
done