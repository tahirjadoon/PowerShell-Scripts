$mainFolder = "C:\REPO\"
$xxxrsyyy = $mainFolder+"XXXRSYYY\"
$branches = [System.Collections.ArrayList]@()
$branchesClassic = [System.Collections.ArrayList]@()

$config = "\Source\XXXRSYYY.Config\Config\"

$classic = $mainFolder+"XXXRSYYY Classic\"
$classicSource = "\Source\Web-ASP\Web\"

$xxxrsyyyExist = Test-Path $xxxrsyyy
if($xxxrsyyyExist -eq $false){
    write-host ($xxxrsyyy + " does not exist") -ForegroundColor Red
}
else{
    Get-ChildItem $xxxrsyyy -Directory | 
    Foreach-Object {
        $isDir = Test-Path $_.FullName -PathType Container
        if($isDir -eq $true){
            #check that the dir has the $config location
            $hasConfig = Test-Path ($_.FullName+$config)
            if($hasConfig -eq $true){
                $dirName = Split-Path -Path ($_.FullName) -Leaf
                $branches.Add($dirName) | out-null
            }
        }
    }

    
    Get-ChildItem $classic -Directory | 
    Foreach-Object {
        $isDir = Test-Path $_.FullName -PathType Container
        if($isDir -eq $true){
            #check that the dir has the $config location
            $hasConfig = Test-Path ($_.FullName+$classicSource)
            if($hasConfig -eq $true){
                $dirName = Split-Path -Path ($_.FullName) -Leaf
                $branchesClassic.Add($dirName) | out-null
            }
        }
    }


}
if($branches.count -gt 0){
    $netBranchesString = ""
    for ( $sfnindex = 0; $sfnindex -lt $branches.count; $sfnindex++){
        if($netBranchesString -ne "")
        {
            $netBranchesString = $netBranchesString + ", " + $branches[$sfnindex]
        }
        else
        {
            $netBranchesString = $branches[$sfnindex]
        }
    }
    Write-Host (" - Net Branches: " + $netBranchesString)  -ForegroundColor Magenta
}
else{
    write-host ("No branches found at " + $xxxrsyyy + " with sub folder " + $config) -ForegroundColor Red
}

if($branchesClassic.count -gt 0){
    $netBranchesString = ""
    for ( $sfnindex = 0; $sfnindex -lt $branchesClassic.count; $sfnindex++){
        if($netBranchesString -ne "")
        {
            $netBranchesString = $netBranchesString + ", " + $branchesClassic[$sfnindex]
        }
        else
        {
            $netBranchesString = $branchesClassic[$sfnindex]
        }
    }
    Write-Host (" - Classic Branches: " + $netBranchesString)  -ForegroundColor Magenta
}
else{
    write-host ("No branches classic found at " + $classic + " with sub folder " + $classicSource) -ForegroundColor Red
}




write-host "`n"
pause