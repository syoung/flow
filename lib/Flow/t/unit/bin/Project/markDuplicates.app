---
appname: markDuplicates
description: ''
location: /work/node/stephane/depot/picard-tools/picard-tools-1.103/MarkDuplicates.jar
parameters:
  -
    ordinal: 1
    value: I=${sample}_N_fxmt_flt.bam
    valuetype: string
  -
    argument: O=
    ordinal: 2
    value: ${sample}_N_rmdup.bam
    valuetype: string
  -
    argument: M=
    ordinal: 3
    value: ${sample}_N_dup_report.txt
    valuetype: string
  -
    argument: PROGRAM_RECORD_ID=
    ordinal: 4
    value: 'null'
    valuetype: string
  -
    argument: VALIDATION_STRINGENCY=
    ordinal: 5
    value: SILENT
    valuetype: string
  -
    argument: REMOVE_DUPLICATES=
    ordinal: 6
    value: 'true'
    valuetype: string
