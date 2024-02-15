<#
Script to change the ConnectionString Data Source

Command Line: 
	.\changeConnection.ps1 xxx yyy
	.\changeConnection.ps1
	** NOTE FromDb and ToDb are optional
	** First argument is FromDb, Second argument is ToDb
	** When no arguments passed then will be prompted for FromDb and ToDb

Directly running the script by right clicking it as well
	Will be prompted for FromDb and ToDb

colors
	Black, Gray, Blue, Green, Cyan, Red, Magenta, Yellow, White
	DarkGray, DarkBlue, DarkGreen, DarkCyan, DarkRed, DarkMagenta, DarkYellow
#>

#CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC   CHANGE THIS PER THE ENVIRONMENT CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
#repo base folder
$mainFolder = "C:\REPO\"
$xxxrsyyyConfigFolder = "C:\XXXRSYYY\Config\"

#YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY   ONLY CHANGE IF NEED BE YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY
#setting file 
$global:gSettingFile = "script_setting.json"

#files to update
$files = @('DbConnectionStrings.config','ConnectionStrings.config')
$filesClassic  = @('Global.asa','Web.config')

#full path to the resources
$classic = $mainFolder+"XXXRSYYY Classic\"
$classicSource = "\Source\Web-ASP\Web\"

$xxxrsyyy = $mainFolder+"XXXRSYYY\"
$config = "\Source\XXXRSYYY.Config\Config\"

#XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX   DO NOT CHANGE ANY THING BELOW THIS LINE XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
$branches = [System.Collections.ArrayList]@()
$branchesClassic = [System.Collections.ArrayList]@()

