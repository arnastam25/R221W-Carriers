sudo docker run --rm \
-v $(pwd)/INPUTS/:/INPUTS/ \
-v $(pwd)/OUTPUTS:/OUTPUTS/ \
-v /usr/local/freesurfer/7.4.1/license.txt:/extra/freesurfer/license.txt \
--user $(id -u):$(id -g) \
leonyichencai/synb0-disco:v3.0
--notopup
