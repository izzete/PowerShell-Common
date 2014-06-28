# http://psqlite.codeplex.com/

. ..\PowerShell-Common\Setup-GlobalVariables.ps1
Setup-GlobalVariables

Import-Module SQLite

# Mount database as drive
New-PSDrive -Name db -PSProvider SQLite -Root "Data Source=$PicklePath\test.sqlite"

# Create table
New-Item -Path db:/Users -Value "id INTEGER PRIMARY KEY, username TEXT NOT NULL, userid INTEGER"

# Creating records - option 1
Measure-Command {
    1 .. 100 | % {
        Write-Progress -Activity "db" -PercentComplete ($_/100*100)

        # option 1
#        New-Item -Path db:/Users -username "Jimbo" -userid 123

        # option 2
#        New-Item -Path db:/Users -Value @{ username="Jimbo"; userid=123 }

 
        # option 3
        $o = New-Object PSObject -Property @{ username='Jimbo'; userid=123 }
        $o | New-Item -Path db:/Users | Out-Null
    }
}

# Delete table
Remove-Item -Path db:/Users  
