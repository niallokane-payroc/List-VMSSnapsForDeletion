# List-VMSSnapsForDeletion
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
