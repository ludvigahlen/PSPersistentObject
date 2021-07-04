function New-PSPersistentObject {
<#
 .Synopsis
  Converts an object to a base64 string and saves it to a local SQLite database

 .Description
  Converts an object to a base64 string and saves it to a local SQLite database

 .Parameter Object
  The object that should be saved in persistent storage

 .Parameter id
  Identifier for the object, if not specified a new guid will be generated and used as the identifier
 
 .Parameter datasource
  Specifies the path of a SQLite database file. If not used a "PSPersistentObject.db" will be used

 .Example
   # Creates a new persistent object and stores it in the default PSPersistentObject.db
   New-PersistentObject -Object $myObject -Id 1 

 .Example
   # Creates a new persistent object and stores it in .\my_db.db
   New-PersistentObject -Object $myObject -Id 1 -datasource .\my_db.db
#>
 [CmdletBinding()]
 param(
     [Parameter(Position=0,
                Mandatory = $true,
                ValueFromPipeline=$true,
                HelpMessage="Object to save required...")]
                [Object]$Object,

    [Parameter(Position=1,
               Mandatory = $false,
               ValueFromPipeline = $false)]
               [String]$Id,

    [Parameter(Position=2,
               Mandatory = $false,
               ValueFromPipeline=$false)]
               [String]$DataSource        
 )

 Begin {

    try {
        # Import sqlite assemblies
    } catch {
        Throw 'This module requires an SQLite driver'
    }

    if(-not $Id){
        # Id parameter was not specified. Using guid as the identifier

        $Id = New-Guid | Select-Object -ExpandProperty Guid

    }



 }

 Process {

    Write-Output $id

 }

 End {


 }



}

