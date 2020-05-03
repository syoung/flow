README

Flow: A generic, cloud-enabled workflow tool.

For detailed information on how to use flow and its many capabilities, browse to: www.aguadev.org

For installation instructions, see the accompanying INSTALL.md file.

USAGE:

    APPLICATION

        flow

    PURPOSE

        Create, run and monitor workflows

    USAGE: flow <subcommand> [switch] [Options] [--help]

     subcommand   String :

          list                 List all projects and contained workflows
          addproject|addp      Add a new project
          deleteproject|delp   Delete a project
          addworkflow|addw     Add a workflow to an existing project
          deleteworkflow|delw  Delete a workflow from a project
          addapp|adda          Add an application to a workflow in an existing project
          deleteapp|dela       Delete an application from a workflow

     package      String :    Name of package to install

     Options:

       subcommand     :    Type of workflow object (work|app|param)
       switch   :    Nested object (e.g., work app, app param)
       args     :    Arguments for the selected subcommand
       --help   :    print help info

    EXAMPLES

     # Add project to database 
     flow addproject Project1  
 
     # Add workflow 'Workflow1' file to project 'Project1'  
     flow addworkflow Project1 ./workflow1.wrk  
 
     # Create a workflow file with a specified name
     ./flow work create --wkfile /workflows/workflowOne.wk --name workflowOne
 
     # Add an application to workflow file
     ./flow work addapp --wkfile /workflows/workflowOne.wk --appfile /workflows/applicationOne.app --name applicationOne
 
     # Run a single application in a workflow
     ./flow work app run --wkfile /workflows/workflowOne.wk --name applicationOne
 
     # Run all applications in workflow
     ./flow work run --wkfile /workflows/workflowOne.wk 
 
     # Create an application file from a file containing the application run command
     ./flow app loadCmd --cmdfile /workflows/applicationOne.cmd --appfile /workflows/applicationOne.app --name applicationOne




