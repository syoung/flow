---
appname: addReadGroups
description: ''
location: /work/node/stephane/depot/picard-tools/picard-tools-1.103/AddOrReplaceReadGroups.jar
parameters:
  -
    ordinal: 1
    value: RGPL=Illumina
    valuetype: string
  -
    argument: RGLB=
    ordinal: 2
    value: BWA
    valuetype: string
  -
    argument: RGPU=
    ordinal: 3
    value: GRP1
    valuetype: string
  -
    argument: RGSM=
    ordinal: 4
    value: GP1
    valuetype: string
  -
    argument: I=
    ordinal: 5
    value: ${sample}_N_rmdup.bam
    valuetype: string
  -
    argument: O=
    ordinal: 6
    value: ${sample}_N_rmdup_grp.bam
    valuetype: string
  -
    argument: SO=
    ordinal: 7
    value: coordinate
    valuetype: string
  -
    argument: CREATE_INDEX=
    ordinal: 8
    value: 'true'
    valuetype: string
  -
    argument: VALIDATION_STRINGENCY=
    ordinal: 9
    value: SILENT
    valuetype: string
