# ─────────────────────────────────────────────────────────────
# Ensure PowerShell can run scripts (first-time setup)
# ─────────────────────────────────────────────────────────────
$currentPolicy = Get-ExecutionPolicy
if ($currentPolicy -eq 'Restricted') {
    Write-Host "Execution policy is Restricted. Updating to RemoteSigned..." -ForegroundColor Yellow
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Write-Host "Execution policy updated to RemoteSigned." -ForegroundColor Green
    Write-Host "`n"
}

# ─────────────────────────────────────────────────────────────
# Compression Settings (Global Constants)
# ─────────────────────────────────────────────────────────────
$gsPath   = "C:\Program Files\gs\gs10.06.0\bin\gswin64c.exe"
# Arguments must be passed as an array of strings for external executables
$compressionArgs = @(
    "-sDEVICE=pdfwrite"
    "-dCompatibilityLevel=1.4"
    "-dPDFSETTINGS=/ebook"
    "-dNOPAUSE"
    "-dQUIET"
    "-dBATCH"
)

# ─────────────────────────────────────────────────────────────
# Function: Ask for base folder path
# ─────────────────────────────────────────────────────────────
function AskForFolderBasePath {
    $folderToUse = ""
    $continue = $true

    do {
        Write-Host "Enter Base Folder Path" -ForegroundColor Cyan
        $folderToUse = Read-Host -Prompt " - Folder Path"

        $message = if ($folderToUse -eq "") { "No Path Selected" } else { $folderToUse }

        $title = 'Path Input Confirm...'
        $question = "Is selected path correct? [$message]"
        $choices = '&Yes', '&No'
        $decision = $Host.UI.PromptForChoice($title, $question, $choices, 0)

        if ($decision -eq 0) { $continue = $false }
        Write-Host "`n"
    } while ($continue)

    return $folderToUse
}

# ─────────────────────────────────────────────────────────────
# Function: Format File Size (Bytes to KB/MB/GB)
# ─────────────────────────────────────────────────────────────
function Format-FileSize {
    param(
        [long]$bytes
    )

    $KB = 1KB
    $MB = 1MB
    $GB = 1GB

    if ($bytes -ge $GB) {
        # Format as GB
        return "$([math]::Round($bytes / $GB, 2)) GB"
    } elseif ($bytes -ge $MB) {
        # Format as MB
        return "$([math]::Round($bytes / $MB, 2)) MB"
    } elseif ($bytes -ge $KB) {
        # Format as KB
        return "$([math]::Round($bytes / $KB, 2)) KB"
    } else {
        # Format as Bytes
        return "$bytes Bytes"
    }
}

# ─────────────────────────────────────────────────────────────
# Function: Format Time Duration
# ─────────────────────────────────────────────────────────────
function Format-TimeSpan {
    param (
        [System.TimeSpan]$timeSpan
    )

    if ($timeSpan.Days -gt 0) {
        return "$($timeSpan.Days) days, $($timeSpan.Hours) hours, $($timeSpan.Minutes) minutes, $($timeSpan.Seconds) seconds"
    } elseif ($timeSpan.Hours -gt 0) {
        return "$($timeSpan.Hours) hours, $($timeSpan.Minutes) minutes, $($timeSpan.Seconds) seconds"
    } elseif ($timeSpan.Minutes -gt 0) {
        return "$($timeSpan.Minutes) minutes, $($timeSpan.Seconds) seconds"
    } else {
        # Use TotalSeconds for precision in seconds display
        return "$($timeSpan.TotalSeconds.ToString('N2')) seconds"
    }
}

