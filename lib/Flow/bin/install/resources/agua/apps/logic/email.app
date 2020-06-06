---
description: 'Send email to recipient with specified subject and message body'
installdir: /a
location: bin/logic/email
name: email
owner: agua
package: dnaseq
version: 0.0.1
type: qc
url: www.github.com/agua/dnaseq
parameters:
  -
    argument: --username
    description: 'Sending email account username (i.e., myusername NOT myusername@gmail.com). Will source from config file if not provided'
    discretion: optional
    param: username
    value: ""
    valuetype: string
  -
    argument: --password
    description: 'Account password. Will source from config file if not provided'
    discretion: optional
    param: password
    value: ""
    valuetype: string
  -
    argument: --to
    description: 'Recipient email address'
    discretion: required
    param: to
    value: "aguanoreply@gmail.com"
    valuetype: string
  -
    argument: --from
    description: 'Displayed name of sender'
    discretion: required
    param: from
    value: "aguanoreply@gmail.com"
    valuetype: string
  -
    argument: --subject
    description: 'Subject/title of email'
    discretion: required
    param: subject
    value: "Sample %SAMPLE% failed to pass FastQC [%USERNAME%:%PROJECT%:%WORKFLOW%|continue:%STAGENUMBER%]"
    valuetype: string
  -
    argument: --message
    description: 'Message body/content of email'
    discretion: required
    param: message
    value: 'Processing of sample %SAMPLE% in workflow '%PROJECT%:%WORKFLOW%' stopped at stage %STAGENUMBER%: %STAGE%.

Host: %HOSTNAME%

Check the following files to troubleshoot:

Filetype  Location
STDOUT    /home/%USERNAME%/agua/%PROJECT%/%WORKFLOW%/%STAGE%/stdout/%SAMPLE%.*.stdout
STDERR    /home/%USERNAME%/agua/%PROJECT%/%WORKFLOW%/%STAGE%/stdout/%SAMPLE%.*.stderr

If you want to continue processing sample %SAMPLE%, reply to this message with the word "Continue" as the first line of the message body'
    valuetype: string
  -
    argument: --project
    description: 'Project name. Will source from PROJECT environment variable if not provided'
    discretion: optional
    param: project
    value: "%PROJECT%"
    valuetype: string
  -
    argument: --workflow
    description: 'Project name. Will source from WORKFLOW environment variable if not provided'
    discretion: optional
    param: workflow
    value: "%WORKFLOW%"
    valuetype: string
  -
    argument: --stagenumber
    description: 'Stage number. Will source from STAGENUMBER environment variable if not provided'
    discretion: optional
    param: stagenumber
    value: "%STAGENUMBER%"
    valuetype: string
  -
    argument: --stage
    description: 'Stage name. Will source from STAGE environment variable if not provided'
    discretion: optional
    param: stage
    value: "%STAGE%"
    valuetype: string
  -
    argument: --sample
    description: 'Sample ID. Will source from SAMPLE environment variable if not provided'
    discretion: optional
    param: sample
    value: "%SAMPLE%"
    valuetype: string
