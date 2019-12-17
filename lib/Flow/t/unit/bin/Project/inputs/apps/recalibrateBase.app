---
appname: recalibrateBase
description: ''
location: /work/knode05/milanesej/GenomeAnalysisTK-2.8-1/GenomeAnalysisTK.jar
parameters:
  -
    argument: -T
    ordinal: 1
    value: BaseRecalibrator
    valuetype: string
  -
    argument: -I
    ordinal: 2
    value: ${sample}_N_realigned.bam
    valuetype: string
  -
    argument: -R
    ordinal: 3
    value: $ref
    valuetype: string
  -
    argument: -o
    ordinal: 4
    value: ${sample}_N_recal_data.grp
    valuetype: string
  -
    argument: -knownSites
    ordinal: 5
    value: $phase_indels
    valuetype: string
  -
    argument: -knownSites
    ordinal: 6
    value: $dbsnp
    valuetype: string
  -
    argument: -knownSites
    ordinal: 7
    value: $stand_indels
    valuetype: string
