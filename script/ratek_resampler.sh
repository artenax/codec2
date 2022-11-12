#!/bin/bash -x
# ratek_resampler.sh
# David Rowe Sep 2022
#
# Support for rate K resampler experiments see doc/ratek_resampler

CODEC2_PATH=$HOME/codec2
PATH=$PATH:$CODEC2_PATH/build_linux/src:$CODEC2_PATH/build_linux/misc
K=30
M=4096
Kst=0
Ken=29
out_dir=postfilter_out
Nb=20

# Process sample with various postfilter methods
# usage:
#   cd ~/codec2/build_linux
#   ../script/ratek_resampler.sh
function postfilter_test() {
  fullfile=$1
  filename=$(basename -- "$fullfile")
  extension="${filename##*.}"
  filename="${filename%.*}"
  mkdir -p $out_dir

  c2sim $fullfile --hpf -o - | sox -t .s16 -r 8000 -c 1 - ${out_dir}/${filename}_1_out.wav
  # TODO: uses c2sim internal Am->Hm, rather than our Octave version bypassing filtering
  c2sim $fullfile --hpf --phase0 --postfilter --dump $filename -o - | sox -t .s16 -r 8000 -c 1 - ${out_dir}/${filename}_2_p0.wav

  echo "ratek2_batch; ratek2_model_postfilter(\"${filename}\",\"${filename}_am.f32\"); quit;" \
  | octave -p ${CODEC2_PATH}/octave -qf
  c2sim $fullfile --hpf --amread ${filename}_am.f32 -o - | \
      sox -t .s16 -r 8000 -c 1 - ${out_dir}/${filename}_3_ratek.wav

  echo "ratek2_batch; ratek2_model_postfilter(\"${filename}\",\"${filename}_am.f32\",\"${filename}_hm.f32\"); quit;" \
  | octave -p ${CODEC2_PATH}/octave -qf
  c2sim $fullfile --hpf --phase0 --postfilter --amread ${filename}_am.f32 --hmread ${filename}_hm.f32 -o - | \
      sox -t .s16 -r 8000 -c 1 - ${out_dir}/${filename}_4_ratek_p0.wav

  echo "ratek2_batch; ratek2_model_postfilter(\"${filename}\",\"${filename}_am.f32\",\"\",1,0); quit;" \
  | octave -p ${CODEC2_PATH}/octave -qf
  c2sim $fullfile --hpf --amread ${filename}_am.f32 -o - | \
      sox -t .s16 -r 8000 -c 1 - ${out_dir}/${filename}_5_ratek_pf.wav

  echo "ratek2_batch; ratek2_model_postfilter(\"${filename}\",\"${filename}_am.f32\",\"${filename}_hm.f32\",0,1); quit;" \
  | octave -p ${CODEC2_PATH}/octave -qf
  c2sim $fullfile --hpf --phase0 --postfilter --amread ${filename}_am.f32 --hmread ${filename}_hm.f32 -o - | \
      sox -t .s16 -r 8000 -c 1 - ${out_dir}/${filename}_6_ratek_p0_pf.wav

  echo "ratek2_batch; ratek2_model_postfilter(\"${filename}\",\"${filename}_am.f32\",\"${filename}_hm.f32\",1,1); quit;" \
  | octave -p ${CODEC2_PATH}/octave -qf
  c2sim $fullfile --hpf --phase0 --postfilter --amread ${filename}_am.f32 --hmread ${filename}_hm.f32 -o - | \
      sox -t .s16 -r 8000 -c 1 - ${out_dir}/${filename}_7_ratek_pf_p0_pf.wav

  c2enc 3200 $fullfile - | c2dec 3200 - - | sox -t .s16 -r 8000 -c 1 - ${out_dir}/${filename}_8_3200.wav
}

