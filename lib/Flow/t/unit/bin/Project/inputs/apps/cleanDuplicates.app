---
appname: cleanDuplicates
description: ''
location: rm
parameters:
  -
    ordinal: 1
    value: $cur_dir/${sample}_N_fxmt_flt.ba*
    valuetype: file
  -
    ordinal: '2'
    value: $cur_dir/${sample}_N_dup_report.txt
    valuetype: file
