
$subFolderNamesToDelete = @('bin', 'obj', 'node_modules', '.vs', '.vscode', '.angular', 'packages', '_vti_cnf', '__pycache__')


#XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX   DO NOT CHANGE ANY THING BELOW THIS LINE XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

function DeleteFolder{
    param([string]$folderPath)

    Write-Host "Checking: $folderPath" -ForegroundColor Yellow

    for ( $index = 0; $index -lt $subFolderNamesToDelete.count; $index++){
        
        $delFolder = Join-Path -Path $folderPath -ChildPath $subFolderNamesToDelete[$index]

        if (Test-Path -Path $delFolder) {
            Remove-Item -Path $delFolder -Force -Recurse
            Write-Host "    Deleted: $subFolderNamesToDelete[$index]"
        }
        else{
            Write-Host "    NotAvailable: $subFolderNamesToDelete[$index]" -ForegroundColor Cyan
        }

        $subfolders = Get-ChildItem -Path $folderPath -Directory
        foreach ($subfolder in $subfolders) {
            DeleteFolder -folderPath $subfolder.FullName
        } 
    }
}

function DeleteFolder2{
    param([string]$folderPath)
    #for ( $index = 0; $index -lt $subFolderNamesToDelete.count; $index++){
    #    Get-ChildItem $path -recurse -directory -include $subFolderNamesToDelete[$index] | Remove-Item -Force -ErrorAction SilentlyContinue
    #}

    $title    = 'Delete Type Confirm...'
    $question = 'Please pick run type...'
    $choices  = '&Test Run', 'Perform &Delete', '&Abort (No Action)'

    $decision = $Host.UI.PromptForChoice($title, $question, $choices, 0)
    if($decision -eq 1 -or $decision -eq 0){
        write-host "`n"
        write-host "Delete process started... $folderPath" -ForegroundColor Yellow
        write-host "`n"

        if ($decision -eq 1) {
            #delete
            Get-ChildItem $folderPath -Recurse -Force -Directory -Include $subFolderNamesToDelete | Remove-Item -Recurse -Confirm:$false -Force
        } 
        elseif($decision -eq 0) {
            #test 
            write-host "Test mode, nothing will get deleted "
    
            Get-ChildItem $folderPath -Recurse -Force -Directory -Include $subFolderNamesToDelete | Remove-Item -Recurse -Confirm:$false -Force -WhatIf
            write-host "`n"
        }

        write-host "Delete process completed" -ForegroundColor Yellow
    }
    else{
        write-host "`n"
        write-host "Delete aborted" -ForegroundColor Red
    }
}

function AskForFolderBasePath{
    $folderToUse = ""
    $continue = $true

    do{
        write-host "Enter Base Folder Path" -ForegroundColor Cyan
        $folderToUse = Read-Host -Prompt " - Folder Path"

        $message = $folderToUse
        if($folderToUse -eq ""){
            $message = "No Path Selected"
        }

        $titleContinue = 'Path Input Confirm...'
        $questionContinue = "Is selected path correct? [$message]"
        $choicesContinue  = '&Yes', '&No'

        $decisionContinue = $Host.UI.PromptForChoice($titleContinue, $questionContinue, $choicesContinue, 0)

        if ($decisionContinue -eq 0) {
            #do not ask for path again
            $continue = $false
        }
        write-host "`n"

    } while($continue -eq $true)

    return $folderToUse
}

function GetFolderBasePath {
    param([string]$folderPath)
    $pathAvailable = $false
    $folderToUse = ""
    if ($folderPath -ne ""){
        write-host "Previous used folder path : $folderPath" -ForegroundColor Magenta
        $titleBasePath = 'BasePath Confirm...'
        $questionBasePath = 'Do you want to continue using above base path?'
        $choicesBasePath  = '&Yes', '&No'

        $decisionBasePath = $Host.UI.PromptForChoice($titleBasePath, $questionBasePath, $choicesBasePath, 0)
        if ($decisionBasePath -eq 1){
            #ask for the base path again
            $pathAvailable = $false
            #ClearTerminal
        }
        else{
            #keep using the base path
            $pathAvailable = $true
            $folderToUse = $folderPath
        }
        write-host "`n"
    }

    if($pathAvailable -eq $false){
        $folderToUse = AskForFolderBasePath
    }
    return $folderToUse
}

function Main{
    param([string]$folderPath)

    $folderToUse = GetFolderBasePath -folderPath $folderPath

    if($folderToUse -eq ""){
        write-host "Base folder not provided" -ForegroundColor Red
    }
    elseif(-Not (Test-Path $folderToUse)){
        write-host "Base folder does not exist" -ForegroundColor Red
    }
    else{

        write-host "Following folders will be recursively deleted from " -ForegroundColor Green
        write-host "    Path: $folderToUse"  -ForegroundColor Magenta
        $dd = ($subFolderNamesToDelete -join ", ")
        write-host "    $dd"
        #write-host "`n"

        DeleteFolder2 -folderPath $folderToUse
    }
    return $folderToUse
}

Remove-Item Alias:clear
function ClearTerminal {
    Write-Output "$([char]27)[2J"
    Clear-Host
}

#program starts here
if($subFolderNamesToDelete.length -eq 0){
    write-host "Sub folders array is empty. Nothing to delete" -ForegroundColor Red
}
else{
    $continue = $true
    $gBasePath = ""
    do{
        $gBasePath = Main -folderPath $gBasePath

        write-host "`n"
        $titleContinue = 'Continue...'
        $questionContinue = 'Do you want to continue run delete?'
        $choicesContinue  = '&Yes', '&No'

        $decisionContinue = $Host.UI.PromptForChoice($titleContinue, $questionContinue, $choicesContinue, 1)
        if ($decisionContinue -eq 1) {
            #want to quit so make it false
            $continue = $false
        }
        else{
            #want to continue running so clear
            ClearTerminal
        }

    } while($continue -eq $true)
}

#write-host "`n"
#pause