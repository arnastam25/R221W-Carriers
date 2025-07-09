
for subj in $(seq -w 1 22); do
    echo "Processing subject ${subj}…"
    cd "${subj}"

    PARC=hcpmmp1_parcels_coreg.mif

    # MCC
    mrcalc $PARC 40 -eq 40.mif -datatype bit
    mrcalc $PARC 41 -eq 41.mif -datatype bit
    mrcalc 40.mif 41.mif -max MCC_L.mif

    mrcalc $PARC 220 -eq 220.mif -datatype bit
    mrcalc $PARC 221 -eq 221.mif -datatype bit
    mrcalc 220.mif 221.mif -max MCC_R.mif

    mrcalc MCC_L.mif MCC_R.mif -max MCC.mif

    # Anterior insula
    mrcalc $PARC 112 -eq 112.mif -datatype bit
    mrcalc $PARC 109 -eq 109.mif -datatype bit
    mrcalc 112.mif 109.mif -max AI_L.mif

    mrcalc $PARC 292 -eq 292.mif -datatype bit
    mrcalc $PARC 289 -eq 289.mif -datatype bit
    mrcalc 292.mif 289.mif -max AI_R.mif

    mrcalc AI_L.mif AI_R.mif -max AI.mif

    mrcalc MCC.mif AI.mif -max MCC_AI.mif

    # Primary somatosensory cortex (S1)
    mrcalc $PARC 1 -eq S1_L.mif -datatype bit
    mrcalc $PARC 201 -eq S1_R.mif -datatype bit
    mrcalc S1_L.mif S1_R.mif -max S1.mif

    # Secondary somatosensory cortex (S2)
    mrcalc $PARC 2 -eq S2_L.mif -datatype bit
    mrcalc $PARC 202 -eq S2_R.mif -datatype bit
    mrcalc S2_L.mif S2_R.mif -max S2.mif

    # Anterior cingulate cortex (ACC)
    mrcalc $PARC 30 -eq ACC_L.mif -datatype bit
    mrcalc $PARC 210 -eq ACC_R.mif -datatype bit
    mrcalc ACC_L.mif ACC_R.mif -max ACC.mif

    # Thalamus
    mrconvert aseg.mgz aseg.mif
    mrcalc aseg.mif 10 -eq Thal_L.mif -datatype bit
    mrcalc aseg.mif 49 -eq Thal_R.mif -datatype bit
    mrcalc Thal_L.mif Thal_R.mif -max Thalamus.mif

    # Brainstem
    mrcalc aseg.mif 16 -eq Brainstem.mif -datatype bit

    # Combine all into one mask
    mrcalc MCC_AI.mif S1.mif -max temp1.mif
    mrcalc temp1.mif S2.mif -max temp2.mif
    mrcalc temp2.mif ACC.mif -max temp3.mif
    mrcalc temp3.mif Thalamus.mif -max temp4.mif
    mrcalc temp4.mif Brainstem.mif -max ROIs_combined.mif

    rm temp*.mif
    echo "Done with subject ${subj}"

    cd ..
done
