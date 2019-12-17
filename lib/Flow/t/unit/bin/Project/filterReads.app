---
appname: filterReads
description: ''
location: /work/node/stephane/depot/bin/bamtools
parameters:
  -
    ordinal: 1
    value: filter
    valuetype: string
  -
    argument: -isMapped
    ordinal: 2
    value: 'true'
    valuetype: string
  -
    argument: -isPaired
    ordinal: 3
    value: 'true'
    valuetype: string
  -
    argument: -isProperPair
    ordinal: 4
    value: 'true'
    valuetype: string
  -
    argument: -in
    ordinal: 5
    value: ${sample}_N_fxmt.bam
    valuetype: string
  -
    argument: -out
    ordinal: 6
    value: ${sample}_N_fxmt_flt.bam
    valuetype: string
