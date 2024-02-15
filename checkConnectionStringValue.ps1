#CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC   CHANGE THIS PER THE ENVIRONMENT CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
#repo base folder
$mainFolder = "C:\REPO\"
$xxrsyyConfigFolde = "C:\xxxrsyyy\Config\"

#YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY   ONLY CHANGE IF NEED BE YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY
#setting file 
$global:gSettingFile = "script_setting.json"

#files to update
$files = @('DbConnectionStrings.config','ConnectionStrings.config')
$filesClassic  = @('Global.asa','Web.config')

#full path to the resources
$classic = $mainFolder+"xxxrsyyy Classic\"
$classicSource = "\Source\Web-ASP\Web\"

$xxxrsyyy = $mainFolder+"xxxrsyyy\"
$config = "\Source\xxxrsyyy.Config\Config\"

#XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX   DO NOT CHANGE ANY THING BELOW THIS LINE XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
$branches = [System.Collections.ArrayList]@()
$branchesClassic = [System.Collections.ArrayList]@()

try {
    #function will come before the call

    function CreateBranches {
		param ($ltitle, $lpath, $lconfig)

		$xxxrsyyyExist = Test-Path $lpath
		if($xxxrsyyyExist -eq $false){
			write-host ($lpath + " does not exist for " + $ltitle) -ForegroundColor Red
		}
		else{
			Get-ChildItem $lpath -Directory | 
			Foreach-Object {
				$isDir = Test-Path $_.FullName -PathType Container
				if($isDir -eq $true){
					#check that the dir has the $config location 
					$hasConfig = Test-Path ($_.FullName+$lconfig)
					if($hasConfig -eq $true){
						$dirName = Split-Path -Path ($_.FullName) -Leaf 
						if($ltitle -eq "NetBranches"){
							$branches.Add($dirName) | out-null
						}
						else{
							$branchesClassic.Add($dirName) | out-null
						}
					}
				}
			}
		}
	}

    function BranchesAndFilesGettingUPdate 
	{
		Write-Host "Branches where the connection will be looked at" -ForegroundColor Green 
		$classicBranchesString = ""
		$netBranchesString = ""
		if ($branchesClassic.count  -gt 0){
			for ( $cfbindex = 0; $cfbindex -lt $branchesClassic.count; $cfbindex++){ 
				if($classicBranchesString -ne "")
				{
					$classicBranchesString = $classicBranchesString + ", " + $branchesClassic[$cfbindex]
				}
				else
				{
					$classicBranchesString = $branchesClassic[$cfbindex]
				}
			}
			Write-Host (" - Classic ASP Branches: " + $classicBranchesString) -ForegroundColor Magenta
			for ( $cfindex = 0; $cfindex -lt $filesClassic.count; $cfindex++){
				Write-Host ("  > " + $filesClassic[$cfindex])
			}
		}
		else{
			Write-Host (" - Classic ASP Branches: None built") -ForegroundColor Red
		}
		
		if($branches.count -gt 0){
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
			for ( $sfindex = 0; $sfindex -lt $files.count; $sfindex++){
				Write-Host ("  > " + $files[$sfindex])
			}
		}
		else{
			Write-Host (" - Net Branches: None built")  -ForegroundColor Red
		}

        if($xxrsyyConfigFolde -ne ""){
            Write-Host (" - " + $xxrsyyConfigFolde)  -ForegroundColor Magenta
            for ( $sfindex = 0; $sfindex -lt $files.count; $sfindex++){
				Write-Host ("  > " + $files[$sfindex])
			}
        }

		write-host "`n"
	}

    function WriteNetBranchesXML{
        param ($path)

        Write-Host "    > $path" -ForegroundColor Yellow

        [xml]$xml = Get-Content -Path $path
        $nodes = Select-Xml "//add/@connectionString" $xml
        foreach ($node in $nodes) {
            Write-Host "       >> $node"
        }
        <#
        [xml]$xmlContent = Get-Content -Path $path -Raw 
        Write-Host $xmlContent
        #select all connectionString attribute of the add node
        $nodes = $xmlContent.SelectNodes('//add/@connectionString')
        foreach ($node in $nodes) {
            Write-Host "        >> Node: $node.connectionString.InnerText"
        }
        #>
        write-host "`n"
    }

    function WriteClassicGlobal{
        param ($path)

        Write-Host "    > $path" -ForegroundColor Yellow

        $content = Get-Content -Path $path | Select-String -Pattern "^const xxxrsyyyConnectionString = " | Select-Object -First 1

        $content = $content -replace "const xxxrsyyyConnectionString = ", ""
        $content = $content -replace "Provider=MSDataShape;", ""
        $content = $content -replace """", ""

        Write-Host "       >> $content"
        write-host "`n"
    }

    function HanldeNetBranchesXML{
        write-host "`n"
        if($branches.count -gt 0){
            Write-Host "Net branches "  -ForegroundColor Cyan
            for ( $index = 0; $index -lt $branches.count; $index++)
            {
                for ( $sfindex = 0; $sfindex -lt $files.count; $sfindex++){
                    $path = $xxxrsyyy + $branches[$index] + $config + $files[$sfindex] 
                    
                    WriteNetBranchesXML -path $path
                }
            }
        }
        else{
            Write-Host "No .net branches available to look at"  -ForegroundColor Red
        }
        write-host "`n"
    }

    function HandlexxxrsyyyFolderXML{
        write-host "`n"
        Write-Host $xxrsyyConfigFolde  -ForegroundColor Cyan
        for ( $index = 0; $index -lt $branches.count; $index++)
        {
            for ( $sfindex = 0; $sfindex -lt $files.count; $sfindex++){
                $path = $xxrsyyConfigFolde + $files[$sfindex] 
                
                WriteNetBranchesXML -path $path
            }
        }
        write-host "`n"
    }

    function HandleClassicXML{
        write-host "`n"
        if($branchesClassic.count -gt 0){
            Write-Host "Classic branches "  -ForegroundColor Cyan
            for ( $index = 0; $index -lt $branchesClassic.count; $index++)
            {
                for ( $sfindex = 0; $sfindex -lt $filesClassic.count; $sfindex++){ 
                    $path = $classic + $branchesClassic[$index] + $classicSource + $filesClassic[$sfindex] 
                    if($filesClassic[$sfindex] -ieq "web.config"){
                        WriteNetBranchesXML -path $path
                    }
                    else{
                        WriteClassicGlobal -path $path
                    }
                }
            }
        }
        else{
            Write-Host "No classic branches available to look at"  -ForegroundColor Red
        }
        write-host "`n"
    }

    #Add branches for both .Net and Classic asp
	CreateBranches -ltitle "NetBranches" -lpath $xxxrsyyy -lconfig $config
	CreateBranches -ltitle "ClassicBranches" -lpath $classic -lconfig $classicSource

    #Branches and Files getting update
	BranchesAndFilesGettingUPdate

    #Handle 
    HandlexxxrsyyyFolderXML
    HanldeNetBranchesXML
    HandleClassicXML

}
catch {
	Write-Host "An error occurred:" -ForegroundColor Red
	Write-Host $_
	Write-Host $_.ScriptStackTrace
}

write-host "`n"
pause