# ─────────────────────────────────────────────────────────────
# Function: Traverse and compress PDFs (Synchronous Processing)
# ─────────────────────────────────────────────────────────────
function TraverseAndCompress {
    param (
        [string]$basePath,
        [int]$overwrite,
        [string[]]$targetFolders, # Array of folders to target
        [int]$matchType,          # 0 = Exact Match, 1 = Contains Match
        [hashtable]$stats,         # Parameter to pass and update the statistics
        [string]$gsPath,          # Passed from Main
        [string[]]$compressionArgs # Passed from Main
    )

    $searchPaths = @()
    
    if ($targetFolders.Count -eq 0) {
        $searchPaths = Get-Item $basePath
        Write-Host "`nINFO: No specific folders targeted. Processing ALL PDFs recursively under: $basePath" -ForegroundColor Yellow
    } else {
        Write-Host "`nINFO: Searching for target folder names: $($targetFolders -join ', ')" -ForegroundColor Yellow
        
        $searchPaths = Get-ChildItem -Path $basePath -Recurse -Directory | Where-Object {
            $currentFolderName = $_.Name
            $found = $false
            
            foreach ($target in $targetFolders) {
                if ($matchType -eq 0) {
                    if ($currentFolderName -ceq $target) { $found = $true; break }
                } else {
                    if ($currentFolderName -like "*$target*") { $found = $true; break }
                }
            }
            $found
        }
        
        if ($searchPaths.Count -eq 0) {
            Write-Host "WARNING: No folders found matching the target criteria in the base path. Exiting." -ForegroundColor Yellow
            return
        }
    }
    
    # Process the found path(s)
    foreach ($folderItem in $searchPaths) {
        if ($folderItem -is [string]) { $folderItem = Get-Item $folderItem } 
        
        $folderPath = $folderItem.FullName
        $folderName = $folderItem.Name
        
        Write-Host "`n >>> Processing Target: $folderName ($folderPath) <<<" -ForegroundColor Cyan

        $allPdfFiles = Get-ChildItem -Path $folderPath -Filter *.pdf -Recurse -File
        
        if ($allPdfFiles.Count -eq 0) {
            Write-Host "   No PDFs found." -ForegroundColor DarkYellow
            continue
        }
        
        # Calculate the base length to determine relative paths
        # NOTE: Using folderPath.Length instead of folderPath.Length + 1 here is safer, 
        # as it will result in an empty string if the paths are identical.
        $baseLength = $folderPath.Length
        $totalCount = $allPdfFiles.Count
        
        # 1. Synchronously prepare indexed list for progress tracking
        $indexedPdfFiles = @()
        $i = 1
        $allPdfFiles | ForEach-Object {
            $indexedPdfFiles += [PSCustomObject]@{
                Pdf = $_
                Index = $i++
                Total = $totalCount
            }
        }
        
        Write-Host "   Found $($allPdfFiles.Count) total PDF files to process synchronously." -ForegroundColor Gray
        
        # 2. Start Sequential processing loop
        $indexedPdfFiles | ForEach-Object {
            $indexedFile = $_
            $pdf = $indexedFile.Pdf
            $index = $indexedFile.Index
            $total = $indexedFile.Total

            # --- Core logic execution starts here ---
            
            # Increment total files looked at
            $stats.TotalLookedAt++

            # Setup context 
            $directoryName = $pdf.DirectoryName

            # --- Fix for Substring error ---
            # If the current directory is deeper than the base path, get the relative part.
            if ($directoryName.Length -gt $baseLength) {
                # This should extract the relative path (including the starting separator)
                $relativePath = $directoryName.Substring($baseLength)
            } else {
                # This handles the case where the file is DIRECTLY in the base folder path.
                $relativePath = ""
            }
            # -------------------------------

            $progressPrefix = "[$index/$total] "

            $original = $pdf.FullName
            $compressed = "$($pdf.DirectoryName)\compressed_$($pdf.Name)"
            $filename = Split-Path $original -Leaf
            
            # Construct the path string: RelativePath\Filename
            # This part now safely handles the empty $relativePath
            $pathFragment = $relativePath.TrimStart('\')
            if (-not [string]::IsNullOrWhiteSpace($pathFragment)) {
                $pathFragment += "\"
            }
            $contextPath = "$pathFragment$filename"
            
            # Check for pre-existing (Skipped)
            if ($pdf.Name -like "compressed_*") {
                Write-Host "$progressPrefix $contextPath (Skipped: Pre-existing compressed file)" -ForegroundColor DarkYellow
                $stats.Skipped++
                return # Skip to next file
            }
            
            try {
                # Execute GhostScript
                $gsOutput = & "$gsPath" $compressionArgs -sOutputFile="$compressed" "$original" 2>&1
                
                # Check for font embedding warnings
                if ($gsOutput -match "Warning: Font.*cannot be embedded because of licensing restrictions") {
                    if (Test-Path $compressed) { Remove-Item $compressed -Force }
                    Write-Host "$progressPrefix $contextPath (Skipped: Font license restriction)" -ForegroundColor Magenta
                    $stats.Skipped++
                    return # Skip to next file
                }

                if (-not (Test-Path $compressed)) {
                    Write-Host "$progressPrefix $contextPath (Failed: Compression output file missing)" -ForegroundColor Red
                    $stats.Skipped++
                    return # Skip to next file
                }
                
                $originalItem   = Get-Item $original
                $compressedItem = Get-Item $compressed

                $originalSizeB   = $originalItem.Length
                $compressedSizeB = $compressedItem.Length
                $originalSizeKB  = [math]::Round($originalSizeB / 1KB, 2)
                $compressedSizeKB = [math]::Round($compressedSizeB / 1KB, 2)

                if ($compressedSizeB -ge $originalSizeB) {
                    Remove-Item $compressed
                    Write-Host "$progressPrefix $contextPath (Kept Original: No Gain) [$originalSizeKB KB | $compressedSizeKB KB]" -ForegroundColor Yellow
                    $stats.Skipped++
                }
                else {
                    if ($overwrite -eq 0) {
                        Remove-Item $original
                        Rename-Item $compressed $original
                        Write-Host "$progressPrefix $contextPath (Overwritten) [$originalSizeKB KB -> $compressedSizeKB KB]" -ForegroundColor Green
                    } else {
                        Write-Host "$progressPrefix $contextPath (Compressed) [$originalSizeKB KB -> $compressedSizeKB KB]" -ForegroundColor Green
                    }
                    $stats.Compressed++
                    # Accumulate total size for successfully compressed files
                    $stats.TotalOriginalSizeB += $originalSizeB
                    $stats.TotalCompressedSizeB += $compressedSizeB
                }
            }
            catch {
                Write-Host "$progressPrefix $contextPath (Failed: GhostScript error: $($_.Exception.Message))" -ForegroundColor Red
                if (Test-Path $compressed) { Remove-Item $compressed -Force }
                $stats.Skipped++
            }

        } # End ForEach-Object (synchronous loop)
    } # End foreach $folderItem in $searchPaths
} 

# ─────────────────────────────────────────────────────────────
# Function: Clean up pre-existing compressed files (optional)
# ─────────────────────────────────────────────────────────────
function HandlePreExistingCompressedFiles {
    param (
        [string]$basePath
    )

    # Search for all files named 'compressed_*.pdf' recursively
    $compressedFiles = Get-ChildItem -Path $basePath -Filter 'compressed_*.pdf' -Recurse -ErrorAction SilentlyContinue
    $count = $compressedFiles.Count

    if ($count -eq 0) {
        Write-Host "INFO: No pre-existing 'compressed_*.pdf' files found to clean up." -ForegroundColor Gray
        return
    }

    Write-Host "`nWARNING: Found $count pre-existing 'compressed_*.pdf' files in the base path." -ForegroundColor DarkYellow
    $title = 'Cleanup Required?'
    $question = "Do you want to delete these $count files now? (If you choose 'No', they will be skipped during compression.)"
    $choices = '&Yes, Delete Them', '&No, Keep Them'
    $decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)

    if ($decision -eq 0) {
        Write-Host "DELETING: Removing $count files..." -ForegroundColor Red
        $removedCount = 0
        $compressedFiles | ForEach-Object {
            try {
                Remove-Item $_.FullName -Force -ErrorAction Stop
                $removedCount++
            }
            catch {
                Write-Host "ERROR: Failed to remove file '$($_.FullName)': $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        Write-Host "CLEANUP COMPLETE: Successfully removed $removedCount pre-existing compressed files." -ForegroundColor Green
        Write-Host "`n"
    } else {
        Write-Host "SKIP: Keeping pre-existing compressed files. They will be skipped during processing." -ForegroundColor Yellow
        Write-Host "`n"
    }
}


# ─────────────────────────────────────────────────────────────
# Main Function
# ─────────────────────────────────────────────────────────────
function Main {
    # Record start time
    $startTime = Get-Date

    Write-Host "`nINFO: Using synchronous processing for file compression." -ForegroundColor Green
    
    $folderToUse = AskForFolderBasePath

    if ($folderToUse -eq "") {
        Write-Host "Base folder not provided" -ForegroundColor Red
        return
    }
    elseif (-not (Test-Path $folderToUse)) {
        Write-Host "Base folder does not exist" -ForegroundColor Red
        return
    }
    
    # Check if Ghostscript executable exists
    if (-not (Test-Path $gsPath)) {
        Write-Host "`nERROR: Ghostscript executable not found at '$gsPath'" -ForegroundColor Red
        Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Red
        Write-Host "Please ensure Ghostscript is installed and the path in the script is correct." -ForegroundColor Red
        Write-Host "`nInstallation Instructions:" -ForegroundColor Yellow
        Write-Host "1. Download the latest 64-bit installer for Ghostscript from the official website."
        Write-Host "2. Install Ghostscript."
        Write-Host "3. After installation, check the correct path to 'gswin64c.exe' (it may change based on the version)."
        Write-Host "   Example path: C:\Program Files\gs\gs<version>\bin\gswin64c.exe"
        Write-Host "4. Update the \$gsPath variable (around line 21) in this script with your correct path."
        Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Red
        return
    }

    Write-Host "`n BasePath: $folderToUse" -ForegroundColor Yellow

    # Call the new function to handle pre-existing compressed files
    HandlePreExistingCompressedFiles -basePath $folderToUse
    
    $title1    = 'Do you want to continue with compressing PDF files?'
    $question1 = 'Pick selection...'
    $choices1  = '&Yes', '&No'
    $decision1 = $Host.UI.PromptForChoice($title1, $question1, $choices1, 1)
    if ($decision1 -ne 0) {
        Write-Host "`n Compress aborted" -ForegroundColor Red
        return
    }

    $title2    = 'Do you want to overwrite original PDFs with compressed versions?'
    $question2 = 'This will delete the original and rename the compressed file.'
    $choices2  = '&Yes', '&No'
    $overwrite = $Host.UI.PromptForChoice($title2, $question2, $choices2, 1)
    if ($overwrite -ne 0 -and $overwrite -ne 1) {
        Write-Host "`n Invalid overwrite choice. Exiting..." -ForegroundColor Red
        return
    }
    
    # Ask for specific folders to target - updated for flexibility
    Write-Host "`nDo you want to target specific folders for compression? (e.g., 'Receipts', '2024', 'Taxes')" -ForegroundColor Yellow
    $targetFolderInput = Read-Host -Prompt "Enter a comma-separated list of folder names (leave blank to process ALL PDFs recursively)"
    
    $targetFolders = @()
    $matchType = 1 # Default to Contains Match

    if (-not [string]::IsNullOrWhiteSpace($targetFolderInput)) {
        $targetFolders = $targetFolderInput.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

        $title3    = 'How should the folder names be matched?'
        $question3 = 'Do you want to check for an exact folder name match or just if the name contains the text?'
        $choices3  = '&Exact Match', '&Contains Match'
        $matchType = $Host.UI.PromptForChoice($title3, $question3, $choices3, 1) 
    }
    
    # Initialize Stats Counter with size tracking fields
    $stats = @{ 
        TotalLookedAt = 0;
        Skipped = 0;
        Compressed = 0;
        TotalOriginalSizeB = 0; # Total size of files successfully compressed (before)
        TotalCompressedSizeB = 0; # Total size of files successfully compressed (after)
    }
    
    # Call TraverseAndCompress with all parameters
    TraverseAndCompress -basePath $folderToUse -overwrite $overwrite -targetFolders $targetFolders -matchType $matchType -stats $stats -gsPath $gsPath -compressionArgs $compressionArgs

    # Record end time and calculate duration
    $endTime = Get-Date
    $duration = $endTime - $startTime
    $formattedDuration = Format-TimeSpan -timeSpan $duration

    # Calculate size statistics
    $originalTotalB = $stats.TotalOriginalSizeB
    $compressedTotalB = $stats.TotalCompressedSizeB
    $savingsTotalB = $originalTotalB - $compressedTotalB
    
    # Calculate savings percentage safely
    $savingsPercentage = if ($originalTotalB -gt 0) { 
        [math]::Round(($savingsTotalB / $originalTotalB) * 100, 2)
    } else { 
        0.00 
    }

    # Format sizes for display
    $formattedOriginalSize = Format-FileSize -bytes $originalTotalB
    $formattedCompressedSize = Format-FileSize -bytes $compressedTotalB
    $formattedSavingsSize = Format-FileSize -bytes $savingsTotalB

    # Final Summary Report (Using standard hyphens for compatibility)
    Write-Host "`n-------------------------------------------------------------" -ForegroundColor White
    Write-Host " Compression Summary" -ForegroundColor Cyan
    Write-Host "-------------------------------------------------------------" -ForegroundColor White
    Write-Host " Total Time Taken: $formattedDuration" -ForegroundColor White
    Write-Host " Total Original Size (Files Compressed): $formattedOriginalSize" -ForegroundColor Gray
    Write-Host " Total Compressed Size (Files Compressed): $formattedCompressedSize" -ForegroundColor Gray
    Write-Host " Total Size Reduction: $formattedSavingsSize ($($savingsPercentage)%)" -ForegroundColor Green
    Write-Host " Total PDFs Looked At: $($stats.TotalLookedAt)" -ForegroundColor Gray
    Write-Host " Files Successfully Compressed: $($stats.Compressed)" -ForegroundColor Green
    Write-Host " Files Skipped (No Gain/Pre-existing): $($stats.Skipped)" -ForegroundColor Yellow
    Write-Host "-------------------------------------------------------------" -ForegroundColor White

    # Pause at the end for user to read the summary
    Write-Host "`nPress any key to exit..." -ForegroundColor Cyan
    [void]$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

} 

# ─────────────────────────────────────────────────────────────
# Program Entry Point
# ─────────────────────────────────────────────────────────────
Main