# Process sample with various methods including 1 and 2 stage VQ
# usage:
#   cd ~/codec2/build_linux
#   ../script/ratek_resampler.sh
function vq_test() {
  fullfile=$1
  filename=$(basename -- "$fullfile")
  extension="${filename##*.}"
  filename="${filename%.*}"
  mkdir -p $out_dir

  c2sim $fullfile --hpf --phase0 --postfilter --dump $filename -o - | sox -t .s16 -r 8000 -c 1 - ${out_dir}/${filename}_1_out.wav
  echo "ratek2_batch;  ratek2_model_to_ratek(\"${filename}\",${Nb},30,'','','',\"${filename}_novq.f32\"); quit;" \
  | octave -p ${CODEC2_PATH}/octave -qf
  c2sim $fullfile --hpf --phase0 --postfilter --amread ${filename}_novq.f32 -o - | \
      sox -t .s16 -r 8000 -c 1 - ${out_dir}/${filename}_2_novq.wav
  echo "ratek2_batch;  ratek2_model_to_ratek(\"${filename}\",${Nb},30,'','vq_stage1.f32','',\"${filename}_vq1.f32\"); quit;" \
  | octave -p ${CODEC2_PATH}/octave -qf
  c2sim $fullfile --hpf --phase0 --postfilter --amread ${filename}_vq1.f32 -o - | \
      sox -t .s16 -r 8000 -c 1 - ${out_dir}/${filename}_3_vq1.wav
  echo "ratek2_batch;  ratek2_model_to_ratek(\"${filename}\",${Nb},30,'','vq_stage1.f32','vq_stage2.f32',\"${filename}_vq2.f32\"); quit;" \
  | octave -p ${CODEC2_PATH}/octave -qf
  c2sim $fullfile --hpf --phase0 --postfilter --amread ${filename}_vq2.f32 -o - | \
      sox -t .s16 -r 8000 -c 1 - ${out_dir}/${filename}_4_vq2.wav
  c2enc 3200 $fullfile - | c2dec 3200 - - | sox -t .s16 -r 8000 -c 1 - ${out_dir}/${filename}_5_3200.wav
  #TODO consider SSB simulation, codec 2 1200, 700C
}

# usage:
#   cd ~/codec2/build_linux
#   ../script/ratek_resampler.sh
function vq_test1() {
  fullfile=$1
  filename=$(basename -- "$fullfile")
  extension="${filename##*.}"
  filename="${filename%.*}"

  c2sim $fullfile --hpf --dump $filename
  echo "ratek2_batch;  ratek2_model_to_ratek(\"../build_linux/${filename}\",20,30,\"${filename}.f32\"); quit;" \
  | octave -p ${CODEC2_PATH}/octave -qf
  extract -t $K -s $Kst -e $Ken --removemean --writeall ${filename}.f32 ${filename}_nomean.f32
  cat ${filename}_nomean.f32 | vq_mbest --mbest 5 -k $K -q vq_stage1.f32,vq_stage2.f32 >> /dev/null
}

# usage: see ratek2_batch.m
function train_kmeans() {
  fullfile=$1
  filename=$(basename -- "$fullfile")
  extension="${filename##*.}"
  filename="${filename%.*}"

  # remove mean, train 2 stages - kmeans
  extract -t $K -s $Kst -e $Ken --lower 10 --removemean --writeall $fullfile ${filename}_nomean.f32
  vqtrain ${filename}_nomean.f32 $K $M  --st $Kst --en $Ken -s 1e-3 vq_stage1.f32 -r res1.f32 > kmeans_res1.txt
  vqtrain res1.f32 $K $M  --st $Kst --en $Ken  -s 1e-3 vq_stage2.f32 -r res2.f32 > kmeans_res2.txt
}

# comparing kmeans to lbg

