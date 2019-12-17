---
appname: fixMate
description: ''
location: /work/node/stephane/depot/picard-tools/picard-tools-1.103/FixMateInformation.jar
parameters:
  -
    ordinal: 1
    value: I=${sample}_N_sorted.bam
    valuetype: string
  -
    argument: O=
    ordinal: 2
    value: ${sample}_N_fxmt.bam
    valuetype: string
  -
    argument: SO=
    ordinal: 3
    value: coordinate
    valuetype: string
  -
    argument: CREATE_INDEX=
    ordinal: 4
    value: 'true'
    valuetype: string
  -
    argument: VALIDATION_STRINGENCY=
    ordinal: 5
    value: SILENT
    valuetype: string
