<#
.SYNOPSIS
    This script connects to multiple vCenter servers, retrieves information about VMs with snapshots, and categorizes them into those that can be removed and those that are protected by tags.

.DESCRIPTION
    The script performs the following steps:
    1. Connects to the specified vCenter servers.
    2. Retrieves all VMs with snapshots from each vCenter and gathers relevant snapshot details.
    3. Filters out VMs with names that include "VMT", "Template", or "Templ", excluding them from the snapshot removal process.
    4. Identifies VMs with the "PersistantSnapshot" tag and excludes them from removal, listing them in a separate section of the report.
    5. Categorizes snapshots older than 2 weeks into a list of "Snapshots to be Removed" and those with the "PersistantSnapshot" tag into a "Persistant Snapshots" list.
    6. Generates a Bootstrap-formatted HTML report with two tabs: "Snapshots to be Removed" and "Persistant Snapshots".
    7. The snapshot deletion logic is included but commented out for safety.

.PARAMETER None
    The script does not take any parameters.

.EXAMPLE
    ./VM_Snapshot_Report.ps1
    This command runs the script and generates the VM Snapshot Report in HTML format.

.NOTES
    - Requires VMware PowerCLI to be installed.
    - The script prompts for credentials to connect to vCenter servers.
    - The HTML report is saved as "VM_Snapshot_Report.html" in the current directory.

.AUTHOR
    Niall O'Kane

#>

# Install VMware PowerCLI module if not installed
if (-not (Get-Module -ListAvailable -Name VMware.PowerCLI)) {
    Install-Module -Name VMware.PowerCLI -Force
}

# Import the module
Import-Module VMware.PowerCLI

# Prompt for credentials
$cred = Get-Credential

# Define vCenter servers in an array
$vcenters = @("VCA-FQDN1", "VCA-FQDN2")

# Initialize arrays to store snapshot information
$snapshotsToBeRemoved = @()
$persistantSnapshots = @()

# Connect to each vCenter and gather snapshot data
foreach ($vc in $vcenters) {
    Connect-VIServer -Server $vc -Credential $cred
    
    # Retrieve all VMs with snapshots
    $vmsWithSnapshots = Get-VM | Get-Snapshot

    foreach ($snapshot in $vmsWithSnapshots) {
        $vm = $snapshot.VM
        $vmName = $vm.Name
        $snapCreated = $snapshot.Created
        $snapAge = (New-TimeSpan -Start $snapCreated -End (Get-Date)).Days

        # Exclude VMs with "VMT", "Template", or "Templ" in the name
        if ($vmName -match "VMT|Template|Templ") {
            continue
        }

        # Retrieve tags for the VM
        $tags = Get-TagAssignment -Entity $vm | Select-Object -ExpandProperty Tag

        # Check if the VM has the "PersistantSnapshot" tag
        if ($tags.Name -contains "PersistantSnapshot") {
            $persistantSnapshots += [PSCustomObject]@{
                VDC             = $vc
                VMName          = $vmName
                SnapshotName    = $snapshot.Name
                SnapshotDescription = $snapshot.Description
                SnapshotSizeMB  = [math]::Round(($snapshot.SizeGB * 1024), 2)
                SnapshotCreated = $snapCreated
                SnapshotAgeDays = $snapAge
            }
            continue
        }

        # Check if the snapshot is older than 2 weeks
        if ($snapAge -gt 14) {
            $snapshotsToBeRemoved += [PSCustomObject]@{
                VDC             = $vc
                VMName          = $vmName
                SnapshotName    = $snapshot.Name
                SnapshotDescription = $snapshot.Description
                SnapshotSizeMB  = [math]::Round(($snapshot.SizeGB * 1024), 2)
                SnapshotCreated = $snapCreated
                SnapshotAgeDays = $snapAge
            }

            # Commented out snapshot removal code
            # Remove-Snapshot -Snapshot $snapshot -Confirm:$false
        }
    }

    Disconnect-VIServer -Server $vc -Confirm:$false
}

# Generate HTML Report with Tabs
$htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link href="https://stackpath.bootstrapcdn.com/bootstrap/4.5.2/css/bootstrap.min.css" rel="stylesheet">
    <title>VM Snapshot Report</title>
</head>
<body>
    <div class="container">
        <h1 class="mt-5">VM Snapshot Report</h1>
        <ul class="nav nav-tabs" id="snapshotTabs" role="tablist">
            <li class="nav-item">
                <a class="nav-link active" id="remove-tab" data-toggle="tab" href="#remove" role="tab" aria-controls="remove" aria-selected="true">Snapshots to be Removed</a>
            </li>
            <li class="nav-item">
                <a class="nav-link" id="persistent-tab" data-toggle="tab" href="#persistent" role="tab" aria-controls="persistent" aria-selected="false">Persistent Snapshots</a>
            </li>
        </ul>
        <div class="tab-content" id="snapshotTabsContent">
            <div class="tab-pane fade show active" id="remove" role="tabpanel" aria-labelledby="remove-tab">
                <h2>Snapshots to be Removed</h2>
                <table class="table table-striped">
                    <thead>
                        <tr>
                            <th>VDC</th>
                            <th>VM Name</th>
                            <th>Snapshot Name</th>
                            <th>Snapshot Description</th>
                            <th>Snapshot Size (MB)</th>
                            <th>Snapshot Creation Date</th>
                            <th>Snapshot Age (Days)</th>
                        </tr>
                    </thead>
                    <tbody>
"@
foreach ($snapshot in $snapshotsToBeRemoved) {
    $htmlContent += @"
                        <tr>
                            <td>$($snapshot.VDC)</td>
                            <td>$($snapshot.VMName)</td>
                            <td>$($snapshot.SnapshotName)</td>
                            <td>$($snapshot.SnapshotDescription)</td>
                            <td>$($snapshot.SnapshotSizeMB)</td>
                            <td>$($snapshot.SnapshotCreated)</td>
                            <td>$($snapshot.SnapshotAgeDays)</td>
                        </tr>
"@
}
$htmlContent += @"
                    </tbody>
                </table>
            </div>
            <div class="tab-pane fade" id="persistent" role="tabpanel" aria-labelledby="persistent-tab">
                <h2>Persistent Snapshots</h2>
                <p>VMs Tagged with the <b>PersistantSnapshot</b> tag in VMware vSphere</p>
                <table class="table table-striped">
                    <thead>
                        <tr>
                            <th>VDC</th>
                            <th>VM Name</th>
                            <th>Snapshot Name</th>
                            <th>Snapshot Description</th>
                            <th>Snapshot Size (MB)</th>
                            <th>Snapshot Creation Date</th>
                            <th>Snapshot Age (Days)</th>
                        </tr>
                    </thead>
                    <tbody>
"@
foreach ($snapshot in $persistantSnapshots) {
    $htmlContent += @"
                        <tr>
                            <td>$($snapshot.VDC)</td>
                            <td>$($snapshot.VMName)</td>
                            <td>$($snapshot.SnapshotName)</td>
                            <td>$($snapshot.SnapshotDescription)</td>
                            <td>$($snapshot.SnapshotSizeMB)</td>
                            <td>$($snapshot.SnapshotCreated)</td>
                            <td>$($snapshot.SnapshotAgeDays)</td>
                        </tr>
"@
}
$htmlContent += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>
    <script src="https://code.jquery.com/jquery-3.5.1.slim.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@4.5.2/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
"@

# Output the HTML content to a file
$outputFile = "VM_Snapshot_Report.html"
$htmlContent | Out-File -FilePath $outputFile -Encoding utf8

Write-Host "Report generated and saved as $outputFile"
