[CmdletBinding()]
param()

# For more information on the VSTS Task SDK:
# https://github.com/Microsoft/vsts-task-lib
#Trace-VstsEnteringInvocation $MyInvocation
try {
    #Get input variables
    $packageJsonPath = Get-VstsInput -Name packageJsonPath -Require
    $nodeModulesPath = Get-VstsInput -Name nodeModulesPath -Require
    $npmInstallCommand = Get-VstsInput -Name npmInstallCommand -Require
    $storageAccountName = Get-VstsInput -Name storageAccountName -Require
    $storageAccountKey = Get-VstsInput -Name storageAccountKey -Require
    $containerName = Get-VstsInput -Name containerName -Require

    #Assert-VstsPath -LiteralPath $packageJsonPath -PathType Container
    $packageJsonDir = Split-Path -Path $packageJsonPath
    Write-Verbose "Setting working directory to '$packageJsonDir'."    
    Set-Location $packageJsonDir 
    
    $ctx = New-AzureStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey

    $packageJsonHash = Get-FileHash "$packageJsonPath"
    $packageJsonHash = $packageJsonHash."Hash"

    try
    {   $blobExists = "true";
        Get-AzureStorageBlobContent -Blob $packageJsonHash -Destination $nodeModulesPath -Container $containerName -Context $ctx -ErrorAction Stop
    }
    catch [Microsoft.WindowsAzure.Commands.Storage.Common.ResourceNotFoundException]
    {
        $blobExists = "false"
        Write-Host "Could not find blob: "+$packageJsonHash
    }

    if($blobExists -eq "true")
    {
        #unpack at location
        [System.IO.Compression.ZipFile]::ExtractToDirectory("$nodeModulesPath/$packageJsonHash", $nodeModulesPath)
    }
    else
    {
        #npm install command
        Invoke-Expression "$npmInstallCommand"

        #now zip up node_modules
        Compress-Archive -Path $nodeModulesPath -DestinationPath $packageJsonHash

        #upload
        Set-AzureStorageBlobContent -File $packageJsonHash".zip" -Container $containerName -Blob $packageJsonHash -Context $ctx
    }

    # Output the message to the log.
    #Write-Host (Get-VstsInput -Name msg)
} finally {
    #Trace-VstsLeavingInvocation $MyInvocation
}