$global:gHasSettingFile = $false 
$global:gSuccessCount = 0 
$global:gErrorCount = 0 
$global:gNotTriedCount = 0 

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

	function ReplaceDB {
		param ($title, $path, $isTry, $from, $to)
	
		try{
			if($isTry -eq $true){
				if(Test-Path $path){
					$script:gSuccessCount++

					#remove read only attribute
					$isFileReadOnly = Get-ItemProperty -Path $path | Select-Object IsReadOnly
					if($isFileReadOnly -eq $true){
						Set-ItemProperty -Path $path -Name IsReadOnly -Value $false
					}

					((Get-Content -path $path -Raw) -replace $from,$to) | Set-Content -Path $path
					Write-Host $title " Success " $path -ForegroundColor Green
				}
				else{
					$script:gErrorCount++
					Write-Host  $title " File does not exist " $path -ForegroundColor Red
				}
			}
			else{
				Write-Host $title  " Not Tried " $path -ForegroundColor Magenta
				$script:gNotTriedCount++
			}
		}
		catch {
			$script:gErrorCount++
			Write-Host $title  " An error occurred " $path -ForegroundColor Red
			Write-Host $_
			Write-Host $_.ScriptStackTrace -ForegroundColor Red
		}
	}

	function LastDbUsed {
		Write-Host "++++++++++++++++++++++ Last Run Settings Start +++++++++++++++++++++++++++++"
		try{
			$lFromDb = ""
			$lToDb = ""
			$lChangedOn = ""

			if(Test-Path $gSettingFile){
				$gHasSettingFile = $true

				$json = Get-Content -Path $gSettingFile -Raw | ConvertFrom-Json
				$lFromDb = $json.fromDb
				$lToDb = $json.toDb
				$lChangedOn = $json.changedOn
			}

			
			Write-Host (" - Setting File " + $gSettingFile + "  available = " + $gHasSettingFile)
			Write-Host (" - Last From DB Used: " + $lFromDb)
			Write-Host (" - Last To DB Used: " + $lToDb)
			Write-Host (" - Last Changed On: " + $lChangedOn)
		}
		catch {
			Write-Host " - An error occurred " -ForegroundColor Red
			Write-Host $_ -ForegroundColor Red
			Write-Host $_.ScriptStackTrace -ForegroundColor Red
		}

		Write-Host "++++++++++++++++++++++ Last Run Settings End +++++++++++++++++++++++++++++"
		write-host "`n"
	}

	function WriteSetting {
		param ($rFromDb, $rToDb)

		Write-Host "++++++++++++++++++++++++++++ Setting File Update Start ++++++++++++++++++++++++++++"

		try{
			$lCurrentDate = Get-Date -Format "yyyy/MM/dd HH:mm"

			#build object
			$obj = @{
				"fromDb" = $rFromDb
				"toDb" = $rToDb
				"changedOn" = $lCurrentDate
			}

			# Convert object to JSON
			$json = $obj | ConvertTo-Json

			# Save JSON to file
			$json | Set-Content -Path $gSettingFile

			
			Write-Host (" - Setting File " + $gSettingFile + "  updated")
			Write-Host (" - From DB: " + $rFromDb)
			Write-Host (" - To DB: " + $rToDb)
			Write-Host (" - Changed On: " + $lCurrentDate)
		}
		catch {
			Write-Host "     An error occurred " -ForegroundColor Red
			Write-Host $_
			Write-Host $_.ScriptStackTrace -ForegroundColor Red
		}

		Write-Host "++++++++++++++++++++++++++++ Setting File Update End ++++++++++++++++++++++++++++"
		write-host "`n"
	}

	function BranchesAndFilesGettingUPdate 
	{
		Write-Host "Only following files will be updated" -ForegroundColor Green 
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
		write-host "`n"
	}

	#script location 
	Write-Host ("Script location: " + $PSScriptRoot) -ForegroundColor Magenta
	write-host "`n"

	#LastDB Used
	LastDbUsed 

	#Add branches for both .Net and Classic asp
	CreateBranches -ltitle "NetBranches" -lpath $xxxrsyyy -lconfig $config
	CreateBranches -ltitle "ClassicBranches" -lpath $classic -lconfig $classicSource

	#Branches and Files getting update
	BranchesAndFilesGettingUPdate

	#Get input for from db and to db from arguments
	$fromDB = $args[0]
	$toDB  = $args[1]

	#WHEN NOT PROVIDED THEN ASK
	if($args[0] -eq "" -Or !$args[0])
	{
		write-host "Enter From and To DB" -ForegroundColor Cyan
		$fromDb = Read-Host -Prompt " - Enter FROM DB"
		$toDB = Read-Host -Prompt " - Enter TO DB"
		write-host "`n"
	}

	write-host "DBs Provided" -ForegroundColor Green
	write-host (" - From: "+$fromDB)
	write-host (" - To: "+$toDB)

	write-host "`n"

	if(($fromDb -eq "" -Or !$fromDB) -Or ($toDB -eq "" -Or !$toDB))
	{
		Write-Host "FromDB or ToDB is missing" -ForegroundColor Red 
	}
	elseif($fromDB -ceq $toDB)
	{
		write-host "From DB and To DB are same" -ForegroundColor Red
	}
	else
	{
		Write-Host "=========================== Updating DB Start ============================" -ForegroundColor DarkCyan
		write-host "`n"

		#Classic ASP
		if($branchesClassic.count -gt 0){
			for ( $cindex = 0; $cindex -lt $branchesClassic.count; $cindex++){
				write-host ("Updating Classic ASP Repo " + $branchesClassic[$cindex])
				if($filesClassic.count -gt 0){
					for ( $cfindex = 0; $cfindex -lt $filesClassic.count; $cfindex++){
						$itemTitle = ("  - " + $filesClassic[$cfindex])
						$itemPath = ($classic + $branchesClassic[$cindex] + $classicSource + $filesClassic[$cfindex])
						ReplaceDB -title $itemTitle -path $itemPath -isTry $true -from $fromDb -to $toDB
					}
				}
				else{
					write-host "  - No files specified"  -ForegroundColor Magenta
				}
				write-host "`n"
			}
		}
		else{
			write-host "No classic ASP branches provided to update" -ForegroundColor Magenta
			write-host "`n"
		}

		#XXXRSYYY Config
		write-host "Updating XXXRSYYY Config"
		if($files.count -gt 0){
			for ( $sfindex = 0; $sfindex -lt $files.count; $sfindex++){
				$itemTitle = (" - " + $files[$sfindex])
				$itemPath = $xxxrsyyyConfigFolder+$files[$sfindex]
				ReplaceDB -title $itemTitle -path $itemPath -isTry $true -from $fromDb -to $toDB
				
			}
		}
		else{
			write-host "  - No .config files specified"  -ForegroundColor Magenta
		}
		write-host "`n"

		#Other branches
		if($branches.count -gt 0){
			for ( $index = 0; $index -lt $branches.count; $index++)
			{
				write-host ("Updating Repo " + $branches[$index])
				for ( $sfindex = 0; $sfindex -lt $files.count; $sfindex++){
					if($files.count -gt 0){
						$itemTitle = (" - " + $files[$sfindex])
						$itemPath = ($xxxrsyyy+$branches[$index]+$config+$files[$sfindex])
						ReplaceDB -title $itemTitle -path $itemPath -isTry $true -from $fromDb -to $toDB
					}
					else{
						write-host "  - No .config files specified"  -ForegroundColor Magenta
					}
				}
				write-host "`n"
			}
		}
		else{
			write-host "No config (repos) branches provided to update" -ForegroundColor Magenta
			write-host "`n"
		}

		Write-Host "=========================== Updating DB End ============================" -ForegroundColor DarkCyan
		write-host "`n"

		Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~ Summary Start ~~~~~~~~~~~~~~~~~~~~~~~~~~~"-ForegroundColor Yellow
		$totalCount = $gSuccessCount+$gErrorCount+$gNotTriedCount
		Write-Host " - Total Count: " $totalCount
		Write-Host " - Success Count: " $gSuccessCount
		Write-Host " - Error Count: " $gErrorCount
		Write-Host " - Not Tried Count: " $gNotTriedCount
		Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~ Summary End ~~~~~~~~~~~~~~~~~~~~~~~~~~~"-ForegroundColor Yellow
		write-host "`n"

		#write setting
		WriteSetting -rFromDb $fromDb -rToDb $toDB

		#restarting iis
		Write-Host "**** Resetting IIS ****" -ForegroundColor DarkGreen 
		Start-Process "iisreset.exe" -NoNewWindow -Wait
	}
}
catch {
	Write-Host "An error occurred:" -ForegroundColor Red
	Write-Host $_
	Write-Host $_.ScriptStackTrace
}

write-host "`n"
pause