function train_kmeans_lbg() {
  fullfile=$1
  filename=$(basename -- "$fullfile")
  extension="${filename##*.}"
  filename="${filename%.*}"

  # remove mean, train 2 stages - kmeans
  extract -t $K -s $Kst -e $Ken --removemean --writeall $fullfile ${filename}_nomean.f32
  vqtrain ${filename}_nomean.f32 $K $M  --st $Kst --en $Ken -s 1e-3 vq_stage1.f32 -r res1.f32 > kmeans_res1.txt
  vqtrain res1.f32 $K $M  --st $Kst --en $Ken  -s 1e-3 vq_stage2.f32 -r res2.f32 > kmeans_res2.txt

  # remove mean, train 2 stages - LBG
  extract -t $K -s $Kst -e $Ken --removemean --writeall $fullfile ${filename}_nomean.f32
  vqtrain ${filename}_nomean.f32 $K $M  --st $Kst --en $Ken -s 1e-3 vq_stage1.f32 -r res1.f32 --split > lbg_res1.txt
  vqtrain res1.f32 $K $M  --st $Kst --en $Ken  -s 1e-3 vq_stage2.f32 -r res2.f32 --split > lbg_res2.txt
  cat ${filename}_nomean.f32 | vq_mbest --mbest 5 -k $K -q vq_stage1.f32,vq_stage2.f32 >> /dev/null

  echo "kmeans1=load('kmeans_res1.txt'); kmeans2=load('kmeans_res2.txt'); \
        lbg1=load('lbg_res1.txt'); lbg2=load('lbg_res2.txt'); \
        hold on; \
        plot(log2(kmeans1(:,1)),kmeans1(:,2),'+-','markersize', 15); plot(log2(kmeans2(:,1)),kmeans2(:,2),'+-','markersize', 15); \
        plot(log2(lbg1(:,1)),lbg1(:,2),'+-'); plot(log2(lbg2(:,1)),lbg2(:,2),'+-'); \
        hold off; \
        leg = {'kmeans stage1','kmeans stage2','lbg stage1','lbg stage2'}; \
        h = legend(leg); legend('boxoff'); \
        set(gca, 'FontSize', 16); set (h, 'fontsize', 16);
        xlabel('Bits'); ylabel('Eq dB^2'); grid; \
        print(\"${filename}_vq.png\",'-dpng','-S500,500'); \
        quit" | octave  -qf
}

# Try training with two different Nb
function train_Nb() {
  fullfile1=$1
  filename1=$(basename -- "$fullfile1")
  extension1="${filename1##*.}"
  filename1="${filename1%.*}"

  fullfile2=$2
  filename2=$(basename -- "$fullfile2")
  extension2="${filename2##*.}"
  filename2="${filename2%.*}"

  Nb1=$3
  Nb2=$4

  # remove mean, train 2 stages - LBG
  extract -t $K -s $Kst -e $Ken --removemean --writeall $fullfile1 ${filename1}_nomean.f32
  vqtrain ${filename1}_nomean.f32 $K $M  --st $Kst --en $Ken -s 1e-3 vq_stage1.f32 -r res1.f32 --split > lbg_res1.txt
  vqtrain res1.f32 $K $M  --st $Kst --en $Ken  -s 1e-3 vq_stage2.f32 -r res2.f32 --split > lbg_res2.txt

  extract -t $K -s $Kst -e $Ken --removemean --writeall $fullfile2 ${filename2}_nomean.f32
  vqtrain ${filename2}_nomean.f32 $K $M  --st $Kst --en $Ken -s 1e-3 vq_stage1.f32 -r res1.f32 --split > lbg_res3.txt
  vqtrain res1.f32 $K $M  --st $Kst --en $Ken  -s 1e-3 vq_stage2.f32 -r res2.f32 --split > lbg_res4.txt

  echo "lbg1=load('lbg_res1.txt'); lbg2=load('lbg_res2.txt'); \
        lbg3=load('lbg_res3.txt'); lbg4=load('lbg_res4.txt'); \
        hold on; \
        plot(log2(lbg1(:,1)),lbg1(:,2),'+-'); plot(log2(lbg2(:,1)),lbg2(:,2),'+-'); \
        plot(log2(lbg3(:,1)),lbg3(:,2),'o-'); plot(log2(lbg4(:,1)),lbg4(:,2),'o-'); \
        hold off; \
        leg = {'Nb=${Nb1} stage1','Nb=${Nb1} stage2','Nb=${Nb2} stage1','Nb=${Nb2} stage2'}; \
        h = legend(leg); legend('boxoff'); \
        set(gca, 'FontSize', 16); set (h, 'fontsize', 16);
        xlabel('Bits'); ylabel('Eq dB^2'); grid; \
        print(\"${Nb1}_${Nb2}_vq.png\",'-dpng','-S500,500'); \
        quit" | octave  -qf
}

# TODO: make these selectable via CLI
postfilter_test ../raw/big_dog.raw
postfilter_test ../raw/hts1a.raw
postfilter_test ../raw/two_lines.raw

#test $1

#train_kmeans $1

#../script/ratek_resampler.sh ../octave/train_120_Nb20_K30.f32
#train_kmeans_lbg $1

# ../script/ratek_resampler.sh ../octave/train_120_Nb20_K30.f32 ../octave/train_120_Nb100_K30.f32 20 100
#train_Nb $1 $2 $3 $4
