---
appname: cleanRealign
description: ''
location: rm
parameters:
  -
    ordinal: 1
    value: $cur_dir/${sample}_N_rmdup_grp_rmlq.ba*
    valuetype: file
  -
    ordinal: '2'
    value: $cur_dir/${sample}_N_forRealign.intervals
    valuetype: file
