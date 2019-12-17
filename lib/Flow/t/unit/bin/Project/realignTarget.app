---
appname: realignTarget
description: ''
location: /work/knode05/milanesej/GenomeAnalysisTK-2.8-1/GenomeAnalysisTK.jar
parameters:
  -
    argument: -T
    ordinal: 1
    value: RealignerTargetCreator
    valuetype: string
  -
    argument: -nt
    ordinal: 2
    value: '2'
    valuetype: integer
  -
    argument: -I
    ordinal: 3
    value: ${sample}_N_rmdup_grp_rmlq.bam
    valuetype: string
  -
    argument: -R
    ordinal: 4
    value: $ref
    valuetype: string
  -
    argument: -o
    ordinal: 5
    value: ${sample}_N_forRealign.intervals
    valuetype: string
