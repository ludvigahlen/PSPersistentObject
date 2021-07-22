try {
    # Import sqlite assemblies

    if([IntPtr]::size -eq 8) #64
    {
        $SQLiteAssembly = Join-path $PSScriptRoot "x64\System.Data.SQLite.dll"
    }
    elseif([IntPtr]::size -eq 4) #32
    {
        $SQLiteAssembly = Join-path $PSScriptRoot "x86\System.Data.SQLite.dll"
    }

    Add-Type -path $SQLiteAssembly -ErrorAction stop



} catch {
    Throw 'This module requires an SQLite driver'
}

$DBLocation = "$((Get-location).path)\PSPersistentObject.db"

function New-DBConnection {

    $ConnectionString = "Data source=$DBLocation"

    $conn = New-Object System.Data.SQLite.SQLiteConnection -ArgumentList $ConnectionString
    
    $conn.ParseViaFramework = $true
    
        try {
            $conn.Open() 
        }
        Catch {
            Write-Error $_
            continue
        }
 

    $Conn
}

function Close-DBConnection {

    param($Connection)

    try {
    $Connection.Close()
    $Connection.Dispose()

    } catch {
        Write-Error $_
        continue

    }


}

function Invoke-DBNonQuery {
    param(
        $connection,
        $query
        )

        $connectionCreated = $false

        if(-not $connection){
            
            $connection = New-DBConnection
            $connectionCreated = $true
        }
        $command = $connection.createCommand()
        $command.commandtext = $query


     try {

    $command.executeNonQuery()  

            if($connectionCreated){
                Close-DBConnection -Connection $connection
            }
            $command.Dispose()
        }
        Catch
        { 
            if($connectionCreated){
                Close-DBConnection -Connection $connection
                write-error $_
                continue
            }
        }

}

function Invoke-DBQuery {
    param(
        $connection,
        $Query
        )

        $connectionCreated = $false

        if(-not $connection){
            
            $connection = New-DBConnection
            $connectionCreated = $true
        }
        $command = $connection.createCommand()
        $command.commandtext = $Query

        $ds = New-Object system.Data.DataSet 
        $da = New-Object System.Data.SQLite.SQLiteDataAdapter($command)

        Try
        {
            [void]$da.fill($ds)
         
            $command.Dispose()
        }
        Catch
        { 
            if($connectionCreated){
                Close-DBConnection -Connection $connection
                write-error $_
                continue
            }
        }

        $objects = Convert-DataTable -datatable $ds
        
        if($connectionCreated){
            if($connection.state -eq "Open"){
            Close-DBConnection -Connection $connection
            }
        }
      

        $objects
}

function Convert-DataTable {
    param($DataTable)

    $psObjects = @()
    $Rows = $DataTable.tables[0].rows
    foreach($row in $Rows){
        $psObjects += new-object PSCustomObject -property @{
            id = $row.id
            object = $row.object
        }
    }
    $psObjects
}

function Convert-Object {
    param([PSCustomobject]$object)

        $Serialized = [System.Management.Automation.PSSerializer]::Serialize($object)
    
        $bytes = [System.Text.Encoding]::Unicode.GetBytes($Serialized)
        [Convert]::ToBase64String($Bytes)
}
function Convert-ToObject {
    param($string)
    
        $obj = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($string))
    
        [System.Management.Automation.PSSerializer]::Deserialize($obj)
    
}

function PrepareDB {

    $connection = New-DBConnection

    Invoke-DBNonQuery -connection $connection -cmd "CREATE TABLE OBJECTS (id TEXT PRIMARY KEY, object TEXT)"
    

    Close-DBConnection -Connection $connection
}

function New-PersistentObject {
<#
 .Synopsis
  Converts an object to a base64 string and saves it to a local SQLite database

 .Description
  Converts an object to a base64 string and saves it to a local SQLite database

 .Parameter Object
  The object that should be saved in persistent storage

 .Parameter id
  # Identifier for the object, if not specified a new guid will be generated and used as the identifier
 
 .Example
   # Creates a new persistent object and stores it in the default PSPersistentObject.db
   New-PersistentObject -Object $myObject -Id 1 


#>
 [CmdletBinding()]
 param(
    [Parameter(Position=0,
               Mandatory = $false,
               ValueFromPipeline = $false)]
               [String]$Id,

     [Parameter(Position=1,
                Mandatory = $true,
                ValueFromPipeline=$true,
                HelpMessage="Object to save required...")]
                [Object]$Object,

                [Switch]$Force
  )

 Begin {



    if(-not $Id){
        # Id parameter was not specified. Using guid as the identifier

        $Id = New-Guid | Select-Object -ExpandProperty Guid

    }
    
    $Test = Get-PersistentObject -Id $id

    $connection = New-DBConnection

    if($Test){
        Write-Verbose "Id $id already in use"

        if($Force){

            Invoke-DBNonQuery -connection $connection -query "delete from objects where id = '$id'"
        
        } else {

        

            Write-Error "Id $id already in use and the -Force switch was not used"
            break
        }


    }


 }

 Process {


    

    $Base64 = Convert-Object -object $Object

   


 
    Invoke-DBNonQuery -connection $connection -query "Insert into objects (id, object) values ('$id', '$Base64')"


}

 End {

    Close-DBConnection -Connection $connection

    Get-PersistentObject -Id $id


 }



}

function Get-PersistentObject {
    <#
 .Synopsis
  Get a previously saved object from the database

 .Description
  Get a previously saved object from the database

 .Parameter id
  Identifier for the object, if not specified all objects will be returned
 
 .Example
   # Get the object with Id 1
   Get-PersistentObject -Id 1 

#>
    param(
        [Parameter(Position=0,
                   Mandatory = $false,
                   ValueFromPipeline = $false)]
                   [String]$Id
    )

    Begin {



        if(-not $Id){
            # Id parameter was not specified. Getting all objects
            $Query = "Select id, object from objects"
        } else {
            $Query = "Select id, object from objects where id = '$id'"
        } 
    
    
     }
    
     Process {
    
      
        
        $connection = New-DBConnection
        $object = Invoke-DBQuery -connection $connection -query "$Query"
    
  
    }
    
     End {
    
        Close-DBConnection $connection
        $obj = @()
        foreach($o in $object){
        $obj += Convert-ToObject -String $o.object
        }
        $obj
    
     }
 
}


PrepareDB

#Export-ModuleMember -Function New-PersistentObject
#Export-ModuleMember -Function Save-PersistentObject
#Export-ModuleMember -Function Get-PersistentObject
#Export-ModuleMember -Function Remove-PersistentObject