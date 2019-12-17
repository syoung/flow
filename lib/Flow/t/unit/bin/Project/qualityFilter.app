---
appname: qualityFilter
description: ''
location: /work/node/stephane/depot/bin/bamtools
parameters:
  -
    ordinal: 1
    value: filter
    valuetype: string
  -
    argument: -mapQuality
    ordinal: 2
    value: '">=60"'
    valuetype: string
  -
    argument: -in
    ordinal: 3
    value: ${sample}_N_rmdup_grp.bam
    valuetype: string
  -
    argument: -out
    ordinal: 4
    value: ${sample}_N_rmdup_grp_rmlq.bam
    valuetype: string
